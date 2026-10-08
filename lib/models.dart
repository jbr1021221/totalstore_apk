import 'package:flutter/material.dart';
import 'theme.dart';

double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

String money(num v) {
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$taka$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String initialsOf(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return p.take(2).map((e) => e[0].toUpperCase()).join();
}

String timeAgo(String? iso) {
  final t = DateTime.tryParse(iso ?? '')?.toLocal();
  if (t == null) return '';
  final now = DateTime.now();
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final clock = '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  if (t.year == now.year && t.month == now.month && t.day == now.day) return clock;
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[t.month - 1]} ${t.day}, $clock';
}

class Store {
  final int id;
  final String name;
  final bool isOwner;
  Store(this.id, this.name, this.isOwner);
  factory Store.fromJson(Map j) => Store(_i(j['id']), '${j['name']}', j['is_owner'] == true);
}

class User {
  final int id;
  final String name, email;
  User(this.id, this.name, this.email);
  factory User.fromJson(Map j) => User(_i(j['id']), '${j['name']}', '${j['email']}');
}

class Stats {
  final int newCount, confirmed, preparing, ready, shipped, delivered, todayOrders, todayProcessed, total, customers, returning, repeatRate;
  final double todaySales, todayPaid, avgOrder, avgChange, cod, digital;
  final double? changePct, fulfillmentRate;
  final Map<String, ({int orders, double amount})> pipeline;
  final Map<String, int> woo;
  Stats(Map j)
      : newCount = _i(j['new']),
        confirmed = _i(j['confirmed']),
        preparing = _i(j['preparing']),
        ready = _i(j['ready']),
        shipped = _i(j['shipped']),
        delivered = _i(j['delivered']),
        todayOrders = _i(j['today_orders']),
        todayProcessed = _i(j['today_processed']),
        total = _i(j['total_orders']),
        customers = _i(j['customers_total']),
        returning = _i(j['returning_orders']),
        repeatRate = _i(j['repeat_rate']),
        todaySales = _d(j['today_sales']),
        todayPaid = _d(j['today_paid']),
        avgOrder = _d(j['avg_order_value']),
        avgChange = _d(j['avg_order_change']),
        cod = _d(j['payments']?['cod']),
        digital = _d(j['payments']?['digital']),
        changePct = j['sales_change_pct'] == null ? null : _d(j['sales_change_pct']),
        fulfillmentRate = j['fulfillment_rate'] == null ? null : _d(j['fulfillment_rate']),
        woo = {for (final e in (j['woo'] as Map? ?? {}).entries) '${e.key}': _i(e.value)},
        pipeline = {
          for (final e in (j['pipeline'] as Map? ?? {}).entries) '${e.key}': (orders: _i(e.value['orders']), amount: _d(e.value['amount']))
        };
  int get totalPipeline => pipeline.values.fold(0, (a, e) => a + e.orders);
}

class Paged<T> {
  final List<T> items;
  final bool more;
  final Map meta;
  Paged(this.items, this.more, this.meta);
}

class ProdCategory {
  final int id;
  final String name;
  ProdCategory(Map j)
      : id = _i(j['id']),
        name = '${j['name']}';
}

/// WooCommerce order statuses, shown with the app's own colours.
enum Woo {
  pending('pending', 'Pending payment', 'Waiting for payment or your confirmation', Icons.hourglass_top),
  processing('processing', 'Processing', 'Payment received. Pack, ship and deliver', Icons.autorenew),
  onHold('on-hold', 'On hold', 'Paused until payment or stock is sorted out', Icons.pause_circle_outline),
  completed('completed', 'Completed', 'Delivered to the customer', Icons.check_circle_outline),
  cancelled('cancelled', 'Cancelled', 'Stopped. Stock was put back', Icons.cancel_outlined),
  refunded('refunded', 'Refunded', 'Money returned. Stock was put back', Icons.undo),
  failed('failed', 'Failed', 'Payment failed. Stock was put back', Icons.error_outline);

  final String slug, label, hint;
  final IconData icon;
  const Woo(this.slug, this.label, this.hint, this.icon);

  Color get color => switch (this) {
        Woo.pending => C.orange,
        Woo.processing => C.secondary,
        Woo.onHold => C.tertiary,
        Woo.completed => C.green,
        Woo.cancelled => C.neutral,
        Woo.refunded => C.sub,
        Woo.failed => C.red,
      };

  bool get isFinal => this == Woo.cancelled || this == Woo.refunded || this == Woo.failed;

