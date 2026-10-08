import 'package:flutter/material.dart';
import 'theme.dart';

/// Payment channels the merchant sees. Wallets (MFS) use their brand colour and name so they are recognisable at a glance.
enum Pay { cod, bkash, nagad, rocket, upay, other }

Pay payOf(String? method) => switch ((method ?? '').toLowerCase()) {
      'cod' || '' => Pay.cod,
      'bkash' => Pay.bkash,
      'nagad' => Pay.nagad,
      'rocket' => Pay.rocket,
      'upay' => Pay.upay,
      _ => Pay.other,
    };

extension PayInfo on Pay {
  String get label => switch (this) {
        Pay.cod => 'Cash on Delivery',
        Pay.bkash => 'bKash',
        Pay.nagad => 'Nagad',
        Pay.rocket => 'Rocket',
        Pay.upay => 'Upay',
        Pay.other => 'Online payment',
      };

  /// Short text drawn inside the badge.
  String get mark => switch (this) {
        Pay.cod => 'COD',
        Pay.bkash => 'bKash',
        Pay.nagad => 'Nagad',
        Pay.rocket => 'Rocket',
        Pay.upay => 'Upay',
        Pay.other => 'PAY',
      };

  Color get color => switch (this) {
        Pay.cod => const Color(0xFF16A34A),
        Pay.bkash => const Color(0xFFE2136E),
        Pay.nagad => const Color(0xFFEE4023),
        Pay.rocket => const Color(0xFF8C3494),
        Pay.upay => const Color(0xFF0B8F4D),
        Pay.other => C.neutral,
      };

  bool get isWallet => this == Pay.bkash || this == Pay.nagad || this == Pay.rocket || this == Pay.upay;
}

/// Small coloured badge: wallet name on its brand colour (COD shows a cash icon).
class PayLogo extends StatelessWidget {
  final Pay pay;
  final double height;
  final bool muted;
  const PayLogo(this.pay, {super.key, this.height = 22, this.muted = false});

  @override
  Widget build(BuildContext context) {
    // bKash: only the bird mark (no wordmark), on a white chip with a pink edge.
    if (pay == Pay.bkash && !muted) {
      return Container(
        height: height,
        width: height * 1.25,
        padding: EdgeInsets.all(height * .12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(height * .3),
          border: Border.all(color: pay.color.withValues(alpha: .45)),
        ),
        child: Image.asset('assets/pay/bkash_icon.png', fit: BoxFit.contain, semanticLabel: 'bKash'),
      );
    }
    final bg = muted ? C.line : pay.color;
    final fg = muted ? C.neutral : Colors.white;
    return Container(
      height: height,
      constraints: BoxConstraints(minWidth: height * 1.5),
      padding: EdgeInsets.symmetric(horizontal: height * .36),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(height * .3)),
      child: pay == Pay.cod
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.payments_outlined, size: height * .62, color: fg),
              SizedBox(width: height * .15),
              Text('COD', style: TextStyle(color: fg, fontSize: height * .46, fontWeight: FontWeight.w800, letterSpacing: .3)),
            ])
          : Text(pay.mark, style: TextStyle(color: fg, fontSize: height * .5, fontWeight: FontWeight.w800, fontStyle: pay.isWallet ? FontStyle.italic : FontStyle.normal)),
    );
  }
}

/// Badge plus a plain-language sentence, e.g. "[bKash] Paid with bKash".
class PayLine extends StatelessWidget {
  final String method;
  final bool paid, awaiting;
  const PayLine({super.key, required this.method, required this.paid, this.awaiting = false});

  @override
  Widget build(BuildContext context) {
    final p = payOf(method);
    final (text, color) = paid
        ? ('Paid with ${p.label}', C.green)
        : p == Pay.cod
            ? ('Customer pays cash on delivery', C.orange)
            : awaiting
                ? ('Waiting for ${p.label} payment', C.orange)
                : ('${p.label} payment not received', C.red);
    return Row(children: [
      PayLogo(p, height: 24),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color))),
      Icon(paid ? Icons.check_circle : Icons.schedule, size: 18, color: color),
    ]);
  }
}
