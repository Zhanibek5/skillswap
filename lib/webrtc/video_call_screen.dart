import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling.dart';

class VideoCallScreen extends StatefulWidget {
  final String? specificRoomId;
  final bool isCaller;

  const VideoCallScreen({
    Key? key,
    this.specificRoomId,
    this.isCaller = false,
  }) : super(key: key);

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final Signaling signaling = Signaling();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  String? roomId;
  TextEditingController textEditingController = TextEditingController(text: '');
  bool callStarted = false;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();

    signaling.onAddRemoteStream = ((stream) {
      _remoteRenderer.srcObject = stream;
      if (mounted) setState(() {});
    });

    if (widget.specificRoomId != null) {
      textEditingController.text = widget.specificRoomId!;
      _autoStartCall();
    }
  }

  Future<void> _autoStartCall() async {
    // Open media first
    await signaling.openUserMedia(_localRenderer, _remoteRenderer);
    if (mounted) setState(() {});

    if (widget.isCaller) {
      roomId = await signaling.createRoom(_remoteRenderer, specificRoomId: widget.specificRoomId);
      if (mounted) setState(() { callStarted = true; });
    } else {
      // Small delay to let the caller construct the room if we clicked simultaneously
      await Future.delayed(const Duration(seconds: 2));
      await signaling.joinRoom(widget.specificRoomId!, _remoteRenderer);
      if (mounted) setState(() { callStarted = true; });
    }
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Кездесу / Meeting"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // If no specific room ID is provided, show the manual connect buttons
          if (widget.specificRoomId == null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    signaling.openUserMedia(_localRenderer, _remoteRenderer);
                    setState(() {});
                  },
                  child: const Text("Open camera & mic"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    roomId = await signaling.createRoom(_remoteRenderer);
                    textEditingController.text = roomId!;
                    setState(() {});
                  },
                  child: const Text("Create room"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: textEditingController,
                      decoration: const InputDecoration(
                        hintText: "Enter Room ID to join",
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      signaling.joinRoom(
                        textEditingController.text,
                        _remoteRenderer,
                      );
                    },
                    child: const Text("Join room"),
                  ),
                ],
              ),
            ),
          ] else if (!callStarted) ...[
            // Show loading if auto-connecting
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Қосылуда... / Connecting..."),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          // Видео зоны
          if (widget.specificRoomId == null || callStarted) ...[
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text("Me"),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(5.0),
                            decoration: const BoxDecoration(color: Colors.black),
                            child: RTCVideoView(_localRenderer, mirror: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text("Others"),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(5.0),
                            decoration: const BoxDecoration(color: Colors.black),
                            child: RTCVideoView(_remoteRenderer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Панель управления (Откл звук, Камера, Завершить)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mic Button
                  GestureDetector(
                    onTap: () {
                      signaling.toggleMic();
                      setState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: signaling.isMicOn ? Colors.grey.shade300 : Colors.red.withOpacity(0.8),
                        boxShadow: [
                          if (!signaling.isMicOn)
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                        ],
                      ),
                      child: Icon(
                        signaling.isMicOn ? Icons.mic : Icons.mic_off,
                        color: signaling.isMicOn ? Colors.black87 : Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  
                  // Screen Share Button
                  GestureDetector(
                    onTap: () async {
                      await signaling.toggleScreenShare(_localRenderer);
                      setState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: signaling.isScreenSharing ? Colors.blueAccent : Colors.grey.shade300,
                        boxShadow: [
                          if (signaling.isScreenSharing)
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                        ],
                      ),
                      child: Icon(
                        signaling.isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                        color: signaling.isScreenSharing ? Colors.white : Colors.black87,
                        size: 28,
                      ),
                    ),
                  ),

                  // End Call Button
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    elevation: 5,
                    onPressed: () {
                      signaling.hangUp(_localRenderer);
                      Navigator.pop(context, true);
                    },
                    child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                  ),

                  // Camera Button
                  GestureDetector(
                    onTap: () {
                      signaling.toggleCamera();
                      setState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: signaling.isCameraOn ? Colors.grey.shade300 : Colors.red.withOpacity(0.8),
                        boxShadow: [
                          if (!signaling.isCameraOn)
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                        ],
                      ),
                      child: Icon(
                        signaling.isCameraOn ? Icons.videocam : Icons.videocam_off,
                        color: signaling.isCameraOn ? Colors.black87 : Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}
