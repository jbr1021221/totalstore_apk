import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:total_store/main.dart';
import 'package:total_store/models.dart';

Map fx(String n) => jsonDecode(File('test/fixtures/$n.json').readAsStringSync());

void main() {
  test('models parse real API responses', () {
    expect(Stats(fx('stats')['data']).total, greaterThan(0));

    final orders = [for (final e in fx('orders')['data']) OrderSummary(e)];
    expect(orders, isNotEmpty);
    expect(orders.first.customerName, isNotEmpty);

    final o = OrderDetail(fx('order')['data']);
    expect(o.items, isNotEmpty);
    expect(o.timeline, isNotEmpty);
    expect(o.total, closeTo(o.subtotal + o.shippingFee - o.discount + o.tax, 0.01));

    expect([for (final e in fx('products')['data']) ProductItem(e)].first.price, greaterThan(0));
    expect(CustomerItem(fx('customer')['data']).name, isNotEmpty);
  });

  test('paid bKash order exposes the payer number and transaction id', () {
    final o = OrderDetail(fx('order_bkash')['data']);
    expect(o.payGateway, 'bkash');
    expect(o.payerNumber, '01619777283');
    expect(o.trxId, 'CKB7T4P9QX');
    expect(o.hasGatewayPayment, isTrue);
    expect(OrderDetail(fx('order')['data']).hasGatewayPayment, isFalse);
  });

  test('orders carry a WooCommerce status and the moves allowed from it', () {
    final o = OrderDetail(fx('order')['data']);
    expect(o.woo, Woo.processing);
    expect(o.next.map((n) => n.woo), [Woo.completed, Woo.onHold, Woo.cancelled, Woo.refunded]);
    expect(o.next.firstWhere((n) => n.woo == Woo.cancelled).destructive, isTrue);
    expect(Woo.fromRaw('packed'), Woo.processing);
    expect(Woo.fromRaw('submitted'), Woo.pending);
    expect(Woo.fromRaw('returned'), Woo.refunded);
    expect(Woo.cancelled.isFinal && Woo.refunded.isFinal && Woo.failed.isFinal, isTrue);
    expect(Stats(fx('stats')['data']).woo.keys, containsAll(['pending', 'processing', 'on-hold', 'completed']));
  });

  test('chat threads and messages parse', () {
    final threads = [for (final e in fx('threads')['data']) ChatThread(e)];
    expect(threads, isNotEmpty);
    expect(threads.first.customerName, isNotEmpty);
    final msgs = [for (final e in fx('chat')['data']['messages']) ChatMessage(e)];
    expect(msgs.first.mine, isTrue);
    expect(msgs.last.mine, isFalse);
  });

  test('money formats thousands', () {
    expect(money(1910), '৳1,910');
    expect(money(3421.04), '৳3,421.04');
  });

  testWidgets('shows login when signed out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MerchantApp());
    await tester.pumpAndSettle();
    expect(find.text('Merchant Direct'), findsOneWidget);
  });
}
