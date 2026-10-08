import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../notifier.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_detail.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  Future<(Stats, List<OrderSummary>)> _load() async {
    final r = await Future.wait([api.stats(), api.orders(perPage: 3)]);
    return (r[0] as Stats, (r[1] as Paged<OrderSummary>).items);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
  }

  void _open(int filter) {
    ordersFilter.value = filter;
    onNavigate(1);
  }

  @override
  Widget build(BuildContext context) {
    final first = (api.user?.name ?? '').split(' ').first;
    return Scaffold(
      body: SafeArea(
        child: Loader<(Stats, List<OrderSummary>)>(
          load: _load,
          poll: const Duration(seconds: 30),
          builder: (context, d, reload) {
            final (s, recent) = d;
            final pct = s.changePct;
            return ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$_greeting, $first 👋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(api.store?.name ?? '', style: const TextStyle(color: C.sub)),
                  ]),
                ),
                ListenableBuilder(
                  listenable: notifier,
                  builder: (_, _) => GestureDetector(
                    onTap: () {
                      notifier.clearUnseen();
                      _open(1);
                    },
                    child: Badge(
                      isLabelVisible: notifier.unseen > 0,
                      label: Text('${notifier.unseen}'),
                      backgroundColor: C.red,
                      child: const Icon(Icons.notifications_none),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              const SectionLabel("Today's overview", trailing: Text('Live update', style: TextStyle(fontSize: 11, color: C.sub))),
              Row(children: [
                Expanded(child: Stat('Sales', money(s.todaySales), dot: C.secondary, sub: pct == null ? '${money(s.todayPaid)} paid' : '${pct >= 0 ? '↗ +' : '↘ '}$pct%', subColor: pct == null ? null : pct >= 0 ? C.green : C.red)),
                const SizedBox(width: 12),
                Expanded(child: Stat('Orders', '${s.todayOrders}', dot: C.tertiary, sub: '${s.todayProcessed} processed')),
              ]),
              const SizedBox(height: 16),
              const SectionLabel('● Needs attention', trailing: Text('Action required', style: TextStyle(fontSize: 11, color: C.sub))),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _attn(Woo.pending.color, '${s.woo['pending'] ?? 0} Pending payment', 'Waiting for payment or confirmation', 1),
                  const Divider(height: 1, color: C.line),
                  _attn(Woo.processing.color, '${s.woo['processing'] ?? 0} Processing', 'Pack, ship and deliver', 2),
                  const Divider(height: 1, color: C.line),
                  _attn(Woo.onHold.color, '${s.woo['on-hold'] ?? 0} On hold', 'Paused orders to look at', 3),
                ]),
              ),
              SectionLabel('Recent orders',
                  trailing: GestureDetector(
                    onTap: () => _open(0),
                    child: const Text('View all orders →', style: TextStyle(fontSize: 12, color: C.secondary, fontWeight: FontWeight.w600)),
                  )),
              if (recent.isEmpty) const AppCard(child: Text('No orders yet.', style: TextStyle(color: C.sub))),
              if (recent.isNotEmpty)
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final (i, o) in recent.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: C.line),
                      InkWell(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(o.id)));
                          reload(silent: true);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text.rich(TextSpan(children: [
                                  TextSpan(text: '#${o.shortNumber}', style: mono(13, null, FontWeight.w600)),
                                  TextSpan(text: '  ·  ${o.customerName}', style: const TextStyle(fontSize: 13)),
                                ])),
                                Text(money(o.total), style: mono(12, C.sub)),
                              ]),
                            ),
                            Pill(o.label, o.color, dot: false),
                          ]),
                        ),
                      ),
                    ],
                  ]),
                ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _attn(Color color, String t, String s, int filter) => InkWell(
        onTap: () => _open(filter),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(s, style: const TextStyle(fontSize: 12, color: C.sub)),
              ]),
            ),
            const Text('View', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Icon(Icons.chevron_right, size: 18),
          ]),
        ),
      );
}
