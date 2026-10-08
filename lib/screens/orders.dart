import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../pay_badge.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets.dart';
import 'create_order.dart';
import 'order_detail.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const filters = ['All', 'Pending payment', 'Processing', 'On hold', 'Completed', 'Cancelled', 'Refunded', 'Failed'];
  static const values = ['', 'pending', 'processing', 'on-hold', 'completed', 'cancelled', 'refunded', 'failed'];

  int filter = 0;
  String query = '';
  final items = <OrderSummary>[];
  int page = 1;
  bool more = false, loading = true, loadingMore = false;
  Object? error;
  Stats? stats;

  @override
  void initState() {
    super.initState();
    ordersFilter.addListener(_external);
    refresh();
  }

  @override
  void dispose() {
    ordersFilter.removeListener(_external);
    super.dispose();
  }

  void _external() {
    final f = ordersFilter.value;
    if (f == null) return;
    ordersFilter.value = null;
    filter = f;
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = items.isEmpty;
      error = null;
    });
    try {
      final r = await Future.wait([api.orders(status: values[filter], search: query), api.stats()]);
      final o = r[0] as Paged<OrderSummary>;
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(o.items);
        more = o.more;
        page = 1;
        stats = r[1] as Stats;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => (error = e, loading = false));
    }
  }

  Future<void> loadMore() async {
    setState(() => loadingMore = true);
    try {
      final o = await api.orders(status: values[filter], search: query, page: page + 1);
      if (!mounted) return;
      setState(() {
        items.addAll(o.items);
        more = o.more;
        page++;
      });
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen()));
          refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Order', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
            const Row(children: [Icon(Icons.arrow_back), Spacer(), Icon(Icons.search), SizedBox(width: 14), Icon(Icons.tune)]),
            const SizedBox(height: 8),
            const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Orders', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              Spacer(),
              Text('totalshop v1.0', style: TextStyle(fontSize: 12, color: C.sub)),
            ]),
            const SizedBox(height: 14),
            if (stats != null)
              Row(children: [
                Expanded(child: _Mini('PENDING', stats!.woo['pending'] ?? 0, 'pay', Woo.pending.color)),
                const SizedBox(width: 8),
                Expanded(child: _Mini('PROCESSING', stats!.woo['processing'] ?? 0, 'live', Woo.processing.color)),
                const SizedBox(width: 8),
                Expanded(child: _Mini('ON HOLD', stats!.woo['on-hold'] ?? 0, 'held', Woo.onHold.color)),
              ]),
            const SizedBox(height: 14),
            SearchField('Search order or customer...', onSubmitted: (v) {
              query = v.trim();
              refresh();
            }),
            const SizedBox(height: 12),
            FilterChips(filters, filter, (i) {
              filter = i;
              refresh();
            }, dots: {1: Woo.pending.color, 2: Woo.processing.color, 3: Woo.onHold.color}),
            const SizedBox(height: 14),
            SectionLabel('All orders', trailing: Text('${items.length}${more ? '+' : ''} shown', style: const TextStyle(fontSize: 11, color: C.sub))),
            if (loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: C.sub)),
                  OutlinedButton(onPressed: refresh, child: const Text('Retry')),
                ]),
              ),
            if (!loading && error == null && items.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No orders found.', style: TextStyle(color: C.sub)))),
            for (final o in items) _OrderCard(o, onBack: refresh),
            if (more) Center(child: loadingMore ? const CircularProgressIndicator() : TextButton(onPressed: loadMore, child: const Text('Load more'))),
            const SizedBox(height: 70),
          ]),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label, unit;
  final int value;
  final Color color;
  const _Mini(this.label, this.value, this.unit, this.color);
  @override
  Widget build(BuildContext context) => AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('● $label', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
          Text.rich(TextSpan(children: [
            TextSpan(text: '$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            TextSpan(text: ' $unit', style: const TextStyle(fontSize: 11, color: C.sub)),
          ])),
        ]),
      );
}

class _OrderCard extends StatelessWidget {
  final OrderSummary o;
  final VoidCallback onBack;
  const _OrderCard(this.o, {required this.onBack});
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(o.id)));
          onBack();
        },
        child: Column(children: [
          Row(children: [
            Text('#${o.shortNumber}', style: mono(13, null, FontWeight.w600)),
            Text('  •  ${timeAgo(o.createdAt)}', style: const TextStyle(fontSize: 12, color: C.sub)),
            const Spacer(),
            Pill(o.label, o.color, icon: o.woo.icon),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Avatar(initialsOf(o.customerName), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (o.area.isNotEmpty) Text(o.area, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.sub)),
              ]),
            ),
            const Icon(Icons.chevron_right, size: 18, color: C.sub),
          ]),
          const Divider(height: 22, color: C.line),
          Row(children: [
            const Icon(Icons.shopping_bag_outlined, size: 16, color: C.sub),
            const SizedBox(width: 6),
            Text('${o.itemsCount} items', style: const TextStyle(fontSize: 12, color: C.sub)),
            const SizedBox(width: 10),
            PayLogo(payOf(o.paymentMethod), height: 18),
            if (o.paymentStatus == 'paid') const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.check_circle, size: 14, color: C.green)),
            const Spacer(),
            Text(money(o.total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ]),
      );
}
