import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../pay_badge.dart';
import '../theme.dart';
import '../widgets.dart';
import 'catalog.dart';
import '../notifier.dart';
import 'order_confirmation.dart';

/// Delivery options come from the backend's shipping zones (config store.shipping_zones).
const zones = [
  ('inside_dhaka', 'Inside Dhaka', '24-48 hrs', 'Regular doorstep delivery by merchant fleet', 70),
  ('sub_dhaka', 'Sub-Dhaka', '48-72 hrs', 'Delivery to nearby areas around Dhaka', 100),
  ('outside_dhaka', 'Outside Dhaka', '3-5 days', 'Courier delivery across the country', 130),
];

class CreateOrderScreen extends StatefulWidget {
  final CustomerItem? customer;
  final ProductItem? product;
  const CreateOrderScreen({super.key, this.customer, this.product});
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  int step = 0;
  CustomerItem? buyer;
  String notes = '';
  final cart = <CartLine>[];
  int zone = 0;
  bool prepaid = false, busy = false;

  @override
  void initState() {
    super.initState();
    buyer = widget.customer;
    if (widget.product != null) cart.add(CartLine(widget.product!, 1));
  }

  double get subtotal => cart.fold(0, (a, l) => a + l.total);
  double get fee => zones[zone].$5.toDouble();

  Future<void> submit() async {
    final b = buyer!;
    setState(() => busy = true);
    try {
      final o = await api.createOrder(
        customer: {
          if (b.id != null) 'id': b.id,
          'name': b.name,
          'phone': b.phone,
          'address': b.address,
          'city': b.city,
        },
        lines: cart,
        shippingFee: fee,
        zone: zones[zone].$1,
        bkash: prepaid,
        notes: notes,
      );
      notifier.markSeen(o.id);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderConfirmationScreen(o)));
    } catch (e) {
      if (mounted) {
        toast(context, '$e');
        setState(() => busy = false);
      }
    }
  }

  Future<void> editNote() async {
    final c = TextEditingController(text: notes);
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Fulfillment note'),
        content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'Packaging instructions or promo tag')),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Save'))],
      ),
    );
    if (v != null) setState(() => notes = v.trim());
  }

  @override
  Widget build(BuildContext context) {
    final count = const [1, 2, 4][step];
    return Scaffold(
      appBar: AppBar(
        title: Column(children: [
          Text('${(api.store?.name ?? '').toUpperCase()} • NEW ORDER', style: const TextStyle(fontSize: 9, color: C.sub, letterSpacing: .5)),
          const Text('Create Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        centerTitle: true,
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Tag('$count of 4')))],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(color: i < count ? C.primary : C.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ]),
        ),
        Expanded(
          child: switch (step) {
            0 => _CustomerStep(selected: buyer, onSelect: (c) => setState(() => buyer = c), onEditNote: editNote, notes: notes),
            1 => _ProductStep(cart: cart, notes: notes, onChanged: () => setState(() {}), onEditNote: editNote),
            _ => _ReviewStep(
                buyer: buyer!,
                cart: cart,
                zone: zone,
                prepaid: prepaid,
                onZone: (v) => setState(() => zone = v),
                onPrepaid: (v) => setState(() => prepaid = v),
                onEditBuyer: () => setState(() => step = 0),
              ),
          },
        ),
      ]),
      bottomNavigationBar: BottomAction(children: [
        if (step == 0)
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Selected Buyer', style: TextStyle(fontSize: 10, color: C.sub)),
                Text(buyer?.name ?? 'None yet', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
            ),
            SizedBox(width: 240, child: PrimaryButton('Continue to Products', icon: Icons.arrow_forward, trailingIcon: true, onPressed: buyer == null ? null : () => setState(() => step = 1))),
          ])
        else if (step == 1) ...[
          PrimaryButton('Continue to Delivery (${money(subtotal)})', icon: Icons.arrow_forward, trailingIcon: true, onPressed: cart.isEmpty ? null : () => setState(() => step = 2)),
          const Padding(padding: EdgeInsets.only(top: 6), child: Text('Step 2/4', style: TextStyle(fontSize: 10, color: C.sub))),
        ] else ...[
          PrimaryButton(busy ? 'Creating...' : 'Create Order (${money(subtotal + fee)})', icon: Icons.check_circle_outline, onPressed: busy ? null : submit),
          TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: C.sub))),
        ],
        if (step > 0)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: busy ? null : () => setState(() => step--), icon: const Icon(Icons.arrow_back, size: 14), label: const Text('Back'))),
      ]),
    );
  }
}

