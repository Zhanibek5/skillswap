import 'package:flutter/material.dart';

class Backgroundcolor extends StatelessWidget {
  const Backgroundcolor({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isDarkMode) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.4, 0.8, 1.0],
            colors: [
              Color(0xFF0F172A), // Very dark blue/grey
              Color(0xFF050A15),
              Color(0xFF02040A),
              Colors.black,
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [
          0.0,
          0.4,
          0.75,
          1.0,
        ],
        colors: [
          Color(0xFF1565C0),
          Color(0xFF1E88E5),
          Color(0xFFE3F2FD),
          Colors.white,
        ],
      )),
    );
  }
}
