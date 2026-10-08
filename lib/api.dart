import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Session + HTTP client for the totalshop mobile API (`/api/v1/mobile`).
/// The backend is the single source of truth; nothing is cached locally
/// except the login token and the selected store.
class Api extends ChangeNotifier {
  static const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://192.168.3.179:8001/api/v1/mobile');

  String? token;
  User? user;
  Store? store;
  List<Store> stores = [];
  bool ready = false;

  /// Firebase token of this phone, set once push is registered (removed again on logout).
  String? deviceToken;

  bool get loggedIn => token != null;

  Future<void> restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      token = p.getString('token');
      final s = p.getString('session');
      if (s != null) {
        final j = jsonDecode(s);
        user = User.fromJson(j['user']);
        stores = [for (final e in j['stores']) Store.fromJson(e)];
        final sid = p.getInt('store');
        store = stores.where((e) => e.id == sid).firstOrNull;
      }
    } catch (_) {
      token = null;
    }
    ready = true;
    notifyListeners();
    if (token != null) _refreshSession();
  }

  /// Re-reads the account so a stale saved session (e.g. changed store access) is corrected.
  Future<void> _refreshSession() async {
    try {
      final r = await _req('GET', '/auth/me');
      user = User.fromJson(r['user']);
      stores = [for (final e in r['tenants']) Store.fromJson(e)];
      if (store == null || !stores.any((s) => s.id == store!.id)) store = stores.length == 1 ? stores.first : null;
      await _save({'user': r['user'], 'stores': r['tenants']});
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save(Map? session) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (token == null) {
        await p.clear();
        return;
      }
      await p.setString('token', token!);
      if (session != null) await p.setString('session', jsonEncode(session));
      if (store != null) await p.setInt('store', store!.id);
    } catch (_) {}
  }

  Future<void> login(String email, String password) async {
    final r = await _req('POST', '/auth/login', body: {'email': email, 'password': password, 'device_name': 'flutter'}, auth: false);
    token = r['token'];
    user = User.fromJson(r['user']);
    stores = [for (final e in r['tenants']) Store.fromJson(e)];
    store = stores.length == 1 ? stores.first : null;
    await _save({'user': r['user'], 'stores': r['tenants']});
    notifyListeners();
  }

  Future<void> selectStore(Store s) async {
    store = s;
    await _save(null);
    notifyListeners();
  }

  Future<void> registerDevice(String fcmToken) async {
    await _req('POST', '/devices', body: {'token': fcmToken, 'platform': 'android'});
    deviceToken = fcmToken;
  }

  Future<void> logout() async {
    try {
      if (deviceToken != null) await _req('DELETE', '/devices', body: {'token': deviceToken});
      deviceToken = null;
      await _req('POST', '/auth/logout');
    } catch (_) {}
    token = null;
    user = null;
    store = null;
    stores = [];
    await _save(null);
    notifyListeners();
  }

  Future<dynamic> _req(String method, String path, {Map<String, String>? query, Map? body, bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query?..removeWhere((_, v) => v.isEmpty));
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (auth && token != null) 'Authorization': 'Bearer $token',
      if (auth && store != null) 'X-Tenant-ID': '${store!.id}',
    };
    http.Response res;
    try {
      final enc = body == null ? null : jsonEncode(body);
      res = await switch (method) {
        'POST' => http.post(uri, headers: headers, body: enc),
        'PUT' => http.put(uri, headers: headers, body: enc),
        'DELETE' => http.delete(uri, headers: headers, body: enc),
        _ => http.get(uri, headers: headers),
      }
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException('The server took too long to respond.');
    } catch (_) {
      throw ApiException('Cannot reach the server. Check your connection.');
    }
    dynamic j;
    try {
      j = jsonDecode(res.body);
    } catch (_) {}
    if (res.statusCode == 401 && auth) {
      token = null;
      notifyListeners();
      throw ApiException('Session expired. Please sign in again.', 401);
    }
    if (res.statusCode >= 400) {
      final errs = j is Map ? j['errors'] : null;
      final first = errs is Map && errs.isNotEmpty ? (errs.values.first as List).first : null;
      throw ApiException('${first ?? (j is Map ? j['message'] : null) ?? 'Request failed (${res.statusCode})'}', res.statusCode);
    }
    return j;
  }

  Future<Stats> stats() async => Stats((await _req('GET', '/orders/stats'))['data']);

  Paged<T> _page<T>(dynamic r, T Function(Map) f) =>
      Paged([for (final e in r['data']) f(e)], (r['meta']['current_page'] as int) < (r['meta']['last_page'] as int), r['meta']);

  Future<Paged<OrderSummary>> orders({String status = '', String search = '', int page = 1, int perPage = 20, String range = '', int? sinceId}) async =>
      _page(await _req('GET', '/orders', query: {'status': status, 'search': search, 'page': '$page', 'per_page': '$perPage', 'date_range': range, 'since_id': sinceId == null ? '' : '$sinceId'}), OrderSummary.new);

  Future<OrderDetail> order(int id) async => OrderDetail((await _req('GET', '/orders/$id'))['data']);

  /// [status] is a WooCommerce slug (processing, on-hold, completed, cancelled, refunded, failed) or the
  /// warehouse steps inside Processing: packed, shipped. The server enforces which moves are allowed.
  Future<void> updateStatus(int id, String status, {String? notes}) =>
      _req('PUT', '/orders/$id/status', body: {'status': status, if (notes != null && notes.isNotEmpty) 'notes': notes});

  Future<List<ChatThread>> chatThreads() async => [for (final e in (await _req('GET', '/messages/threads'))['data']) ChatThread(e)];

  Future<List<ChatMessage>> chatMessages(int orderId) async =>
      [for (final e in (await _req('GET', '/orders/$orderId/messages'))['data']['messages']) ChatMessage(e)];

  /// [channel]: sms (sent by the server), whatsapp (opened by the app, logged here), note. [incoming] logs a customer reply.
  Future<ChatMessage> sendChat(int orderId, String body, {String channel = 'sms', bool incoming = false}) async =>
      ChatMessage((await _req('POST', '/orders/$orderId/messages', body: {'body': body, 'channel': channel, 'direction': incoming ? 'in' : 'out'}))['data']);

  Future<Paged<ProductItem>> products({String search = '', int page = 1, int? category}) async =>
      _page(await _req('GET', '/products', query: {'search': search, 'page': '$page', 'category_id': category == null ? '' : '$category'}), ProductItem.new);

  Future<List<ProdCategory>> categories() async => [for (final e in (await _req('GET', '/categories'))['data']) ProdCategory(e)];

  Future<Paged<CustomerItem>> customers({String search = '', int page = 1}) async =>
      _page(await _req('GET', '/customers', query: {'search': search, 'page': '$page'}), CustomerItem.new);

  Future<CustomerItem> customer(int id) async => CustomerItem((await _req('GET', '/customers/$id'))['data']);

  Future<OrderDetail> createOrder({
    required Map customer,
    required List<CartLine> lines,
    required double shippingFee,
    required String zone,
    required bool bkash,
    String? notes,
  }) async {
    final r = await _req('POST', '/orders', body: {
      'customer': customer,
      'items': [
        for (final l in lines) {'product_id': l.product.id, 'product_name': l.product.title, 'price': l.product.price, 'quantity': l.qty}
      ],
      'shipping_fee': shippingFee,
      'shipping_zone': zone,
      'shipping_address': customer['address'],
      'shipping_city': customer['city'],
      // bKash orders stay unpaid: the customer gets a payment link by SMS and the order confirms itself when paid.
      'payment_method': bkash ? 'bkash' : 'cod',
      'payment_status': 'pending',
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return OrderDetail(r['data']);
  }
}

final api = Api();
