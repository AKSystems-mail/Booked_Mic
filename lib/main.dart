// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:home_widget/home_widget.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

// Import your screen widgets and services
import 'firebase_options.dart';
import 'widgets/booked_mic_loading.dart';
import 'registration_screen.dart';
import 'role_selection_screen.dart';
import 'host_screens/created_lists_screen.dart';
import 'performer_screens/performer_list_screen.dart';
import 'performer_screens/nearby_mics_screen.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'providers/firestore_provider.dart';
import 'services/settings_service.dart';

// Helper: lightweight client-side logging to Firestore for diagnostics
Future<void> addClientLog(String level, String msg, {String? uid, Map<String, dynamic>? meta}) async {
  try {
    await FirebaseFirestore.instance.collection('client_logs').add({
      'level': level,
      'message': msg,
      'uid': uid ?? FirebaseAuth.instance.currentUser?.uid,
      'meta': meta ?? {},
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    // Swallow errors to avoid crashing the app during diagnostics
    debugPrint('[client_log] failed to write log: $e');
  }
}



final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Handles data-only FCM messages when the app is killed or in background.
/// Uses flutterLocalNotificationsPlugin because it works in the background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Must initialize flutterLocalNotificationsPlugin in this background isolate
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
  final InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  final data = message.data;
  if (data['type'] == 'spot_update') {
    final title = data['title'] ?? 'Booked Mic Update';
    final body = data['body'] ?? 'Your spot has updated.';
    final listId = data['listId'] ?? '';

    flutterLocalNotificationsPlugin.show(
      listId.hashCode + data.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'spot_updates_channel',
          'Spot Updates',
          channelDescription: 'Notifications for queue position updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: listId,
    );
  }
}

/// Handles FCM data messages while the app is in the foreground.
void _handleForegroundFcmMessage(RemoteMessage message) {
  final data = message.data;
  if (data['type'] == 'spot_update') {
    HapticFeedback.heavyImpact();
    final title = data['title'] ?? 'Booked Mic Update';
    final body = data['body'] ?? 'Your spot has updated.';
    final listId = data['listId'] ?? '';
    flutterLocalNotificationsPlugin.show(
      listId.hashCode + data.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'spot_updates_channel',
          'Spot Updates',
          channelDescription: 'Notifications for queue position updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      payload: listId,
    );
  }
}

/// Handles when user taps a notification from terminated/background state.
void _handleNotificationTap(RemoteMessage message) {
  final data = message.data;
  if (data['type'] == 'spot_update') {
    final listId = data['listId'] ?? '';
    debugPrint('[notif_tap] User tapped spot_update notification for list: $listId');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register background FCM handler BEFORE Firebase init (required by FCM docs)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundFcmMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  }

  debugPrint('[main] Firebase initialized. currentUser=${FirebaseAuth.instance.currentUser?.uid ?? 'null'}');
  // Also log to Firestore for post-mortem diagnostics (non-blocking)
  addClientLog('info', 'firebase_initialized', meta: {'currentUser': FirebaseAuth.instance.currentUser?.uid});

  // Log auth events to help diagnose unexpected sign-outs
  FirebaseAuth.instance.idTokenChanges().listen((user) {
    debugPrint('[main] idTokenChanges: user=${user?.uid ?? 'null'} email=${user?.email ?? 'null'}');
    addClientLog('info', 'idTokenChanges', uid: user?.uid, meta: {'email': user?.email});
  });
  FirebaseAuth.instance.authStateChanges().listen((user) {
    debugPrint('[main] authStateChanges (global listener): user=${user?.uid ?? 'null'} email=${user?.email ?? 'null'}');
    addClientLog('info', 'authStateChanges', uid: user?.uid, meta: {'email': user?.email});
  });

  try {
     await dotenv.load(fileName: ".env");
  } catch (e) {
     debugPrint("Error loading .env file: $e");
  }

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
  final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings, onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirestoreProvider()),
        Provider(create: (_) => SettingsService.instance),
      ],
      child: const MyApp(),
    ),
  );
}

