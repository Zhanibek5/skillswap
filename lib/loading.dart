import 'package:flutter/material.dart';
import 'dart:async';
import 'package:skillswap/MainPage/skillMain.dart';

class Screen extends StatefulWidget {
  const Screen({Key? key}) : super(key: key);

  @override
  State<Screen> createState() => _ScreenState();
}

class _ScreenState extends State<Screen> with SingleTickerProviderStateMixin {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();

    // Start fade-in effect after a short delay
    Timer(const Duration(milliseconds: 10), () {
      setState(() => _opacity = 1.0);
    });

    // Navigate to MainPage with fade transition
    Timer(const Duration(seconds: 5), () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const SkillMainPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedOpacity(
        duration: const Duration(seconds: 2),
        opacity: _opacity,
        child: SizedBox.expand(
          child: Image.asset(
            'assets/IMG_5578.JPG',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
