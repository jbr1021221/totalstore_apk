import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';
import 'push.dart';
import 'screens/order_detail.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// New-order alerts. While the app is running it polls the API for orders newer than the last one
/// it has seen and raises a system notification (Android) plus an in-app banner.
/// Alerts while the app is fully closed need server push (Firebase), which is not set up.
class Notifier extends ChangeNotifier {
  static const _interval = Duration(seconds: 20);
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Timer? _timer;
  int? _lastSeen;
  int? _storeId;

  /// Orders that arrived since the merchant last looked (drives the bell badge).
  int unseen = 0;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) {
          final id = int.tryParse(r.payload ?? '');
          if (id != null) navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => OrderDetailScreen(id)));
        },
      );
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {}
  }

  /// Start watching the current store; call again when the store or login changes.
  Future<void> start() async {
    stop();
    final store = api.store;
    if (!api.loggedIn || store == null) return;
    _storeId = store.id;
    await init();
    await push.init();
    await push.register();
    try {
      final p = await SharedPreferences.getInstance();
      _lastSeen = p.getInt('lastOrder_${store.id}');
    } catch (_) {}
    // With push working, the server (and the system tray) announce orders that arrived while we were away.
    await _check(alert: !push.active);
    _timer = Timer.periodic(_interval, (_) async {
      if (!push.active) await push.register(); // retry if the server was unreachable earlier
      await _check(alert: !push.active);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastSeen = null;
    unseen = 0;
  }

  /// Orders created from this app shouldn't alert the person who just created them.
  void markSeen(int orderId) {
    if (_lastSeen != null && orderId > _lastSeen!) _remember(orderId);
  }

  void clearUnseen() {
    if (unseen == 0) return;
    unseen = 0;
    notifyListeners();
  }

  Future<void> _remember(int id) async {
    _lastSeen = id;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('lastOrder_$_storeId', id);
    } catch (_) {}
  }

  /// A push arrived while the app is open: fetch the order and alert right away.
  Future<void> checkNow() => _check();

  Future<void> _check({bool alert = true}) async {
    if (!api.loggedIn || api.store?.id != _storeId) return;
    try {
      final last = _lastSeen;
      if (last == null) {
        // First run for this store: remember where we are, don't alert for old orders.
        final latest = (await api.orders(perPage: 1)).items;
        await _remember(latest.isEmpty ? 0 : latest.first.id);
        return;
      }
      final all = (await api.orders(sinceId: last, perPage: 20)).items; // newest first
      if (all.isEmpty) return;
      await _remember(all.first.id);
      final fresh = all.where((o) => o.woo == Woo.pending).toList();
      if (fresh.isEmpty) return;
      unseen += fresh.length;
      notifyListeners();
      if (alert) _alert(fresh);
    } catch (_) {
      // Offline or server down: try again on the next tick.
    }
  }

  void _alert(List<OrderSummary> fresh) {
    final one = fresh.length == 1 ? fresh.first : null;
    final title = one == null ? '${fresh.length} new orders' : 'New order #${one.shortNumber}';
    final body = one == null ? fresh.map((o) => o.customerName).join(', ') : '${one.customerName} · ${money(one.total)} · ${one.itemsCount} items';

    messengerKey.currentState?.showSnackBar(SnackBar(
      content: Text('$title — $body'),
      backgroundColor: C.primary,
      duration: const Duration(seconds: 6),
      action: one == null
          ? null
          : SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () => navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => OrderDetailScreen(one.id))),
            ),
    ));

    if (!_ready) return;
    _plugin.show(
      id: one?.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: one == null ? null : '${one.id}',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'new_orders',
          'New orders',
          channelDescription: 'Alerts when a customer places a new order',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}

final notifier = Notifier();