class _CustomerStep extends StatefulWidget {
  final CustomerItem? selected;
  final ValueChanged<CustomerItem> onSelect;
  final VoidCallback onEditNote;
  final String notes;
  const _CustomerStep({required this.selected, required this.onSelect, required this.onEditNote, required this.notes});
  @override
  State<_CustomerStep> createState() => _CustomerStepState();
}

class _CustomerStepState extends State<_CustomerStep> {
  late Future<Paged<CustomerItem>> future = api.customers();

  Future<void> createNew() async {
    final name = TextEditingController(), phone = TextEditingController(), address = TextEditingController(), city = TextEditingController(text: 'Dhaka');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('New customer'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Delivery address')),
            TextField(controller: city, decoration: const InputDecoration(labelText: 'City')),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Use customer'))],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && phone.text.trim().isNotEmpty) {
      widget.onSelect(CustomerItem({'name': name.text.trim(), 'phone': phone.text.trim(), 'address': address.text.trim(), 'city': city.text.trim()}));
    } else if (ok == true && mounted) {
      toast(context, 'Name and phone are required');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Paged<CustomerItem>>(
        future: future,
        builder: (context, snap) {
          final list = snap.data?.items ?? [];
          final meta = snap.data?.meta ?? {};
          final sel = widget.selected;
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              const Text('STEP 1: CUSTOMER SELECTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.secondary)),
              const Spacer(),
              const Text('Step 2: Details', style: TextStyle(fontSize: 10, color: C.sub)),
            ]),
            const SizedBox(height: 8),
            const Text('Who is this order for?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const Text('Select a recorded buyer or initialize a new customer profile.', style: TextStyle(color: C.sub, fontSize: 13)),
            const SizedBox(height: 12),
            SearchField('Search existing customer (name or phone)', onSubmitted: (v) => setState(() => future = api.customers(search: v.trim()))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Stat('Active repeat', '${meta['total'] ?? '–'}', dot: C.secondary, sub: 'accounts')),
              const SizedBox(width: 12),
              Expanded(child: Stat('Dhaka region', '${meta['dhaka_pct'] ?? '–'}%', dot: C.tertiary, sub: 'coverage')),
            ]),
            const SizedBox(height: 14),
            SectionLabel('Recent customers', trailing: Text('${list.length} shown', style: const TextStyle(fontSize: 11, color: C.sub))),
            if (snap.connectionState != ConnectionState.done) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            if (snap.hasError) Text('${snap.error}', style: const TextStyle(color: C.sub)),
            for (final c in list)
              AppCard(
                onTap: () => widget.onSelect(c),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(sel?.id == c.id && sel != null ? Icons.radio_button_checked : Icons.radio_button_off, color: sel?.id == c.id ? C.primary : C.neutral),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))), Tag('${c.totalOrders} orders')]),
                      Text('${c.phone}  ·  ${c.city}', style: mono(11, C.sub)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [
                        if (c.address.isNotEmpty) const Tag('Address on file'),
                        if (c.lastOrderAt != null) Tag('Last: ${timeAgo(c.lastOrderAt)}'),
                      ]),
                    ]),
                  ),
                ]),
              ),
            DashedButton('Create New Customer', Icons.add, createNew),
            if (sel != null)
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('SELECTED ADDRESS SUMMARY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: C.sub)),
                    const Spacer(),
                    GestureDetector(onTap: widget.onEditNote, child: const Text('Edit Notes', style: TextStyle(fontSize: 12, color: C.secondary, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 6),
                  Text(sel.area.isEmpty ? 'No address on file' : sel.area, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Row(children: [Icon(Icons.info_outline, size: 13, color: C.sub), SizedBox(width: 4), Text('COD Available', style: TextStyle(fontSize: 11, color: C.sub))]),
                ]),
              ),
          ]);
        },
      );
}

