import 'package:flutter/material.dart';

class BackgroundForChatcolor extends StatelessWidget {
  const BackgroundForChatcolor({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isDarkMode) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.35, 0.7, 1.0],
            colors: [
              Color(0xFF0A1734), // Navy-based deep blue at top
              Color(0xFF0E214A), // Slightly brighter blue
              Color(0xFF122A66), // Rich navy-blue
              Color(0xFF0D1B3E), // Deep midnight blue
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
    );
  }
}
