import 'package:flutter/material.dart';
import 'package:skillswap/firstPage/pageView.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skillswap/firstPage/loadingPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:skillswap/loginPage/login_page.dart';
import 'package:skillswap/loginPage/register_page.dart';
import 'package:skillswap/loginPage/reset_password_page.dart';
import 'package:skillswap/loginPage/change_password_page.dart';
import 'package:skillswap/loginPage/delete_account_page.dart';
import 'package:skillswap/loginPage/verify_email.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';
import 'loading.dart';
import 'package:skillswap/MainPage/skillMain.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:skillswap/MainPage/chat/chatPage.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message received: ${message.data}");
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await EasyLocalization.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? code = prefs.getString('selected_language');
  Locale startLocale = const Locale('en');
  if (code == 'kk') {
    startLocale = const Locale('kk');
  } else if (code == 'ru') startLocale = const Locale('ru');

  if (Platform.isAndroid) {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([newToken]),
      }, SetOptions(merge: true));
    });
  }
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: iosSettings,
  );
  await EasyLocalization.ensureInitialized();

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chatIdFromNotification', payload);
      }
    },
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'skillswap_channel',
    'SkillSwap Notifications',
    description: 'Meeting notifications',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  if (Platform.isAndroid) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final data = message.data;

    final title = data['title'] ?? 'New Message';
    final body = data['body'] ?? '';

    flutterLocalNotificationsPlugin.show(
      id: (data['chatId'] ?? '').hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'skillswap_channel',
          'SkillSwap Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: data['chatId'],
    );
  });
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('kk'), Locale('ru')],
      path: 'assets/translations',
      fallbackLocale: const Locale('kk'),
      saveLocale: true,
      startLocale: startLocale,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.black,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
        ),
      ),
      themeMode: settingsProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      title: "Firebase Auth App",
      home: const AuthGate(),
      routes: {
        'firstPage/loadingPage.dart': (context) => SplashScreen(),
        'loginPage/login_page.dart': (_) => const LoginPage(),
        'loginPage/register_page.dart': (_) => const RegisterPage(),
        'loginPage/reset_password_page.dart': (_) =>
            const ResetPasswordPage(email: ""),
        'loginPage/change_password_page.dart': (_) =>
            const ChangePasswordPage(),
        'loginPage/delete_account_page.dart': (_) => const DeleteAccountPage(),
        'MainPage/skillMain.dart': (_) => SkillMainPage(),
        'loginPage/verify_email.dart': (_) => const VerifyEmailPage(),
      },

      // initialRoute: 'MainPage/skillMain.dart',
      // initialRoute: 'loginPage/verify_email.dart',
      initialRoute: 'firstPage/loadingPage.dart',
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isFirstLaunch = true;
  String? _chatIdFromNotification;
  String? _otherUserIdFromNotification;
  List<String>? _selectedSkillsFromNotification;
  @override
  void initState() {
    super.initState();

    _checkFirstLaunch();

    setupNotifications();
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null && message.data['chatId'] != null) {
        setState(() {
          _chatIdFromNotification = message.data['chatId'];
          _otherUserIdFromNotification = message.data['otherUserId'] ?? '';
          _selectedSkillsFromNotification =
              (message.data['selectedSkills'] ?? '').split(',');
        });
      }
    });

    // App фоннан ашылғанда хабарламаны өңдеу
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(message);
    });
  }

  void _handleMessage(RemoteMessage message) {
    if (!mounted) return;
    final data = message.data;
    if (data['chatId'] != null) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => SkillMainPage(initialIndex: 0),
        ),
        (route) => false,
      );

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            chatId: data['chatId'],
            otherUserId: data['otherUserId'] ?? '',
            selectedSkills: data['selectedSkills'] != null &&
                    data['selectedSkills'].isNotEmpty
                ? data['selectedSkills'].split(",")
                : [],
            mode: 'chat',
          ),
        ),
      );
    }
  }

  Future<void> _loadNotificationChatId() async {
    final prefs = await SharedPreferences.getInstance();
    final chatId = prefs.getString('chatIdFromNotification');
    if (chatId != null && chatId.isNotEmpty) {
      setState(() {
        _chatIdFromNotification = chatId;
      });
      prefs.remove('chatIdFromNotification');
    }
  }

  Future<void> setupNotifications() async {
    if (Platform.isAndroid) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      await messaging.requestPermission();

      String? token = await messaging.getToken();

      if (token != null) {
        print("🔥 FCM TOKEN: $token");
      }
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    bool first = prefs.getBool('isFirstLaunch') ?? true;
    setState(() {
      _isFirstLaunch = first;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ... (басқа тексерістер)

    if (_chatIdFromNotification != null &&
        _chatIdFromNotification!.isNotEmpty) {
      final chatId = _chatIdFromNotification!;
      final otherUserId = _otherUserIdFromNotification ?? '';
      final selectedSkills = _selectedSkillsFromNotification ?? [];

      _chatIdFromNotification = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Бұл жерде pushAndRemoveUntil қолданған абзал, стек таза болу үшін
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => SkillMainPage(initialIndex: 0)),
        );

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatPage(
              chatId: chatId,
              otherUserId: otherUserId,
              selectedSkills: selectedSkills,
              mode: 'chat',
            ),
          ),
        );
      });

      return SkillMainPage(
          initialIndex: 0); // Негізгі экран астында 0 боп тұрады
    }

    // Қалыпты логин болғанда:
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SplashScreen();
    if (!user.emailVerified) return const VerifyEmailPage();

    return SkillMainPage(initialIndex: 1);
  }
}
