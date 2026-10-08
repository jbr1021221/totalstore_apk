import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../contact.dart';
import '../pay_badge.dart';
import 'customer.dart';
import 'fulfillment.dart';
import 'order_tracking.dart';
import 'status_change.dart';

class OrderDetailScreen extends StatefulWidget {
  final int id;
  const OrderDetailScreen(this.id, {super.key});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderDetail? order;
  Object? error;
  bool busy = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final o = await api.order(widget.id);
      if (mounted) setState(() => (order = o, error = null));
    } catch (e) {
      if (mounted && order == null) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = order;
    if (o == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$error', style: const TextStyle(color: C.sub)),
                  OutlinedButton(onPressed: load, child: const Text('Retry')),
                ]),
        ),
      );
    }
    final w = o.woo;
    final awaitingBkash = o.bkashAwaiting && w == Woo.pending;
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${o.shortNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: receiptText(o)));
              toast(context, 'Order summary copied');
            },
          ),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () => soon(context, 'More actions')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
          AppCard(
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: w.color.withValues(alpha: .12), shape: BoxShape.circle),
                child: Icon(w.icon, size: 20, color: w.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.label, style: TextStyle(color: w.color, fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(w.hint, style: const TextStyle(fontSize: 12, color: C.sub)),
                  Text('Placed ${placedAt(o.createdAt)}', style: const TextStyle(fontSize: 11, color: C.neutral)),
                ]),
              ),
              if (awaitingBkash) const Pill('Awaiting bKash', Color(0xFFE2136E), icon: Icons.hourglass_top),
            ]),
          ),
          if (w == Woo.processing) _fulfillmentCard(o),
          if (awaitingBkash)
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 18, color: Color(0xFFE2136E)),
                  SizedBox(width: 8),
                  Text('Waiting for the customer to pay with bKash', style: TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                const Text('A payment link was texted to the customer. The order confirms itself the moment bKash receives the money.', style: TextStyle(fontSize: 12, color: C.sub)),
                if (o.paymentLink.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SmallButton('Copy payment link', icon: Icons.link, onPressed: () {
                    Clipboard.setData(ClipboardData(text: o.paymentLink));
                    toast(context, 'Payment link copied');
                  }),
                ],
              ]),
            ),
          const SectionLabel('Customer details'),
          AppCard(
            child: Column(children: [
              Row(children: [
                Avatar(initialsOf(o.customerName), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: o.customerId == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerScreen(o.customerId!))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.customerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(o.customerPhone, style: mono(12, C.sub)),
                    ]),
                  ),
                ),
                SmallButton('Call', icon: Icons.call, onPressed: () => callCustomer(context, o.customerPhone)),
              ]),
              const Divider(height: 22, color: C.line),
              Row(children: [
                Icon(o.verified ? Icons.verified_user_outlined : Icons.person_outline, size: 16, color: C.sub),
                const SizedBox(width: 6),
                Text(o.verified ? 'Verified Merchant Buyer' : 'New buyer', style: const TextStyle(fontSize: 12, color: C.sub)),
                const Spacer(),
                Text('${o.customerOrders > 0 ? o.customerOrders - 1 : 0} Previous Orders', style: const TextStyle(fontSize: 12, color: C.sub)),
              ]),
            ]),
          ),
          if (o.area.isNotEmpty) ...[
            const SectionLabel('Delivery address'),
            AppCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.location_on_outlined, color: C.sub),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.address.isEmpty ? o.city : o.address, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    if (o.address.isNotEmpty && o.city.isNotEmpty) Text(o.city),
                    if (o.zone.isNotEmpty) ...[const SizedBox(height: 6), Tag(zoneLabel(o.zone))],
                  ]),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: o.area));
                    toast(context, 'Address copied');
                  },
                  child: const Text('Copy →', style: TextStyle(color: C.secondary, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ]),
            ),
          ],
          SectionLabel('Ordered items (${o.items.length})', trailing: const Text('SKU VERIFIED', style: TextStyle(fontSize: 10, color: C.sub))),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, l) in o.items.indexed) ...[
                if (i > 0) const Divider(height: 1, color: C.line),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.checkroom, color: C.sub),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        if (l.variant.isNotEmpty) Text(l.variant, style: const TextStyle(fontSize: 12, color: C.sub)),
                        Text('${money(l.price)} × ${l.quantity}', style: mono(11, C.sub)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(l.total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Tag('Qty ${l.quantity}'),
                    ]),
                  ]),
                ),
              ],
            ]),
          ),
          const SectionLabel('Payment summary'),
          AppCard(
            child: Column(children: [
              KeyValue('Subtotal', money(o.subtotal)),
              if (o.discount > 0) KeyValue('Discount', '-${money(o.discount)}'),
              KeyValue('Delivery Fee', money(o.shippingFee)),
              const Divider(color: C.line),
              KeyValue('Total', money(o.total), bold: true),
              PayLine(method: o.paymentMethod, paid: o.paymentStatus == 'paid', awaiting: o.bkashAwaiting),
              if (o.hasGatewayPayment) ...[
                const Divider(color: C.line),
                if (o.payerNumber.isNotEmpty) CopyRow('${o.payGateway == 'bkash' ? 'bKash' : o.payGateway} number', o.payerNumber),
                if (o.trxId.isNotEmpty) CopyRow('Transaction ID', o.trxId),
              ],
            ]),
          ),
          if (o.notes.isNotEmpty) ...[const SectionLabel('Notes'), AppCard(child: Text(o.notes))],
        ]),
      ),
      bottomNavigationBar: BottomAction(children: [
        if (awaitingBkash)
          GhostButton('Mark as Processing (paid another way)', icon: Icons.check_circle_outline, onPressed: busy ? null : () => _change(o, Woo.processing))
        else if (w == Woo.pending)
          PrimaryButton('MARK AS PROCESSING', icon: Icons.autorenew, onPressed: busy ? null : () => _change(o, Woo.processing))
        else if (w == Woo.processing)
          PrimaryButton('MARK AS COMPLETED', icon: Icons.check_circle, onPressed: busy ? null : () => _change(o, Woo.completed))
        else if (w == Woo.onHold)
          PrimaryButton('RESUME PROCESSING', icon: Icons.play_arrow, onPressed: busy ? null : () => _change(o, Woo.processing)),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _change(o, null),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(o.next.isEmpty ? 'Status: ${w.label}' : 'Change status'),
                style: OutlinedButton.styleFrom(foregroundColor: C.text, side: const BorderSide(color: C.line), padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: o.id, openChat: true))),
                icon: const Icon(Icons.chat_outlined, size: 16),
                label: const Text('Message Buyer'),
                style: OutlinedButton.styleFrom(foregroundColor: C.text, side: const BorderSide(color: C.line), padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _change(OrderDetail o, Woo? target) async {
    final changed = await changeStatus(context, o, target: target);
    if (!changed) return;
    await load();
    if (mounted) toast(context, 'Status updated');
  }

  /// Warehouse steps that live inside Processing: Confirmed -> Packed -> Shipped.
  Widget _fulfillmentCard(OrderDetail o) {
    final step = switch (o.status) { 'packed' => 1, 'shipped' => 2, _ => 0 };
    Widget dot(int i, String t) => Expanded(
          child: Column(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: i <= step ? C.primary : C.line, shape: BoxShape.circle),
              child: Icon(i < step ? Icons.check : Icons.circle, size: i < step ? 14 : 6, color: i <= step ? Colors.white : C.neutral),
            ),
            const SizedBox(height: 4),
            Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: i == step ? C.text : C.sub)),
          ]),
        );
    return AppCard(
      child: Column(children: [
        Row(children: [dot(0, 'Confirmed'), dot(1, 'Packed'), dot(2, 'Shipped')]),
        const SizedBox(height: 12),
        GhostButton(step == 0 ? 'Open packing checklist' : step == 1 ? 'Hand to courier / mark shipped' : 'View fulfillment', icon: Icons.inventory_2_outlined, onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => FulfillmentScreen(o.id)));
          load();
        }),
      ]),
    );
  }
}

String zoneLabel(String z) => const {'inside_dhaka': 'Inside Dhaka', 'sub_dhaka': 'Sub-Dhaka', 'outside_dhaka': 'Outside Dhaka'}[z] ?? z;

void callCustomer(BuildContext context, String phone) => callPhone(context, phone);

String receiptText(OrderDetail o) => [
      'Order #${o.shortNumber} — ${api.store?.name ?? ''}',
      for (final l in o.items) '${l.quantity} × ${l.name}  ${money(l.total)}',
      'Delivery: ${money(o.shippingFee)}',
      'Total: ${money(o.total)} (${o.paymentMethod.toUpperCase()})',
    ].join('\n');
