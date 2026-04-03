import 'package:flutter/material.dart';
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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background message: ${message.notification?.title}");
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
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E88E5), // The app's signature blue
          secondary: Color(0xFF42A5F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F2EF),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1E88E5), // The app's signature blue 
          secondary: Color(0xFF42A5F5),
          surface: Color(0xFF121212),
          background: Color(0xFF0A0A0A),
          error: Color(0xFFCF6679),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Deep OLED-friendly black
        canvasColor: const Color(0xFF121212), 
        cardColor: const Color(0xFF1A1A1A), // Nicely elevated dark card
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0A),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF121212),
          selectedItemColor: Color(0xFF1E88E5),
          unselectedItemColor: Colors.grey,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xFF1E88E5).withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 4,
          shadowColor: Colors.black45,
          color: Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.5), 
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 24,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(), // Beautiful modern zoom transition
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
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
        'secondPage/loading.dart': (_) => const Screen()
      },

      // initialRoute: 'MainPage/skillMain.dart',
      // initialRoute: 'loginPage/verify_email.dart',
      //initialRoute: 'firstPage/loadingPage.dart',
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
            selectedSkills: data['selectedSkills']?.split(",") ?? [],
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
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => SkillMainPage(initialIndex: 0)),
          (route) => false,
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
    if (user == null) return const LoginPage();
    if (!user.emailVerified) return const VerifyEmailPage();

    return SkillMainPage(initialIndex: 1); // Дефолттық бет (Search)
  }
}
