import 'package:flutter/material.dart';
import 'package:skillswap/firstPage/pageView.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skillswap/firstPage/loadingPage.dart';
import 'package:skillswap/loginPage/auth_layout.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:skillswap/firstPage/pageView.dart';
import 'package:skillswap/loginPage/login_page.dart';
import 'package:skillswap/loginPage/register_page.dart';
import 'package:skillswap/loginPage/login_page.dart';
import 'package:skillswap/loginPage/reset_password_page.dart';
import 'package:skillswap/loginPage/change_password_page.dart';
import 'package:skillswap/loginPage/delete_account_page.dart';
import 'package:skillswap/loginPage/verify_email.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'settings_provider.dart';
import 'loading.dart';
import 'package:skillswap/MainPage/skillMain.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String? code = prefs.getString('selected_language'); // 'en'/'kk'/'ru'
  Locale startLocale = const Locale('en');
  if (code == 'kk')
    startLocale = const Locale('kk');
  else if (code == 'ru') startLocale = const Locale('ru');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
    return MaterialApp(
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
      themeMode: ThemeMode.system,
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
        'MainPage/skillMain.dart': (_) => const SkillMainPage(),
        'loginPage/verify_email.dart': (_) => const VerifyEmailPage(),
        'secondPage/loading.dart': (_) => const Screen()
      },
      initialRoute: 'MainPage/skillMain.dart',
      // initialRoute: 'loginPage/verify_email.dart',
      //initialRoute: 'firstPage/loadingPage.dart',
    );
  }
}

/// --------------------------------------------------------------
/// 🔥 AUTH GATE — decides which screen to show:
/// - Not logged in → LoginPage
/// - Logged in but NOT verified → EmailVerificationPage
/// - Logged in and verified → MainPage
/// --------------------------------------------------------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
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
    if (_isFirstLaunch) {
      return SplashScreen(); // ← Міне, осы жерде 3-5 секундтық анимация көрсетіледі
    }

    if (_isFirstLaunch) {
      // Егер алғаш қосылып тұрса → onboarding көрсету
      return OnboardingScreen(); // Сенікі pageView.dart файлыңдағы
    }

    // Әйтпесе → Firebase auth бойынша бағыттау
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginPage();
    } else if (!user.emailVerified) {
      return const VerifyEmailPage();
    } else {
      return const Screen();
    }
  }
}
