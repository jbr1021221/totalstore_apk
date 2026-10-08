import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'notifier.dart';
import 'screens/order_detail.dart';

/// Firebase Cloud Messaging: lets the server alert this phone about new orders even when the app is closed.
/// If Firebase isn't configured (no google-services.json) or the phone can't register, [active] stays false
/// and the app falls back to polling in [Notifier].
class Push {
  bool active = false;
  bool _initialised = false, _listening = false;
  String? _token;

  Future<void> init() async {
    if (kIsWeb || _initialised) return;
    try {
      await Firebase.initializeApp();
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      _token = await m.getToken();
      _initialised = true;

      if (!_listening) {
        _listening = true;
        // App in the foreground: FCM shows nothing itself, so run the normal alert path.
        FirebaseMessaging.onMessage.listen((_) => notifier.checkNow());
        FirebaseMessaging.onMessageOpenedApp.listen(_open);
        m.onTokenRefresh.listen((t) {
          _token = t;
          register();
        });
        final launch = await m.getInitialMessage();
        if (launch != null) _open(launch);
      }
    } catch (e) {
      debugPrint('Firebase unavailable, using polling: $e');
      active = false;
    }
  }

  /// Tell the server this phone belongs to the signed-in store. Safe to call repeatedly.
  Future<void> register() async {
    final t = _token;
    if (!_initialised || t == null || !api.loggedIn || api.store == null) return;
    try {
      await api.registerDevice(t);
      active = true;
    } catch (_) {
      active = false;
    }
  }

  void _open(RemoteMessage m) {
    final id = int.tryParse('${m.data['order_id'] ?? ''}');
    if (id != null) navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => OrderDetailScreen(id)));
  }
}

final push = Push();
