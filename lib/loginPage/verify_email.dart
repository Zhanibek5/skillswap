import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillswap/MainPage/skillMain.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundColor.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  Timer? timer;
  bool isEmailVerified = false;

  @override
  void initState() {
    super.initState();

    // First check
    isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;

    // If not verified → start checking every 3 seconds
    if (!isEmailVerified) {
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }
  }

  Future<void> checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser!.reload();
    final user = FirebaseAuth.instance.currentUser;

    if (user!.emailVerified) {
      timer?.cancel();

      setState(() => isEmailVerified = true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SkillMainPage()),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            'verify_email'.tr(),
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Backgroundcolor(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.email_outlined,
                        size: 80, color: Color(0xFF203068)),
                    SizedBox(height: 20),
                    Text(
                      'verification_email_sent'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Color(0xFF203068)),
                    ),
                    SizedBox(height: 10),
                    Text(
                      FirebaseAuth.instance.currentUser!.email ?? "",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF203068)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ));
  }
}
