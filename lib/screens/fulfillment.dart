import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_detail.dart';
import 'order_tracking.dart';

/// Pack checklist + 4-step fulfillment timeline. The primary button advances the real order status.
class FulfillmentScreen extends StatefulWidget {
  final int id;
  const FulfillmentScreen(this.id, {super.key});
  @override
  State<FulfillmentScreen> createState() => _FulfillmentScreenState();
}

class _FulfillmentScreenState extends State<FulfillmentScreen> {
  OrderDetail? o;
  Object? error;
  List<bool> checked = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final d = await api.order(widget.id);
      if (!mounted) return;
      setState(() {
        o = d;
        final packed = fulfillmentStep(d.status) >= 2;
        if (checked.length != d.items.length) checked = List.filled(d.items.length, packed);
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> advance(String status, String msg) async {
    setState(() => busy = true);
    try {
      await api.updateStatus(widget.id, status);
      await load();
      if (mounted) toast(context, msg);
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = o;
    if (order == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: error == null ? const CircularProgressIndicator() : Text('$error')));
    }
    final step = fulfillmentStep(order.status);
    final done = checked.where((e) => e).length;
    final all = done == checked.length;
    final packing = step <= 1;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Orders', style: TextStyle(fontSize: 15, color: C.sub)),
          const SizedBox(width: 12),
          Text('Order #${order.shortNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        actions: const [Icon(Icons.search), SizedBox(width: 12)],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ORDER ID', style: TextStyle(fontSize: 10, color: C.sub, letterSpacing: .6)),
                Text('#${order.shortNumber}', style: mono(22, null, FontWeight.w700)),
              ]),
            ),
            Pill(order.label.toUpperCase(), order.color),
          ]),
        ),
        AppCard(
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('FULFILLMENT TIMELINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.sub)),
              Text('Step ${(step + 1).clamp(1, 4)} of 4', style: const TextStyle(fontSize: 12, color: C.secondary, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            _Timeline(order),
          ]),
        ),
        AppCard(
          child: Row(children: [
            Avatar(initialsOf(order.customerName), size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: C.sub),
                  Flexible(child: Text(order.area, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.sub))),
                ]),
              ]),
            ),
            SmallButton('Call', icon: Icons.call, onPressed: () => callCustomer(context, order.customerPhone)),
          ]),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.checklist, size: 18, color: C.sub),
                const SizedBox(width: 8),
                Text('ITEMS TO PACK (${order.items.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.sub)),
                const Spacer(),
                Tag('$done of ${order.items.length} Verified'),
              ]),
            ),
            for (final (i, l) in order.items.indexed) ...[
              const Divider(height: 1, color: C.line),
              CheckboxListTile(
                value: checked[i],
                onChanged: packing ? (v) => setState(() => checked[i] = v!) : null,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: C.secondary,
                title: Row(children: [
                  Expanded(child: Text('${l.quantity} × ${l.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  if (checked[i]) const Tag('Packed'),
                ]),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (l.variant.isNotEmpty) Text(l.variant, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (l.sku.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(4)),
                        child: Text('SKU: ${l.sku}', style: mono(10, C.sub)),
                      ),
                    const Text('Warehouse Bin: not set', style: TextStyle(fontSize: 11, color: C.neutral)),
                  ]),
                ]),
              ),
            ],
            if (all && order.items.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.check_circle_outline, size: 16, color: C.secondary),
                  SizedBox(width: 6),
                  Text('All items verified and packaged.', style: TextStyle(fontSize: 12, color: C.sub)),
                ]),
              ),
          ]),
        ),
      ]),
      bottomNavigationBar: BottomAction(children: [
        if (step <= 1)
          PrimaryButton(busy ? 'Saving...' : 'READY TO SHIP', icon: Icons.check, onPressed: all && !busy ? () => advance('packed', 'Marked ready to ship') : null)
        else if (step == 2)
          PrimaryButton(busy ? 'Saving...' : 'MARK AS SHIPPED', icon: Icons.local_shipping, onPressed: busy ? null : () => advance('shipped', 'Marked as shipped'))
        else if (step == 3)
          PrimaryButton(busy ? 'Saving...' : 'MARK AS COMPLETED', icon: Icons.done_all, onPressed: busy ? null : () => advance('completed', 'Order completed')),
        const SizedBox(height: 8),
        GhostButton('Message Buyer', icon: Icons.chat_outlined, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id, openChat: true)))),
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  final OrderDetail o;
  const _Timeline(this.o);

  String? _time(String status) {
    for (final e in o.timeline) {
      if (e.title.toLowerCase() == status) return timeAgo(e.at);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final step = fulfillmentStep(o.status);
    final steps = [('Confirm', _time('confirmed')), ('Prepare', _time('packed')), ('Ship', _time('shipped')), ('Done', _time('delivered'))];
    return Row(children: [
      for (final (i, s) in steps.indexed)
        Expanded(
          child: Column(children: [
            Row(children: [
              Expanded(child: Container(height: 2, color: i == 0 ? Colors.transparent : (i <= step ? C.primary : C.line))),
              _dot(i, step),
              Expanded(child: Container(height: 2, color: i == steps.length - 1 ? Colors.transparent : (i < step ? C.primary : C.line))),
            ]),
            const SizedBox(height: 6),
            Text(s.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: i == step ? C.secondary : C.text)),
            Text(i < step ? (s.$2 ?? 'Done') : i == step ? 'In Progress' : 'Pending',
                style: TextStyle(fontSize: 9, color: i == step ? C.secondary : C.sub)),
          ]),
        ),
    ]);
  }

  Widget _dot(int i, int step) {
    if (i < step) {
      return Container(width: 28, height: 28, decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle), child: const Icon(Icons.check, size: 15, color: Colors.white));
    }
    if (i == step) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: C.secondary, shape: BoxShape.circle, border: Border.all(color: C.secondary.withValues(alpha: .25), width: 4)),
        child: const Icon(Icons.inventory_2, size: 13, color: Colors.white),
      );
    }
    return Container(width: 28, height: 28, decoration: const BoxDecoration(color: C.line, shape: BoxShape.circle), child: const Icon(Icons.circle, size: 6, color: C.neutral));
  }
}
