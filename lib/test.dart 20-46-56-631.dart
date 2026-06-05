import 'package:flutter/material.dart';
import 'package:skillswap/background/backgroundColor.dart';

void main() {
  runApp(MaterialApp(
    home: SafeArea(child: MyWidget()),
  ));
}

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
        begin: Alignment.topLeft, // Сол жақ жоғарғы бұрыштан бастау
        end: Alignment.bottomCenter, // Оң жақ төменгі бұрышқа қарай
        stops: [
          0.0,
          0.05,
          0.25,
          0.4,
          0.6,
          0.8,
          1.0
        ], // Ақ түстің тез таралуы үшін stop-тарды өзгертіңіз
        colors: [
          Colors.white.withOpacity(0.8), // Күн сәулесі (ақ түс)
          Color(0xFFE3F2FD), // Ашық көк түс (өтпелі кезең)
          Color(0xFF1E88E5), // Орташа көк түс

          Color(0xFF1565C0),
          Color(0xFF1E88E5),
          Color(0xFFE3F2FD),
          Colors.white, // Қою көк (негізгі түс)
        ],
      )),
    );
  }
}
