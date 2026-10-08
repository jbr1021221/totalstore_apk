import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'create_order.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});
  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final items = <ProductItem>[];
  List<ProdCategory> cats = [];
  int cat = 0; // 0 = all, otherwise index+1 into cats
  String query = '';
  int page = 1, units = 0, total = 0;
  bool more = false, loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    api.categories().then((c) => mounted ? setState(() => cats = c.take(6).toList()) : null).catchError((_) {});
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = items.isEmpty;
      error = null;
    });
    try {
      final r = await api.products(search: query, category: cat == 0 ? null : cats[cat - 1].id);
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(r.items);
        more = r.more;
        page = 1;
        units = r.meta['units_total'] ?? 0;
        total = r.meta['total'] ?? r.items.length;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => (error = e, loading = false));
    }
  }

  Future<void> loadMore() async {
    final r = await api.products(search: query, page: page + 1, category: cat == 0 ? null : cats[cat - 1].id);
    if (!mounted) return;
    setState(() {
      items.addAll(r.items);
      more = r.more;
      page++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Catalog', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          actions: const [Icon(Icons.search), SizedBox(width: 16)],
        ),
        body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
            SearchField('Search products...', onSubmitted: (v) {
              query = v.trim();
              refresh();
            }),
            const SizedBox(height: 12),
            FilterChips(['All', ...cats.map((c) => c.name)], cat, (i) {
              cat = i;
              refresh();
            }),
            const SizedBox(height: 14),
            SectionLabel('Showing $total items', trailing: Text('● $units UNITS TOTAL', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.secondary))),
            if (loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            if (error != null) Center(child: Text('$error', style: const TextStyle(color: C.sub))),
            if (!loading && error == null && items.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No products found.', style: TextStyle(color: C.sub)))),
            for (final p in items) ProductCard(p),
            if (more) Center(child: TextButton(onPressed: loadMore, child: const Text('Load more'))),
          ]),
        ),
      );
}

class ProductThumb extends StatelessWidget {
  final ProductItem p;
  final double size;
  const ProductThumb(this.p, {super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size,
          height: size,
          color: C.chip,
          alignment: Alignment.center,
          child: p.imageUrl == null
              ? Text(p.title.substring(0, p.title.length.clamp(0, 2)).toUpperCase(), style: mono(size * .25, C.sub, FontWeight.w700))
              : Image.network(p.imageUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, color: C.neutral)),
        ),
      );
}

class ProductCard extends StatelessWidget {
  final ProductItem p;
  const ProductCard(this.p, {super.key});
  @override
  Widget build(BuildContext context) {
    final low = p.stock <= 10;
    return AppCard(
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ProductThumb(p),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (p.categories.isNotEmpty) Text(p.categories.join(' / '), style: const TextStyle(fontSize: 12, color: C.sub)),
              const SizedBox(height: 4),
              Text(money(p.price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ]),
          ),
          Pill(p.stock <= 0 ? 'Out of stock' : '${p.stock} in stock', p.stock <= 0 ? C.red : low ? C.orange : C.green, dot: false),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          GestureDetector(
            onTap: () => _details(context),
            child: const Text('View Details →', style: TextStyle(color: C.secondary, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          const Spacer(),
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: p.stock <= 0 ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateOrderScreen(product: p))),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add to Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(foregroundColor: C.text, side: const BorderSide(color: C.line)),
            ),
          ),
          const SizedBox(width: 10),
          Text(p.sku, style: mono(10, C.sub)),
        ]),
      ]),
    );
  }

  void _details(BuildContext context) => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [ProductThumb(p, size: 72), const SizedBox(width: 14), Expanded(child: Text(p.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)))]),
            const SizedBox(height: 14),
            KeyValue('Price', money(p.price)),
            KeyValue('In stock', '${p.stock}'),
            KeyValue('SKU', p.sku),
            if (p.categories.isNotEmpty) KeyValue('Categories', p.categories.join(', ')),
            const SizedBox(height: 8),
          ]),
        ),
      );
}