  static Woo of(String? slug) => Woo.values.firstWhere((w) => w.slug == slug, orElse: () => Woo.pending);

  /// Same mapping as the server uses, for screens that only know the raw status.
  static Woo fromRaw(String raw) => switch (raw) {
        'confirmed' || 'processing' || 'packed' || 'shipped' => Woo.processing,
        'on_hold' => Woo.onHold,
        'delivered' || 'completed' => Woo.completed,
        'cancelled' => Woo.cancelled,
        'returned' => Woo.refunded,
        'failed' => Woo.failed,
        _ => Woo.pending,
      };
}

/// One status the order may move to next, with what it does.
class NextStatus {
  final Woo woo;
  final String note;
  final bool destructive;
  NextStatus(Map j)
      : woo = Woo.of('${j['slug']}'),
        note = '${j['note'] ?? ''}',
        destructive = j['destructive'] == true;
}

/// How far an order is along the 4-step fulfillment timeline (Confirm, Prepare, Ship, Done).
int fulfillmentStep(String s) => switch (s) {
      'pending' || 'submitted' => 0,
      'confirmed' || 'processing' => 1,
      'packed' => 2,
      'shipped' => 3,
      _ => 4,
    };

String placedAt(String? iso) {
  final t = DateTime.tryParse(iso ?? '')?.toLocal();
  if (t == null) return '';
  final now = DateTime.now();
  final today = t.year == now.year && t.month == now.month && t.day == now.day;
  return today ? 'Today at ${timeAgo(iso)}' : timeAgo(iso);
}

/// Display metadata for the status buckets the API returns.
class Bucket {
  // Kept for the 4 coarse buckets returned by the API list.
  static String label(String b) => const {
        'new': 'New',
        'preparing': 'Preparing',
        'ready': 'Ready to Ship',
        'shipped': 'Shipped',
        'delivered': 'Delivered',
        'cancelled': 'Cancelled',
        'returned': 'Returned',
      }[b] ?? b;
  static Color color(String b) => const {
        'new': C.red,
        'preparing': C.orange,
        'ready': C.secondary,
        'shipped': C.tertiary,
        'delivered': C.green,
        'cancelled': C.neutral,
        'returned': C.neutral,
      }[b] ?? C.neutral;
}

class OrderSummary {
  final int id, itemsCount;
  final String number, status, bucket, paymentStatus, paymentMethod, createdAt;
  final Woo woo;
  final List<NextStatus> next;
  final double total;
  final int? customerId;
  final String customerName, customerPhone, address, city;
  OrderSummary(Map j)
      : id = _i(j['id']),
        itemsCount = _i(j['items_count']),
        number = '${j['order_number']}',
        status = '${j['status']}',
        bucket = '${j['bucket']}',
        woo = j['woo_status'] != null ? Woo.of('${j['woo_status']}') : Woo.fromRaw('${j['status']}'),
        next = [for (final n in j['allowed_next'] ?? []) NextStatus(n)],
        paymentStatus = '${j['payment_status'] ?? ''}',
        paymentMethod = '${j['payment_method'] ?? ''}',
        createdAt = '${j['created_at'] ?? ''}',
        total = _d(j['total']),
        customerId = j['customer'] == null ? null : _i(j['customer']['id']),
        customerName = '${j['customer']?['name'] ?? 'Guest'}',
        customerPhone = '${j['customer']?['phone'] ?? ''}',
        address = '${j['shipping_address'] ?? ''}',
        city = '${j['shipping_city'] ?? ''}';

  String get area => [address, city].where((e) => e.isNotEmpty && e != 'null').join(', ');
  String get shortNumber => number.split('-').last;
  String get label => woo.label;
  Color get color => woo.color;
}

/// Gateway-agnostic helper for screens: true when a gateway transaction (bKash...) backs this order.
extension PaidInfo on OrderDetail {
  bool get hasGatewayPayment => payGateway.isNotEmpty && (trxId.isNotEmpty || payerNumber.isNotEmpty);
}

class OrderLine {
  final String name, variant, sku;
  final double price, total;
  final int quantity;
  OrderLine(Map j)
      : name = '${j['name']}',
        variant = '${j['variant'] ?? ''}'.replaceAll('null', ''),
        sku = '${j['sku'] ?? ''}'.replaceAll('null', ''),
        price = _d(j['price']),
        total = _d(j['total']),
        quantity = _i(j['quantity']);
}

