import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false, hide = true;
  String? error;

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.login(email.text.trim(), pass.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 56,
                      height: 56,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 28),
                    ),
                  ),
                  const Text('Merchant Direct', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Sign in with your totalshop account', style: TextStyle(color: C.sub)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: _dec('Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pass,
                    obscureText: hide,
                    onSubmitted: (_) => submit(),
                    decoration: _dec('Password').copyWith(
                      suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_off : Icons.visibility, size: 20), onPressed: () => setState(() => hide = !hide)),
                    ),
                  ),
                  if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: C.red))),
                  const SizedBox(height: 20),
                  PrimaryButton(busy ? 'Signing in...' : 'Sign in', onPressed: busy ? null : submit),
                ]),
              ),
            ),
          ),
        ),
      );

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
      );
}

class StorePickerScreen extends StatelessWidget {
  const StorePickerScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Choose a store'),
          actions: [TextButton(onPressed: api.logout, child: const Text('Log out'))],
        ),
        body: api.stores.isEmpty
            ? const Center(child: Text('No stores are linked to this account.', style: TextStyle(color: C.sub)))
            : ListView(padding: const EdgeInsets.all(16), children: [
                for (final s in api.stores)
                  AppCard(
                    onTap: () => api.selectStore(s),
                    child: Row(children: [
                      Avatar(s.name.substring(0, 1), size: 40),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                      if (s.isOwner) const Tag('Owner'),
                      const Icon(Icons.chevron_right, color: C.sub),
                    ]),
                  ),
              ]),
      );
}