class _ProductStep extends StatefulWidget {
  final List<CartLine> cart;
  final String notes;
  final VoidCallback onChanged, onEditNote;
  const _ProductStep({required this.cart, required this.notes, required this.onChanged, required this.onEditNote});
  @override
  State<_ProductStep> createState() => _ProductStepState();
}

class _ProductStepState extends State<_ProductStep> {
  List<ProdCategory> cats = [];
  int cat = 0;
  String query = '';
  late Future<Paged<ProductItem>> future = api.products();

  @override
  void initState() {
    super.initState();
    api.categories().then((c) => mounted ? setState(() => cats = c.take(5).toList()) : null).catchError((_) {});
  }

  void reload() => setState(() => future = api.products(search: query, category: cat == 0 ? null : cats[cat - 1].id));

  void add(ProductItem p) {
    final ex = widget.cart.where((l) => l.product.id == p.id).firstOrNull;
    if (ex != null) {
      if (ex.qty < p.stock) ex.qty++;
    } else {
      widget.cart.add(CartLine(p, 1));
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    final sub = cart.fold<double>(0, (a, l) => a + l.total);
    return FutureBuilder<Paged<ProductItem>>(
      future: future,
      builder: (context, snap) {
        final list = snap.data?.items ?? [];
        return ListView(padding: const EdgeInsets.all(16), children: [
          SearchField('Search products by name or SKU...', onSubmitted: (v) {
            query = v.trim();
            reload();
          }),
          const SizedBox(height: 10),
          FilterChips(['All Catalog', ...cats.map((c) => c.name)], cat, (i) {
            cat = i;
            reload();
          }),
          SectionLabel('Available Products (${list.length} ready)', trailing: Text(api.store?.name ?? '', style: const TextStyle(fontSize: 11, color: C.secondary, fontWeight: FontWeight.w700))),
          if (snap.connectionState != ConnectionState.done) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (snap.hasError) Text('${snap.error}'),
          for (final p in list)
            AppCard(
              child: Row(children: [
                ProductThumb(p, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(p.categories.join(' / '), style: const TextStyle(fontSize: 12, color: C.sub)),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: money(p.price), style: const TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: '  •  In stock: ${p.stock}', style: const TextStyle(fontSize: 11, color: C.sub)),
                    ])),
                  ]),
                ),
                OutlinedButton.icon(
                  onPressed: p.stock <= 0 ? null : () => add(p),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add'),
                  style: OutlinedButton.styleFrom(foregroundColor: C.text, side: const BorderSide(color: C.text), visualDensity: VisualDensity.compact),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Icon(Icons.shopping_bag_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('Selected Items (${cart.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  const Tag('Draft Line Items'),
                ]),
              ),
              if (cart.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(14, 0, 14, 14), child: Text('No products added yet.', style: TextStyle(color: C.sub))),
              for (final l in cart) ...[
                const Divider(height: 1, color: C.line),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.product.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${money(l.product.price)} unit', style: const TextStyle(fontSize: 11, color: C.sub)),
                        GestureDetector(
                          onTap: () {
                            cart.remove(l);
                            widget.onChanged();
                          },
                          child: const Padding(padding: EdgeInsets.only(top: 6), child: Row(children: [Icon(Icons.delete_outline, size: 14, color: C.red), Text(' Remove', style: TextStyle(color: C.red, fontSize: 11))])),
                        ),
                      ]),
                    ),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        InkWell(onTap: l.qty > 1 ? () { l.qty--; widget.onChanged(); } : null, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 16))),
                        Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        InkWell(onTap: l.qty < l.product.stock ? () { l.qty++; widget.onChanged(); } : null, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 16))),
                      ]),
                    ),
                    SizedBox(
                      width: 78,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(money(l.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const Text('LINE TOTAL', style: TextStyle(fontSize: 8, color: C.sub)),
                      ]),
                    ),
                  ]),
                ),
              ],
              const Divider(height: 1, color: C.line),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w800)),
                  const Text('  Taxes & shipping added in Step 3', style: TextStyle(fontSize: 10, color: C.sub)),
                  const Spacer(),
                  Text(money(sub), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                ]),
              ),
            ]),
          ),
          AppCard(
            onTap: widget.onEditNote,
            child: Row(children: [
              const Icon(Icons.edit_note, color: C.sub),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Fulfillment Note (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(widget.notes.isEmpty ? 'Add packaging instructions or promo tag' : widget.notes, style: const TextStyle(fontSize: 11, color: C.sub)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: C.sub),
            ]),
          ),
        ]);
      },
    );
  }
}

