import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding, margin;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: Material(
          color: C.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: C.line)),
          child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .8, color: C.sub)),
          if (trailing != null) trailing!,
        ]),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool dot;
  final IconData? icon;
  const Pill(this.text, this.color, {super.key, this.dot = true, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          if (dot && icon == null) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

class Tag extends StatelessWidget {
  final String text;
  const Tag(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(5)),
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: C.sub)),
      );
}

class Avatar extends StatelessWidget {
  final String initials;
  final double size;
  const Avatar(this.initials, {super.key, this.size = 36});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: C.chip, shape: BoxShape.circle),
        child: Text(initials, style: TextStyle(fontSize: size * .33, fontWeight: FontWeight.w700, color: C.sub)),
      );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool trailingIcon;
  final VoidCallback? onPressed;
  const PrimaryButton(this.label, {super.key, this.icon, this.onPressed, this.trailingIcon = false});
  @override
  Widget build(BuildContext context) {
    final ic = icon == null ? null : Icon(icon, size: 18);
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: C.primary,
          disabledBackgroundColor: const Color(0xFFBDBDC2),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (ic != null && !trailingIcon) ...[ic, const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          if (ic != null && trailingIcon) ...[const SizedBox(width: 8), ic],
        ]),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  const GhostButton(this.label, {super.key, this.icon, this.onPressed, this.height = 44});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: C.text,
            side: const BorderSide(color: C.line),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
}

class SmallButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const SmallButton(this.label, {super.key, this.icon, this.onPressed});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: C.text,
          backgroundColor: Colors.white,
          side: const BorderSide(color: C.line),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 15, color: C.secondary),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged, onSubmitted;
  final bool scan;
  const SearchField(this.hint, {super.key, this.onChanged, this.onSubmitted, this.scan = true});
  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: C.neutral),
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: scan ? const Icon(Icons.qr_code_scanner, size: 20) : null,
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
        ),
      );
}

class FilterChips extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final Map<int, Color> dots;
  const FilterChips(this.items, this.selected, this.onSelected, {super.key, this.dots = const {}});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == selected ? C.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: i == selected ? C.primary : C.line),
              ),
              child: Row(children: [
                Text(items[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: i == selected ? Colors.white : C.text)),
                if (dots[i] != null) ...[
                  const SizedBox(width: 5),
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: dots[i], shape: BoxShape.circle)),
                ],
              ]),
            ),
          ),
        ),
      );
}

class KeyValue extends StatelessWidget {
  final String k, v;
  final bool bold;
  const KeyValue(this.k, this.v, {super.key, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(k, style: TextStyle(fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
          const SizedBox(width: 12),
          Text(v, style: TextStyle(fontSize: bold ? 22 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}

class BottomAction extends StatelessWidget {
  final List<Widget> children;
  const BottomAction({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
        child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: children)),
      );
}

class Stat extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Color? dot;
  final Color? subColor;
  const Stat(this.label, this.value, {super.key, this.sub, this.dot, this.subColor});
  @override
  Widget build(BuildContext context) => AppCard(
        margin: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (dot != null) ...[
              Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 5),
            ],
            Flexible(child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .6, color: C.sub))),
          ]),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          if (sub != null) Text(sub!, style: TextStyle(fontSize: 11, color: subColor ?? C.sub)),
        ]),
      );
}

class DashedButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const DashedButton(this.label, this.icon, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CustomPaint(
          foregroundPainter: _Dash(),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ),
        ),
      );
}

class _Dash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = C.neutral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

void toast(BuildContext c, String msg) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

void soon(BuildContext c, [String what = 'This']) => toast(c, '$what isn\'t connected to the backend yet.');

/// Loads data from the API, shows spinner/error states, supports pull-to-refresh
/// and optional background polling so the screen stays in sync with the web app.
class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function({bool silent}) reload) builder;
  final Duration? poll;
  const Loader({super.key, required this.load, required this.builder, this.poll});
  @override
  State<Loader<T>> createState() => LoaderState<T>();
}

class LoaderState<T> extends State<Loader<T>> with WidgetsBindingObserver {
  T? data;
  Object? error;
  bool loading = true;
  Timer? timer;
  DateTime? updated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload();
    if (widget.poll != null) timer = Timer.periodic(widget.poll!, (_) => reload(silent: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload(silent: true);
  }

  Future<void> reload({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        data = d;
        error = null;
        loading = false;
        updated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent || data == null) error = e;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      if (loading) return const Material(color: C.bg, child: Center(child: CircularProgressIndicator()));
      return Material(
        color: C.bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off, size: 40, color: C.neutral),
              const SizedBox(height: 10),
              Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: C.sub)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: reload, child: const Text('Retry')),
            ]),
          ),
        ),
      );
    }
    return RefreshIndicator(onRefresh: () => reload(silent: true), child: widget.builder(context, data as T, reload));
  }
}

/// Copy-on-tap value row (e.g. bKash number, transaction id).
class CopyRow extends StatelessWidget {
  final String label, value;
  const CopyRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          toast(context, '$label copied');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Text(label, style: const TextStyle(fontSize: 12, color: C.sub)),
            const SizedBox(width: 12),
            Expanded(child: Text(value, textAlign: TextAlign.right, style: mono(13, null, FontWeight.w700))),
            const SizedBox(width: 6),
            const Icon(Icons.copy, size: 13, color: C.neutral),
          ]),
        ),
      );
}
