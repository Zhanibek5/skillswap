import 'package:flutter/material.dart';

class MeetingFinishedPage extends StatelessWidget {
  const MeetingFinishedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Meeting Finished',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
