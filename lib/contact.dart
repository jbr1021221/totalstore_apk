import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets.dart';

/// Opens the phone's dialer with [phone] filled in. Falls back to copying the number when no dialer exists
/// (browsers on a computer, emulators).
Future<void> callPhone(BuildContext context, String phone) async {
  final number = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (number.isEmpty) return toast(context, 'This customer has no phone number.');
  final ok = await launchUrl(Uri(scheme: 'tel', path: number)).catchError((_) => false);
  if (!ok && context.mounted) {
    Clipboard.setData(ClipboardData(text: number));
    toast(context, 'Cannot place calls on this device. Number $number copied.');
  }
}

/// Bangladeshi mobile numbers written 01XXXXXXXXX become international 8801XXXXXXXXX for WhatsApp.
String whatsappNumber(String phone) {
  var n = phone.replaceAll(RegExp(r'\D'), '');
  if (n.startsWith('00')) n = n.substring(2);
  if (n.startsWith('0')) n = '88$n';
  return n;
}

/// Opens a WhatsApp chat with the customer, with [text] ready to send. Returns whether WhatsApp opened.
Future<bool> openWhatsApp(BuildContext context, String phone, {String text = ''}) async {
  final uri = Uri.https('wa.me', '/${whatsappNumber(phone)}', text.isEmpty ? null : {'text': text});
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) toast(context, 'Could not open WhatsApp.');
  return ok;
}
