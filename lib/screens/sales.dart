import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  static const stages = [
    ('new', 'New', C.neutral),
    ('confirmed', 'Confirmed', Color(0xFF555555)),
    ('preparing', 'Preparing', C.secondary),
    ('ready', 'Ready to Ship', C.tertiary),
    ('shipped', 'Shipped', C.primary),
    ('delivered', 'Delivered', C.green),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chevron_left), label: const Text('More')),
          leadingWidth: 90,
          title: const Text('Sales & Performance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Center(child: Tag('Today ▾')))],
        ),
        body: Loader<Stats>(
          load: api.stats,
          poll: const Duration(seconds: 30),
          builder: (context, s, reload) {
            final pct = s.changePct;
            final payTotal = s.cod + s.digital;
            return ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
              const Row(children: [
                Text('● LIVE PERFORMANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.secondary)),
                Spacer(),
                Text('Updated just now', style: TextStyle(fontSize: 10, color: C.sub)),
              ]),
              const SizedBox(height: 8),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('TOTAL SALES', style: TextStyle(fontSize: 10, color: C.sub, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (pct != null) Pill('${pct >= 0 ? '↗ +' : '↘ '}$pct%', pct >= 0 ? C.secondary : C.red, dot: false),
                  ]),
                  Text(money(s.todaySales), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
                  Row(children: [
                    const Icon(Icons.receipt_long_outlined, size: 13, color: C.sub),
                    Text(' ${s.todayOrders} Orders processed', style: const TextStyle(fontSize: 12, color: C.sub)),
                    const Spacer(),
                    const Text('vs yesterday', style: TextStyle(fontSize: 11, color: C.sub)),
                  ]),
                ]),
              ),
              Row(children: [
                Expanded(child: Stat('Avg order value', money(s.avgOrder), sub: '${s.avgChange >= 0 ? '+' : '-'}${money(s.avgChange.abs())} vs yesterday')),
                const SizedBox(width: 12),
                Expanded(child: Stat('Repeat rate', '${s.repeatRate}%', sub: '${s.returning} Returning')),
              ]),
              const SizedBox(height: 12),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Order Pipeline', style: TextStyle(fontWeight: FontWeight.w800)),
                        Text('Real-time fulfillment stages', style: TextStyle(fontSize: 11, color: C.sub)),
                      ]),
                    ),
                    Tag('${s.totalPipeline} Total'),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: s.totalPipeline == 0
                        ? Container(height: 8, color: C.line)
                        : Row(children: [for (final st in stages) if ((s.pipeline[st.$1]?.orders ?? 0) > 0) Expanded(flex: s.pipeline[st.$1]!.orders, child: Container(height: 8, color: st.$3))]),
                  ),
                  const SizedBox(height: 6),
                  for (final st in stages)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: st.$3, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Text(st.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${s.pipeline[st.$1]?.orders ?? 0} orders', style: const TextStyle(fontSize: 11, color: C.sub)),
                        const SizedBox(width: 12),
                        SizedBox(width: 80, child: Text(money(s.pipeline[st.$1]?.amount ?? 0), textAlign: TextAlign.right, style: mono(12, null, FontWeight.w600))),
                      ]),
                    ),
                ]),
              ),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Payment Distribution', style: TextStyle(fontWeight: FontWeight.w800)),
                  const Text('Method share by processed revenue', style: TextStyle(fontSize: 11, color: C.sub)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: payTotal == 0
                        ? Container(height: 8, color: C.line)
                        : Row(children: [
                            if (s.cod > 0) Expanded(flex: (s.cod * 100).round(), child: Container(height: 8, color: C.primary)),
                            if (s.digital > 0) Expanded(flex: (s.digital * 100).round(), child: Container(height: 8, color: C.secondary)),
                          ]),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _pay('Cash on Delivery', s.cod, payTotal, C.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: _pay('Pre-paid / Digital', s.digital, payTotal, C.secondary)),
                  ]),
                ]),
              ),
              GhostButton("Download Today's Manifest (PDF)", icon: Icons.description_outlined, onPressed: () => soon(context, 'The manifest export')),
              const Padding(padding: EdgeInsets.only(top: 6), child: Center(child: Text('Includes batch invoices, tracking IDs & barcodes', style: TextStyle(fontSize: 10, color: C.sub)))),
            ]);
          },
        ),
      );

  Widget _pay(String k, double v, double total, Color c) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('● $k', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
          Row(children: [
            Text(total == 0 ? '0%' : '${(v / total * 100).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(money(v), style: mono(10, C.sub)),
          ]),
        ]),
      );
}
