import 'package:flutter/material.dart';
import 'api.dart';
import 'notifier.dart';
import 'screens/login.dart';
import 'shell.dart';
import 'theme.dart';

void main() => runApp(const MerchantApp());

class MerchantApp extends StatefulWidget {
  const MerchantApp({super.key});
  @override
  State<MerchantApp> createState() => _MerchantAppState();
}

class _MerchantAppState extends State<MerchantApp> {
  @override
  void initState() {
    super.initState();
    api.restore();
    api.addListener(_sync);
  }

  int? _watching;

  /// Start/stop new-order alerts whenever the login or selected store changes.
  void _sync() {
    final id = api.loggedIn ? api.store?.id : null;
    if (id == _watching) return;
    _watching = id;
    id == null ? notifier.stop() : notifier.start();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'totalshop',
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: ListenableBuilder(
          listenable: api,
          builder: (_, _) {
            if (!api.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            if (!api.loggedIn) return const LoginScreen();
            if (api.store == null) return const StorePickerScreen();
            return Shell(key: ValueKey(api.store!.id));
          },
        ),
      );
}
