import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../contact.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_tracking.dart';

/// Conversation with a customer about one order. Messages go to the customer by SMS (sent by the server) or WhatsApp
/// (opened on this phone); replies that arrive by phone or WhatsApp can be logged so the whole story stays in one place.
class ChatPanel extends StatefulWidget {
  final int orderId;
  final String customerName, customerPhone;
  const ChatPanel({super.key, required this.orderId, required this.customerName, required this.customerPhone});
  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final text = TextEditingController();
  final scroll = ScrollController();
  List<ChatMessage>? messages;
  Object? error;
  Timer? timer;
  bool sending = false;
  String channel = 'sms';

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 15), (_) => load(quiet: true));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load({bool quiet = false}) async {
    try {
      final m = await api.chatMessages(widget.orderId);
      if (!mounted) return;
      final grew = messages == null || m.length != messages!.length;
      setState(() => (messages = m, error = null));
      if (grew) WidgetsBinding.instance.addPostFrameCallback((_) => _toEnd());
    } catch (e) {
      if (mounted && !quiet) setState(() => error = e);
    }
  }

  void _toEnd() {
    if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> send() async {
    final body = text.text.trim();
    if (body.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      if (channel == 'whatsapp') {
        final opened = await openWhatsApp(context, widget.customerPhone, text: body);
        if (!opened) return;
      }
      await api.sendChat(widget.orderId, body, channel: channel);
      text.clear();
      await load();
    } on ApiException catch (e) {
      if (mounted) toast(context, channel == 'sms' ? 'SMS could not be sent. ${e.message}' : e.message);
      await load(quiet: true);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> logReply() async {
    final c = TextEditingController();
    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Add the customer's reply", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Customers answer by phone, SMS or WhatsApp. Type what they said so it is saved with this order.', style: TextStyle(fontSize: 12, color: C.sub)),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Please deliver after 6 PM',
              filled: true,
              fillColor: C.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton('Save reply', onPressed: () => Navigator.pop(ctx, c.text.trim())),
        ]),
      ),
    );
    if (body == null || body.isEmpty) return;
    try {
      await api.sendChat(widget.orderId, body, channel: 'note', incoming: true);
      await load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = messages;
    return Column(children: [
      Expanded(
        child: list == null
            ? Center(child: error == null ? const CircularProgressIndicator() : Text('$error', style: const TextStyle(color: C.sub)))
            : list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.chat_bubble_outline, size: 40, color: C.neutral),
                        const SizedBox(height: 10),
                        Text('Start a chat with ${widget.customerName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        const Text('Your message is sent to their phone by SMS or WhatsApp.', textAlign: TextAlign.center, style: TextStyle(color: C.sub, fontSize: 13)),
                      ]),
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _Bubble(list[i], showDay: i == 0 || _day(list[i - 1].at) != _day(list[i].at)),
                  ),
      ),
      Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Text('Send via', style: TextStyle(fontSize: 11, color: C.sub)),
              const SizedBox(width: 8),
              _chip('SMS', Icons.sms_outlined, 'sms'),
              const SizedBox(width: 6),
              _chip('WhatsApp', Icons.chat, 'whatsapp'),
              const Spacer(),
              TextButton.icon(
                onPressed: logReply,
                icon: const Icon(Icons.reply, size: 15),
                label: const Text("Add customer's reply", style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: C.sub, visualDensity: VisualDensity.compact),
              ),
            ]),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: text,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: channel == 'sms' ? 'Type an SMS...' : 'Type a WhatsApp message...',
                    filled: true,
                    fillColor: C.chip,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: sending ? null : send,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(color: C.primary, shape: BoxShape.circle),
                  child: sending
                      ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white, size: 19),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }

  Widget _chip(String label, IconData icon, String value) {
    final on = channel == value;
    return GestureDetector(
      onTap: () => setState(() => channel = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? C.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? C.primary : C.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: on ? Colors.white : C.sub),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : C.text)),
        ]),
      ),
    );
  }

  String _day(String iso) => (DateTime.tryParse(iso)?.toLocal().toString() ?? '').split(' ').first;
}

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  final bool showDay;
  const _Bubble(this.m, {required this.showDay});

  @override
  Widget build(BuildContext context) {
    final mine = m.mine;
    final failed = m.status == 'failed';
    final via = switch (m.channel) { 'whatsapp' => 'WhatsApp', 'sms' => 'SMS', 'call' => 'Call', _ => 'Logged' };
    return Column(children: [
      if (showDay)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Tag(placedAt(m.at).startsWith('Today') ? 'TODAY' : (timeAgo(m.at).split(',').first).toUpperCase()),
        ),
      Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
          decoration: BoxDecoration(
            color: failed ? const Color(0xFFFDECEC) : (mine ? C.primary : C.chip),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.body, style: TextStyle(color: failed ? C.red : (mine ? Colors.white : C.text), height: 1.3)),
            const SizedBox(height: 4),
            Text(
              '${timeAgo(m.at)} · ${mine ? via : 'Customer ($via)'}${failed ? ' · not sent' : ''}',
              style: TextStyle(fontSize: 10, color: failed ? C.red : (mine ? Colors.white60 : C.sub)),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Messages tab: every conversation, newest first, plus recent orders to start a new one.
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  Future<(List<ChatThread>, List<OrderSummary>)> _load() async {
    final r = await Future.wait([api.chatThreads(), api.orders(perPage: 8)]);
    return (r[0] as List<ChatThread>, (r[1] as Paged<OrderSummary>).items);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Messages', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        body: Loader<(List<ChatThread>, List<OrderSummary>)>(
          load: _load,
          poll: const Duration(seconds: 30),
          builder: (context, d, reload) {
            final (threads, recent) = d;
            final talking = threads.map((t) => t.orderId).toSet();
            final starters = recent.where((o) => !talking.contains(o.id)).toList();
            Future<void> open(int id) async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: id, openChat: true)));
              reload(silent: true);
            }

            return ListView(padding: const EdgeInsets.all(16), physics: const AlwaysScrollableScrollPhysics(), children: [
              const SectionLabel('Conversations'),
              if (threads.isEmpty)
                const AppCard(
                  child: Row(children: [
                    Icon(Icons.chat_bubble_outline, color: C.neutral),
                    SizedBox(width: 12),
                    Expanded(child: Text('No conversations yet. Pick an order below to message its customer.', style: TextStyle(color: C.sub, fontSize: 13))),
                  ]),
                ),
              for (final t in threads)
                AppCard(
                  onTap: () => open(t.orderId),
                  child: Row(children: [
                    Avatar(initialsOf(t.customerName), size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(t.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                          Text(timeAgo(t.last.at), style: const TextStyle(fontSize: 11, color: C.sub)),
                        ]),
                        Text('Order #${t.shortNumber}', style: mono(11, C.sub)),
                        const SizedBox(height: 2),
                        Text('${t.last.mine ? 'You: ' : ''}${t.last.body}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              if (starters.isNotEmpty) ...[
                const SectionLabel('Start a conversation'),
                for (final o in starters)
                  AppCard(
                    onTap: () => open(o.id),
                    child: Row(children: [
                      Avatar(initialsOf(o.customerName), size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('Order #${o.shortNumber} · ${o.label}', style: const TextStyle(fontSize: 12, color: C.sub)),
                        ]),
                      ),
                      const Icon(Icons.chat_outlined, size: 18, color: C.sub),
                    ]),
                  ),
              ],
            ]);
          },
        ),
      );
}