void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;
  if (payload != null) {
    debugPrint('Notification TAPPED - Payload: $payload');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
    final Color primaryBlue = Colors.blue.shade400;
    final Color buttonBlue = Colors.blue.shade600;

    final QuickActions quickActions = const QuickActions();

    @override
    void initState() {
      super.initState();
      WidgetsBinding.instance.addObserver(this);
      _setupQuickActions();
      _setupHomeWidgetLinks();
    }

    @override
    void dispose() {
      WidgetsBinding.instance.removeObserver(this);
      super.dispose();
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
      debugPrint('[lifecycle] state=$state');
      addClientLog('info', 'lifecycle', meta: {'state': state.toString()});
    }

    void _setupHomeWidgetLinks() {
      HomeWidget.setAppGroupId('group.bookedmic.app');
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        debugPrint('[HomeWidget] initiallyLaunchedFromHomeWidget: $uri (host=${uri?.host})');
        if (uri?.host == 'nearbyMics') {
          navigatorKey.currentState?.pushNamed('/nearbyMics');
        }
      });
      
      HomeWidget.widgetClicked.listen((uri) {
        debugPrint('[HomeWidget] widgetClicked: $uri (host=${uri?.host})');
        if (uri?.host == 'nearbyMics') {
          navigatorKey.currentState?.pushNamed('/nearbyMics');
        }
      });
    }

    void _setupQuickActions() {
      quickActions.setShortcutItems(<ShortcutItem>[
        const ShortcutItem(type: 'quick_scan', localizedTitle: 'Quick Scan', icon: 'ic_launcher'),
        const ShortcutItem(type: 'switch_role', localizedTitle: 'Switch Role', icon: 'ic_launcher'),
      ]);

      quickActions.initialize((shortcutType) async {
        final prefs = await SharedPreferences.getInstance();
        
        if (shortcutType == 'quick_scan') {
           await prefs.setString('user_role', 'performer');
           PerformerListScreen.autoScanTrigger = true;
           navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
        } else if (shortcutType == 'switch_role') {
           await prefs.remove('user_role');
           navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
        }
      });
    }

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Booked Mic',
        theme: ThemeData(
          primaryColor: primaryBlue,
          colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue, primary: primaryBlue, secondary: Colors.purple.shade100),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: AppBarTheme(backgroundColor: primaryBlue, foregroundColor: Colors.white, elevation: 0, titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500), iconTheme: const IconThemeData(color: Colors.white)),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: buttonBlue, minimumSize: const Size(double.infinity, 50), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), elevation: 5)),
          outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: buttonBlue, minimumSize: const Size(double.infinity, 50), padding: const EdgeInsets.symmetric(vertical: 12), side: BorderSide(color: buttonBlue, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white.withValues(alpha: 0.8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryBlue, width: 1.5)), labelStyle: TextStyle(color: Colors.grey.shade700), hintStyle: TextStyle(color: Colors.grey.shade500), prefixIconColor: Colors.grey.shade600),
          scaffoldBackgroundColor: Colors.purple.shade50,
          floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: primaryBlue, foregroundColor: Colors.white),
        ),
        home: const AuthWrapper(),
        routes: {
          '/registration': (context) => const RegistrationScreen(),
          '/roleSelection': (context) => const RoleSelectionScreen(),
          '/hostHome': (context) => CreatedListsScreen(),
          '/performerHome': (context) => PerformerListScreen(),
          '/nearbyMics': (context) => const NearbyMicsScreen(),
        },
      );
    }
}

class AuthWrapper extends StatefulWidget {
    const AuthWrapper({super.key});

    @override
    State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
    String? _lastEnsuredUserId;

    /// True once we've given Firebase Auth enough time to restore a persisted
    /// session.  Until this flips to true the widget shows a spinner instead of
    /// the login screen – eliminating the race between UI routing and the async
    /// credential restore that happens on every cold start.
    bool _authSettled = false;

    StreamSubscription<User?>? _authSubscription;

