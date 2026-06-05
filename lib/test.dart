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
    return Backgroundcolor();
  }
}
