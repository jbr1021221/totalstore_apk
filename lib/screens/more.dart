import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'customer.dart';
import 'sales.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = api.user, s = api.store;
    return Scaffold(
      body: SafeArea(
        child: Loader<Stats>(
          load: api.stats,
          builder: (context, st, reload) => ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
            Row(children: [
              Container(width: 26, height: 26, decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 15)),
              const SizedBox(width: 8),
              const Text('totalshop', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              const Icon(Icons.search),
              const SizedBox(width: 14),
              GestureDetector(onTap: () => soon(context, 'Help'), child: const Icon(Icons.help_outline)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              const Text('More', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              const Spacer(),
              const Pill('Accepting Orders', C.green),
            ]),
            const SizedBox(height: 12),
            AppCard(
              onTap: () => _switchStore(context),
              child: Column(children: [
                Row(children: [
                  Avatar(initialsOf(u?.name ?? ''), size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Flexible(child: Text(u?.name ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), const SizedBox(width: 6), if (s?.isOwner == true) const Tag('Owner')]),
                      Text('${s?.name ?? ''} (#STORE-${s?.id})', style: const TextStyle(fontSize: 12, color: C.sub)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: C.sub),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _kpi('MERCHANT LEVEL', '—')),
                  const SizedBox(width: 10),
                  Expanded(child: _kpi('FULFILLMENT RATE', st.fulfillmentRate == null ? '—' : '${st.fulfillmentRate}%')),
                ]),
              ]),
            ),
            const SectionLabel('Business'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _row(Icons.people_outline, 'Customers', '${st.customers} accounts registered', null, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()))),
                const Divider(height: 1, color: C.line),
                _row(Icons.insights, 'Sales & Analytics', money(st.todaySales) + ' today', st.changePct == null ? null : '${st.changePct! >= 0 ? '+' : ''}${st.changePct}%', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()))),
              ]),
            ),
            const SectionLabel('Store & fulfillment'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _row(Icons.storefront_outlined, 'Store Profile & Hours', 'Not set', null, () => soon(context, 'Store profile')),
                const Divider(height: 1, color: C.line),
                _row(Icons.local_shipping_outlined, 'Delivery Settings', 'Inside Dhaka ${money(70)}, Outside ${money(130)}', null, () => soon(context, 'Delivery settings')),
                const Divider(height: 1, color: C.line),
                _row(Icons.warehouse_outlined, 'Inventory & Warehouses', 'Catalog stock', null, () => soon(context, 'Warehouses')),
              ]),
            ),
            const SectionLabel('Preferences & app'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _row(Icons.notifications_none, 'Push Notifications', 'Orders, Messages', null, () => soon(context, 'Push notifications')),
                const Divider(height: 1, color: C.line),
                _row(Icons.shield_outlined, 'Account & Security', null, null, () => soon(context, 'Account settings')),
                const Divider(height: 1, color: C.line),
                _row(Icons.help_outline, 'Help & Support', null, null, () => soon(context, 'Support')),
              ]),
            ),
            const SizedBox(height: 4),
            Material(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: api.logout,
                child: const Padding(padding: EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.logout, color: C.red, size: 18), SizedBox(width: 8), Text('Log out', style: TextStyle(color: C.red, fontWeight: FontWeight.w700))])),
              ),
            ),
            const SizedBox(height: 12),
            const Center(child: Text('totalshop Merchant v1.0.0', style: TextStyle(fontSize: 11, color: C.sub))),
          ]),
        ),
      ),
    );
  }

  Widget _kpi(String k, String v) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(fontSize: 9, color: C.sub, fontWeight: FontWeight.w700)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      );

  Widget _row(IconData i, String t, String? sub, String? badge, VoidCallback onTap) => ListTile(
        leading: Icon(i),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: sub == null ? null : Text(sub, style: const TextStyle(fontSize: 11)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (badge != null) Text(badge, style: TextStyle(color: badge.startsWith('-') ? C.red : C.green, fontWeight: FontWeight.w700, fontSize: 12)),
          const Icon(Icons.chevron_right),
        ]),
        onTap: onTap,
      );

  void _switchStore(BuildContext context) {
    if (api.stores.length < 2) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Switch store', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final st in api.stores)
            ListTile(
              leading: Icon(st.id == api.store?.id ? Icons.radio_button_checked : Icons.radio_button_off, color: C.primary),
              title: Text(st.name),
              onTap: () {
                Navigator.pop(context);
                api.selectStore(st);
              },
            ),
        ]),
      ),
    );
  }
}