    @override
    void initState() {
      super.initState();
      // Listen in the background — triggers _ensureUserSetup whenever
      // Firebase Auth emits (cold-start restore, sign-in, sign-out, token refresh).
      // The StreamBuilder below reacts to the same stream for UI routing.
      _authSubscription =
          FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) _ensureUserSetup(user.uid);
      });
      _waitForAuthToSettle();
    }

    @override
    void dispose() {
      _authSubscription?.cancel();
      super.dispose();
    }

    /// Polls `currentUser` for up to 10 seconds on cold start for Google
    /// users (whose credential restore can be slow), or 2 seconds for
    /// email/password users (whose local session resolves almost instantly).
    /// During the wait we also attempt Google silent sign-in to re-hydrate
    /// the Firebase Auth session on devices where native persistence lags.
    Future<void> _waitForAuthToSettle() async {
      addClientLog('info', 'auth_settle_start');

      const int intervalMs = 250;
      final prefs = await SharedPreferences.getInstance();
      final bool hasLastUid = prefs.containsKey('last_known_uid');

      // Only Google users need the long timeout — email/password auth
      // restores from local persistence nearly instantly.
      bool isGoogleUser = false;
      if (hasLastUid && !kIsWeb) {
        try {
          isGoogleUser = await GoogleSignIn().isSignedIn();
        } catch (_) {}
      }

      const int returningTimeoutMs = 10000;
      const int freshTimeoutMs = 2000;
      final int timeoutMs = isGoogleUser ? returningTimeoutMs : freshTimeoutMs;
      int waited = 0;

      addClientLog('info', 'auth_settle_config',
          meta: {'hasLastUid': hasLastUid, 'isGoogleUser': isGoogleUser, 'timeoutMs': timeoutMs});

      while (waited < timeoutMs) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          addClientLog('info', 'auth_settle_resolved_early',
              uid: user.uid, meta: {'waitedMs': waited});
          break;
        }

        // If we've been waiting for 2 seconds with no user and the user
        // might be a Google user, try silent sign-in to re-hydrate the
        // Firebase Auth session.
        if (waited >= 2000 && !kIsWeb && isGoogleUser && waited < 3000) {
          try {
            final googleUser = await GoogleSignIn().signInSilently()
                .timeout(const Duration(seconds: 2));
            if (googleUser != null) {
              final googleAuth = await googleUser.authentication;
              final credential = GoogleAuthProvider.credential(
                accessToken: googleAuth.accessToken,
                idToken: googleAuth.idToken,
              );
              await FirebaseAuth.instance.signInWithCredential(credential);
            }
          } catch (_) {
            // Silent sign-in failed – the user probably used email/password
            // or their Google session has expired.  Continue polling.
          }
        }

        await Future.delayed(const Duration(milliseconds: intervalMs));
        waited += intervalMs;
      }

      addClientLog('info', 'auth_settle_done',
          meta: {'hasUser': FirebaseAuth.instance.currentUser != null, 'waitedMs': waited});

      if (mounted) {
        setState(() => _authSettled = true);
      }
    }

    Future<String?> _getSavedRole() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_role');
    }

    void _ensureUserSetup(String uid) {
      if (_lastEnsuredUserId == uid) return;
      _lastEnsuredUserId = uid;
      _saveLastKnownUid(uid);

      debugPrint("[AuthWrapper] Running background setup for UID: $uid");
      UserService().ensureHostCode().then((code) {
        debugPrint("[AuthWrapper] Setup complete. Code: $code");
      }).catchError((e) {
        debugPrint("[AuthWrapper] ensureHostCode error: $e");
      });
      UserService().cacheStageName();
      NotificationService().startListening(uid);
      FcmService().init(uid).catchError((e) {
        debugPrint("[AuthWrapper] FcmService.init error: $e");
      });
    }

    Future<void> _saveLastKnownUid(String uid) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_known_uid', uid);
      } catch (_) {}
    }

    static Future<void> clearLastKnownUid() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_known_uid');
      } catch (_) {}
    }

    @override
    Widget build(BuildContext context) {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          debugPrint('[AuthWrapper] authSnapshot: state=${authSnapshot.connectionState} '
              'hasData=${authSnapshot.hasData} error=${authSnapshot.error} '
              'authSettled=$_authSettled');

          final user = authSnapshot.data ?? FirebaseAuth.instance.currentUser;

          if (user != null) {
            // _ensureUserSetup is now handled by the stream listener
            // in initState, not from inside the build method.

            return FutureBuilder<String?>(
              future: _getSavedRole(),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: BookedMicLoading()));
                }

                final role = roleSnapshot.data;
                if (role == 'host') {
                  return CreatedListsScreen();
                } else if (role == 'performer') {
                  return PerformerListScreen();
                } else {
                  return const RoleSelectionScreen();
                }
              },
            );
          }

          if (!_authSettled) {
            return const Scaffold(body: Center(child: BookedMicLoading()));
          }

          return const RegistrationScreen();
        },
      );
    }
}
