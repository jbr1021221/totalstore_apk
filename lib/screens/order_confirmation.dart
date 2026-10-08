import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../pay_badge.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_detail.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final OrderDetail o;
  const OrderConfirmationScreen(this.o, {super.key});

  @override
  Widget build(BuildContext context) {
    final paid = o.paymentStatus == 'paid';
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(children: [Icon(Icons.circle, size: 8, color: C.secondary), SizedBox(width: 8), Text('Order Confirmation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))]),
        actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.popUntil(context, (r) => r.isFirst))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 40))),
        const SizedBox(height: 14),
        Text('Order #${o.shortNumber} Created!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Order successfully booked. It now appears on the web dashboard too.', textAlign: TextAlign.center, style: TextStyle(color: C.sub, fontSize: 13)),
        const SizedBox(height: 10),
        Center(child: Pill('Created ${placedAt(o.createdAt)} • Step 4 of 4 Completed', C.secondary, icon: Icons.schedule)),
        const SizedBox(height: 16),
        const SectionLabel('Order summary'),
        AppCard(
          child: Column(children: [
            _row(Icons.person_outline, 'Customer', Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w800)), Text(o.customerPhone, style: mono(11, C.sub))])),
            const Divider(color: C.line),
            _row(Icons.local_shipping_outlined, 'Delivery', Text('${o.area}\n${zoneLabel(o.zone)} • ${money(o.shippingFee)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            const Divider(color: C.line),
            _row(Icons.payments_outlined, 'Payment', Row(mainAxisSize: MainAxisSize.min, children: [PayLogo(payOf(o.paymentMethod), height: 20), const SizedBox(width: 6), Pill(paid ? 'Paid' : (o.bkashAwaiting ? 'Awaiting bKash' : (o.paymentMethod == 'cod' ? 'Pay on delivery' : 'Unpaid')), paid ? C.green : (o.paymentMethod == 'cod' ? C.orange : C.red), dot: false)])),
            const Divider(color: C.line),
            if (o.hasGatewayPayment) ...[
              if (o.payerNumber.isNotEmpty) CopyRow('${o.payGateway == 'bkash' ? 'bKash' : o.payGateway} number', o.payerNumber),
              if (o.trxId.isNotEmpty) CopyRow('Transaction ID', o.trxId),
              const Divider(color: C.line),
            ],
            _row(Icons.shopping_bag_outlined, 'Items', Text('${o.items.length} items\n${o.items.map((l) => '${l.name} × ${l.quantity}').join(', ')}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
            const Divider(color: C.line),
            KeyValue('Total Amount', money(o.total), bold: true),
          ]),
        ),
        if (o.bkashAwaiting)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('bKash payment link sent', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('The customer received an SMS. The order will be confirmed automatically once they pay.', style: TextStyle(fontSize: 12, color: C.sub)),
              if (o.paymentLink.isNotEmpty) ...[
                const SizedBox(height: 10),
                GhostButton('Copy payment link', icon: Icons.link, onPressed: () {
                  Clipboard.setData(ClipboardData(text: o.paymentLink));
                  toast(context, 'Payment link copied');
                }),
              ],
            ]),
          ),
        const SectionLabel('Quick fulfillment actions'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            _action(Icons.print_outlined, 'Print Invoice / Packing Slip', 'Download PDF or print receipt', () => soon(context, 'Invoice printing')),
            const Divider(height: 1, color: C.line),
            _action(Icons.share_outlined, 'Share Receipt with Buyer', 'Copy the receipt to send by WhatsApp / SMS', () {
              Clipboard.setData(ClipboardData(text: receiptText(o)));
              toast(context, 'Receipt copied');
            }),
            const Divider(height: 1, color: C.line),
            _action(Icons.inventory_2_outlined, 'View in Fulfillment Queue', 'Manage ready-to-ship batches', () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(o.id)))),
          ]),
        ),
      ]),
      bottomNavigationBar: BottomAction(children: [
        PrimaryButton('Go to Order Details', icon: Icons.arrow_forward, trailingIcon: true, onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(o.id)))),
        const SizedBox(height: 8),
        GhostButton('Create Another Order', icon: Icons.add, onPressed: () => Navigator.popUntil(context, (r) => r.isFirst)),
        TextButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text('Back to Orders List', style: TextStyle(color: C.sub, fontSize: 12))),
      ]),
    );
  }

  Widget _row(IconData i, String k, Widget v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 16, color: C.sub),
          const SizedBox(width: 8),
          Text(k, style: const TextStyle(fontSize: 12, color: C.sub)),
          const SizedBox(width: 16),
          Expanded(child: Align(alignment: Alignment.centerRight, child: v)),
        ]),
      );

  Widget _action(IconData i, String t, String s, VoidCallback onTap) => ListTile(
        leading: Icon(i),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(s, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
