import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'chat.dart';
import 'order_detail.dart';

/// Timeline (real data) + Chat (preview only: the backend has no messaging yet).
class OrderTrackingScreen extends StatefulWidget {
  final int? orderId;
  final bool latest; // show the newest order when no orderId is given
  final bool openChat; // start on the Chat tab
  const OrderTrackingScreen({super.key, this.orderId, this.latest = false, this.openChat = false});
  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late int tab = widget.openChat ? 1 : 0;
  late Future<OrderDetail?> future = _load();

  Future<OrderDetail?> _load() async {
    var id = widget.orderId;
    if (id == null) {
      final p = await api.orders(perPage: 1);
      if (p.items.isEmpty) return null;
      id = p.items.first.id;
    }
    return api.order(id);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OrderDetail?>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (snap.hasError) return Scaffold(appBar: AppBar(), body: Center(child: Text('${snap.error}')));
          final o = snap.data;
          if (o == null) return const Scaffold(body: Center(child: Text('No orders yet.', style: TextStyle(color: C.sub))));
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: !widget.latest,
              centerTitle: true,
              title: Column(children: [
                Text(o.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('Order #${o.shortNumber} • ${money(o.total)}', style: mono(11, C.sub)),
              ]),
              actions: [Padding(padding: const EdgeInsets.only(right: 12), child: SmallButton('Call', icon: Icons.call, onPressed: () => callCustomer(context, o.customerPhone)))],
            ),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [_seg('Timeline', 0), _seg('Chat', 1)]),
                ),
              ),
              Expanded(child: tab == 0 ? _timeline(o) : ChatPanel(orderId: o.id, customerName: o.customerName, customerPhone: o.customerPhone)),
            ]),
          );
        },
      );

  Widget _seg(String t, int i, {String? badge}) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => tab = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: tab == i ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: tab == i ? C.text : C.sub)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: C.secondary, borderRadius: BorderRadius.circular(10)),
                  child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
        ),
      );

  Widget _timeline(OrderDetail o) => ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.local_shipping_outlined)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(o.courier.isEmpty ? 'Standard Delivery' : '${o.courier[0].toUpperCase()}${o.courier.substring(1)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Pill(o.label, o.color, dot: false),
                ]),
                Text('${o.tracking.isEmpty ? 'No tracking ID yet' : o.tracking} • ${money(o.total)} (${o.paymentMethod.toUpperCase()})', style: mono(11, C.sub)),
              ]),
            ),
          ]),
        ),
        SectionLabel('Order lifecycle', trailing: Text('${o.timeline.length} Events', style: const TextStyle(fontSize: 11, color: C.sub))),
        AppCard(
          child: Column(children: [
            if (o.timeline.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No events recorded yet.', style: TextStyle(color: C.sub))),
            for (final (i, e) in o.timeline.indexed)
              IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: i == 0 ? Colors.white : C.line, border: i == 0 ? Border.all(color: C.secondary, width: 4) : null),
                    ),
                    if (i < o.timeline.length - 1) Expanded(child: Container(width: 1.5, color: C.line)),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                          Text(timeAgo(e.at), style: mono(11, C.sub, FontWeight.w600)),
                        ]),
                        if (e.description.isNotEmpty) Text(e.description, style: const TextStyle(fontSize: 12, color: C.sub)),
                        if (e.actor.isNotEmpty) Text(e.actor, style: const TextStyle(fontSize: 11, color: C.neutral)),
                      ]),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ]);
}
