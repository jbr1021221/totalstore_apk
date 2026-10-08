import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// WooCommerce-style status change: pick the next status (only the moves allowed from the current one),
/// read what it does, add an optional note, confirm. Pass [target] to jump straight to the confirm step.
/// Returns true when the order was changed.
Future<bool> changeStatus(BuildContext context, OrderDetail order, {Woo? target}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _StatusSheet(order, target),
  );
  return done == true;
}

class _StatusSheet extends StatefulWidget {
  final OrderDetail order;
  final Woo? target;
  const _StatusSheet(this.order, this.target);
  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late NextStatus? chosen = widget.target == null ? null : widget.order.next.where((n) => n.woo == widget.target).firstOrNull;
  final note = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> confirm() async {
    final c = chosen!;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.updateStatus(widget.order.id, c.woo.slug, notes: note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => (error = e.message, busy = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          if (chosen == null) ..._pick(o) else ..._confirm(o, chosen!),
        ]),
      ),
    );
  }

  List<Widget> _pick(OrderDetail o) => [
        Text('Change status', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Row(children: [
          Text('Order #${o.shortNumber} is ', style: const TextStyle(color: C.sub, fontSize: 13)),
          Pill(o.woo.label, o.woo.color, icon: o.woo.icon),
        ]),
        const SizedBox(height: 14),
        if (o.next.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('${o.woo.label} is final. No further status changes are possible.', style: const TextStyle(color: C.sub)),
          ),
        for (final n in o.next)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: C.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: C.line)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => chosen = n),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: n.woo.color.withValues(alpha: .12), shape: BoxShape.circle),
                      child: Icon(n.woo.icon, size: 19, color: n.woo.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.woo.label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: n.destructive ? C.red : C.text)),
                        const SizedBox(height: 2),
                        Text(n.note, style: const TextStyle(fontSize: 12, color: C.sub, height: 1.3)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: C.neutral),
                  ]),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        GhostButton('Close', onPressed: () => Navigator.pop(context, false)),
      ];

  List<Widget> _confirm(OrderDetail o, NextStatus c) => [
        const Text('Confirm status change', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Row(children: [
          Pill(o.woo.label, o.woo.color, icon: o.woo.icon),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 18, color: C.sub)),
          Pill(c.woo.label, c.woo.color, icon: c.woo.icon),
        ]),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)),
          child: Text(c.note, style: const TextStyle(fontSize: 13, height: 1.35)),
        ),
        if (o.bkashAwaiting && c.woo == Woo.processing)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('This order is still waiting for its bKash payment. Only continue if you received the money another way.', style: TextStyle(fontSize: 12, color: C.red)),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: note,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: c.destructive ? 'Reason (optional)' : 'Note (optional)',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
          ),
        ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: C.red))),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: busy ? null : confirm,
            style: FilledButton.styleFrom(
              backgroundColor: c.destructive ? C.red : C.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(busy ? 'Updating...' : 'Change to ${c.woo.label}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 8),
        GhostButton(widget.target == null ? 'Back' : 'Cancel', onPressed: busy ? null : () => widget.target == null ? setState(() => chosen = null) : Navigator.pop(context, false)),
      ];
}