class _ReviewStep extends StatelessWidget {
  final CustomerItem buyer;
  final List<CartLine> cart;
  final int zone;
  final bool prepaid;
  final ValueChanged<int> onZone;
  final ValueChanged<bool> onPrepaid;
  final VoidCallback onEditBuyer;
  const _ReviewStep({required this.buyer, required this.cart, required this.zone, required this.prepaid, required this.onZone, required this.onPrepaid, required this.onEditBuyer});

  @override
  Widget build(BuildContext context) {
    final sub = cart.fold<double>(0, (a, l) => a + l.total);
    final fee = zones[zone].$5.toDouble();
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Row(children: [Text('Delivery & Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), Spacer(), Text('75% Completed', style: TextStyle(fontSize: 11, color: C.sub))]),
      const SizedBox(height: 12),
      SectionLabel('Customer & delivery', trailing: GestureDetector(onTap: onEditBuyer, child: const Text('Edit Link', style: TextStyle(fontSize: 11, color: C.secondary, fontWeight: FontWeight.w700)))),
      AppCard(
        child: Column(children: [
          Row(children: [
            Avatar(initialsOf(buyer.name), size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(buyer.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(buyer.phone, style: mono(11, C.sub)),
              ]),
            ),
            if (buyer.verified) const Tag('Verified'),
          ]),
          const Divider(height: 20, color: C.line),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on_outlined, size: 18, color: C.sub),
            const SizedBox(width: 8),
            Expanded(child: Text(buyer.area.isEmpty ? 'No address provided' : buyer.area, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        ]),
      ),
      const SectionLabel('Delivery method'),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (i, z) in zones.indexed) ...[
            if (i > 0) const Divider(height: 1, color: C.line),
            InkWell(
              onTap: () => onZone(i),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(zone == i ? Icons.radio_button_checked : Icons.radio_button_off, color: zone == i ? C.primary : C.neutral),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Text(z.$2, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(width: 8), Tag(z.$3)]),
                      Text(z.$4, style: const TextStyle(fontSize: 11, color: C.sub)),
                    ]),
                  ),
                  Text(money(z.$5), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ],
        ]),
      ),
      const SectionLabel('Payment method'),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          _pay(false, Pay.cod, 'Cash on Delivery', 'Customer pays cash when the parcel arrives'),
          const Divider(height: 1, color: C.line),
          _pay(true, Pay.bkash, 'bKash — pay before delivery', 'Customer gets a payment link by SMS. The order confirms itself when they pay.'),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          const Text('Other wallets, coming soon:', style: TextStyle(fontSize: 11, color: C.sub)),
          const SizedBox(width: 8),
          for (final w in [Pay.nagad, Pay.rocket, Pay.upay]) ...[PayLogo(w, height: 18, muted: true), const SizedBox(width: 6)],
        ]),
      ),
      SectionLabel('Order summary', trailing: Text('${cart.length} items', style: const TextStyle(fontSize: 11, color: C.sub))),
      AppCard(
        child: Column(children: [
          for (final l in cart)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text('${l.product.title} × ${l.qty}', style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(money(l.total), style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          KeyValue('Delivery Fee', money(fee)),
          const Divider(color: C.line),
          KeyValue('TOTAL', money(sub + fee), bold: true),
        ]),
      ),
    ]);
  }

  Widget _pay(bool value, Pay pay, String t, String s) => InkWell(
        onTap: () => onPrepaid(value),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(prepaid == value ? Icons.radio_button_checked : Icons.radio_button_off, color: prepaid == value ? C.primary : C.neutral),
            const SizedBox(width: 12),
            PayLogo(pay, height: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(s, style: const TextStyle(fontSize: 11, color: C.sub)),
              ]),
            ),
          ]),
        ),
      );
}
