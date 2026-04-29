import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class VideoMeetingPage extends StatefulWidget {
  final String meetingId; // Firestore-дағы кездесу ID
  final List<String> participants; // Қатысушылар ID-лері

  const VideoMeetingPage({
    super.key,
    required this.meetingId,
    required this.participants,
  });

  @override
  State<VideoMeetingPage> createState() => _VideoMeetingPageState();
}

class _VideoMeetingPageState extends State<VideoMeetingPage> {
  bool micOn = true;
  bool camOn = true;
  String currentCam = "front"; // front/back
  bool meetingEnded = false;

  @override
  void initState() {
    super.initState();
    // Мұнда Firestore арқылы қатысушыларды тексеруге болады
    // Және таймер арқылы 1 сағатқа шектеу орнатуға болады
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('video_meeting'.tr()),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(micOn ? Icons.mic : Icons.mic_off),
            onPressed: () {
              setState(() {
                micOn = !micOn;
              });
            },
          ),
          IconButton(
            icon: Icon(camOn ? Icons.videocam : Icons.videocam_off),
            onPressed: () {
              setState(() {
                camOn = !camOn;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.cameraswitch),
            onPressed: () {
              setState(() {
                currentCam = currentCam == "front" ? "back" : "front";
              });
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.black12,
                child: Center(
                  child: Text('video_stream_here'.tr()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    meetingEnded = true;
                  });
                  Navigator.pop(context); // Video бітсе ChatPage-қа қайту
                },
                child: Text('leave_meeting'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