class TimelineEvent {
  final String title, description, actor, at;
  TimelineEvent(Map j)
      : title = '${j['title']}',
        description = '${j['description'] ?? ''}'.replaceAll('null', ''),
        actor = '${j['actor'] ?? ''}'.replaceAll('null', ''),
        at = '${j['at'] ?? ''}';
}

class OrderDetail extends OrderSummary {
  final double subtotal, discount, shippingFee, tax;
  final String notes, tracking, courier;
  final int customerOrders;
  final bool verified;
  final bool bkashAwaiting;
  final String paymentLink;
  final String payGateway, trxId, payerNumber;
  final String zone;
  final List<OrderLine> items;
  final List<TimelineEvent> timeline;
  OrderDetail(Map j)
      : subtotal = _d(j['subtotal']),
        discount = _d(j['discount']),
        shippingFee = _d(j['shipping_fee']),
        tax = _d(j['tax']),
        notes = '${j['notes'] ?? ''}'.replaceAll('null', ''),
        tracking = '${j['tracking_number'] ?? ''}'.replaceAll('null', ''),
        courier = '${j['courier_provider'] ?? ''}'.replaceAll('null', ''),
        customerOrders = _i(j['customer_orders_count']),
        verified = j['customer_verified'] == true,
        bkashAwaiting = j['bkash_awaiting'] == true,
        paymentLink = '${j['payment_link'] ?? ''}'.replaceAll('null', ''),
        payGateway = '${j['payment']?['gateway'] ?? ''}',
        trxId = '${j['payment']?['transaction_id'] ?? ''}'.replaceAll('null', ''),
        payerNumber = '${j['payment']?['payer_number'] ?? ''}'.replaceAll('null', ''),
        zone = '${j['shipping_zone'] ?? ''}'.replaceAll('null', ''),
        items = [for (final e in j['items'] ?? []) OrderLine(e)],
        timeline = [for (final e in j['timeline'] ?? []) TimelineEvent(e)],
        super(j);
}

class ProductItem {
  final int id, stock;
  final String title, sku;
  final double price;
  final String? imageUrl;
  final List<String> categories;
  ProductItem(Map j)
      : id = _i(j['id']),
        stock = _i(j['stock_qty']),
        title = '${j['title']}',
        sku = '${j['sku'] ?? ''}'.replaceAll('null', ''),
        price = _d(j['price']),
        imageUrl = j['image_url'] as String?,
        categories = [for (final c in j['categories'] ?? []) '$c'];
}

class CustomerItem {
  final int? id;
  final int totalOrders, returns;
  final String name, phone, email, address, city;
  final double totalSpent;
  final bool verified;
  final String? lastOrderAt;
  final List<OrderSummary> recent;
  CustomerItem(Map j)
      : id = j['id'] == null ? null : _i(j['id']),
        totalOrders = _i(j['total_orders']),
        returns = _i(j['returns']),
        name = '${j['name']}',
        phone = '${j['phone'] ?? ''}',
        email = '${j['email'] ?? ''}'.replaceAll('null', ''),
        address = '${j['address'] ?? ''}'.replaceAll('null', ''),
        city = '${j['city'] ?? ''}'.replaceAll('null', ''),
        totalSpent = _d(j['total_spent']),
        verified = j['verified'] == true,
        lastOrderAt = j['last_order_at'] as String?,
        recent = [
          for (final o in j['recent_orders'] ?? []) OrderSummary({...o, 'bucket': o['status']})
        ];
  String get area => [address, city].where((e) => e.isNotEmpty).join(', ');
}

class CartLine {
  final ProductItem product;
  int qty;
  CartLine(this.product, this.qty);
  double get total => product.price * qty;
}

class ChatMessage {
  final int id;
  final String direction, channel, body, status, sentBy, at;
  ChatMessage(Map j)
      : id = _i(j['id']),
        direction = '${j['direction']}',
        channel = '${j['channel']}',
        body = '${j['body']}',
        status = '${j['status']}',
        sentBy = '${j['sent_by'] ?? ''}'.replaceAll('null', ''),
        at = '${j['at'] ?? ''}';
  bool get mine => direction == 'out';
}

class ChatThread {
  final int orderId, count;
  final String orderNumber, customerName, customerPhone;
  final ChatMessage last;
  ChatThread(Map j)
      : orderId = _i(j['order_id']),
        count = _i(j['count']),
        orderNumber = '${j['order_number']}',
        customerName = '${j['customer_name'] ?? 'Customer'}',
        customerPhone = '${j['customer_phone'] ?? ''}'.replaceAll('null', ''),
        last = ChatMessage(j['last']);
  String get shortNumber => orderNumber.split('-').last;
}
