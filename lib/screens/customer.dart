import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'create_order.dart';
import 'order_detail.dart';
import 'order_tracking.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final items = <CustomerItem>[];
  String query = '';
  int page = 1;
  bool more = false, loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = items.isEmpty;
      error = null;
    });
    try {
      final r = await api.customers(search: query);
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(r.items);
        more = r.more;
        page = 1;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => (error = e, loading = false));
    }
  }

  Future<void> loadMore() async {
    final r = await api.customers(search: query, page: page + 1);
    if (!mounted) return;
    setState(() {
      items.addAll(r.items);
      more = r.more;
      page++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Customers', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
            SearchField('Search name or phone...', scan: false, onSubmitted: (v) {
              query = v.trim();
              refresh();
            }),
            const SizedBox(height: 12),
            if (loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            if (error != null) Center(child: Text('$error', style: const TextStyle(color: C.sub))),
            for (final c in items)
              AppCard(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerScreen(c.id!))),
                child: Row(children: [
                  Avatar(initialsOf(c.name), size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(c.phone, style: mono(11, C.sub)),
                    ]),
                  ),
                  Tag('${c.totalOrders} orders'),
                ]),
              ),
            if (more) Center(child: TextButton(onPressed: loadMore, child: const Text('Load more'))),
          ]),
        ),
      );
}

class CustomerScreen extends StatelessWidget {
  final int id;
  const CustomerScreen(this.id, {super.key});

  @override
  Widget build(BuildContext context) => Loader<CustomerItem>(
        load: () => api.customer(id),
        builder: (context, c, reload) => Scaffold(
          appBar: AppBar(title: Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), actions: const [Icon(Icons.more_vert), SizedBox(width: 8)]),
          body: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
            AppCard(
              child: Column(children: [
                Row(children: [
                  Avatar(initialsOf(c.name), size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(c.phone, style: mono(12, C.sub)),
                      const SizedBox(height: 4),
                      if (c.verified) const Pill('Verified Buyer', C.secondary, dot: false),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: GhostButton('Call', icon: Icons.call, onPressed: () => callCustomer(context, c.phone))),
                  const SizedBox(width: 10),
                  Expanded(child: GhostButton('Message', icon: Icons.chat_outlined, onPressed: () => c.recent.isEmpty ? toast(context, 'This customer has no orders to message about yet.') : Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: c.recent.first.id, openChat: true))))),
                ]),
              ]),
            ),
            AppCard(
              child: Row(children: [
                _stat('${c.totalOrders}', 'Orders'),
                _stat(money(c.totalSpent), 'Total Spent'),
                _stat('${c.returns}', 'Returns'),
              ]),
            ),
            if (c.area.isNotEmpty)
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [Icon(Icons.location_on_outlined, size: 14, color: C.sub), SizedBox(width: 4), Text('DELIVERY ADDRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.sub))]),
                  const SizedBox(height: 6),
                  Text(c.area),
                ]),
              ),
            SectionLabel('Order History', trailing: Text('${c.recent.length} Recent', style: const TextStyle(fontSize: 11, color: C.sub))),
            if (c.recent.isEmpty) const AppCard(child: Text('No orders yet.', style: TextStyle(color: C.sub))),
            if (c.recent.isNotEmpty)
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final (i, o) in c.recent.indexed) ...[
                    if (i > 0) const Divider(height: 1, color: C.line),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(o.id))),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('#${o.shortNumber} • ${placedAt(o.createdAt)}', style: mono(12, null, FontWeight.w600)),
                              Text('${o.itemsCount} items ordered', style: const TextStyle(fontSize: 12, color: C.sub)),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Pill(o.label, o.color, dot: false),
                            Text(money(o.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ]),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),
          ]),
          bottomNavigationBar: BottomAction(children: [
            PrimaryButton('Create Order for ${c.name.split(' ').first}', icon: Icons.add,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateOrderScreen(customer: c)))),
          ]),
        ),
      );

  Widget _stat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(l, style: const TextStyle(fontSize: 11, color: C.sub)),
        ]),
      );
}
