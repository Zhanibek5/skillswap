import re

with open(r"f:\skillswap\lib\webrtc\video_call_screen.dart", "r", encoding="utf-8") as f:
    text = f.read()

# We need to replace everything from `  @override\n  Widget build(BuildContext context) {` to the end.

new_build_method = """  @override
  Widget build(BuildContext context) {
    bool isVideoActive = widget.specificRoomId == null || callStarted;

    return WillPopScope(
      onWillPop: () async {
        await _leaveCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Background full screen view (remote video)
            if (isVideoActive)
              Positioned.fill(
                child: signaling.isScreenSharing
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.screen_share, color: Colors.white, size: 60),
                            SizedBox(height: 16),
                            Text(
                              "You are sharing\\nyour screen",
                              style: TextStyle(color: Colors.white, fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RTCVideoView(
                        _remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
              )
            else if (!callStarted) ...[
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text("Қосылуда... / Connecting...",
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
            ],

            // 2. PIP Layer (Local Video or remote if screen sharing)
            if (isVideoActive) ...[
              if (!signaling.isScreenSharing)
                Positioned(
                  bottom: 150,
                  right: 16,
                  width: 100,
                  height: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RTCVideoView(
                        _localRenderer,
                        mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),
              if (signaling.isScreenSharing)
                Positioned(
                  bottom: 150,
                  right: 16,
                  width: 100,
                  height: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RTCVideoView(
                        _remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),
            ],

            // 3. User name at top
            if (isVideoActive)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                            onPressed: () => _leaveCall(),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.screen_share, color: Colors.white),
                                onPressed: () async {
                                  try {
                                    await signaling.toggleScreenShare(_localRenderer);
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Could not share screen: ${e.toString().split('\\n').first}")
                                        ),
                                      );
                                    }
                                  }
                                  if (mounted) setState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.people, color: Colors.white),
                                onPressed: () {
                                  _showParticipantsBottomSheet();
                                },
                              ),
                            ]
                          )
                        ]
                      ),
                    ),
                    Text(
                      otherUserName,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                    ),
                  ]
                )
              ),

             // 4. Bottom Controls
            if (isVideoActive)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBottomControl(
                      onTap: () async {
                         if (signaling.localStream != null) {
                           try {
                             final videoTrack = signaling.localStream!.getVideoTracks().firstWhere((track) => track.kind == 'video');
                             await Helper.switchCamera(videoTrack);
                           } catch (e) {
                             print("Error switching camera: $e");
                           }
                         }
                      },
                      icon: Icons.flip_camera_ios,
                      label: "Повернуть",
                      isActive: true,
                    ),
                    _buildBottomControl(
                      onTap: () {
                        signaling.toggleCamera();
                        _updateMyMediaStatus();
                        setState(() {});
                      },
                      icon: signaling.isCameraOn ? Icons.videocam : Icons.videocam_off,
                      label: "Выкл. видео",
                      isActive: signaling.isCameraOn,
                    ),
                    _buildBottomControl(
                      onTap: () {
                        signaling.toggleMic();
                        _updateMyMediaStatus();
                        setState(() {});
                      },
                      icon: signaling.isMicOn ? Icons.mic : Icons.mic_off,
                      label: "Выкл. звук",
                      isActive: signaling.isMicOn,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          backgroundColor: Colors.redAccent,
                          elevation: 0,
                          onPressed: () => _leaveCall(callFinished: true),
                          child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 8),
                        const Text("Завершить", style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

            // Manual forms overlay if needed (fallback)
            if (widget.specificRoomId == null && !callStarted && _renderersReady)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                if (!_renderersReady) return;
                                try {
                                  await [Permission.camera, Permission.microphone].request();
                                  await signaling.openUserMedia(_localRenderer, _remoteRenderer);
                                  if (mounted) setState(() {});
                                } catch (e) {
                                  print(e);
                                }
                              },
                              child: const Text("Open camera & mic"),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                if (!_renderersReady) return;
                                try {
                                  roomId = await signaling.createRoom(_remoteRenderer);
                                  textEditingController.text = roomId!;
                                  if (mounted) setState(() {});
                                } catch (e) {
                                  print(e);
                                }
                              },
                              child: const Text("Create room"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: textEditingController,
                                  decoration: const InputDecoration(
                                    hintText: "Enter Room ID to join",
                                    fillColor: Colors.white,
                                    filled: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  if (!_renderersReady) return;
                                  try {
                                    await signaling.joinRoom(textEditingController.text, _remoteRenderer);
                                  } catch (e) {
                                    print(e);
                                  }
                                },
                                child: const Text("Join room"),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControl({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.grey.shade800 : Colors.white,
            ),
            child: Icon(icon, color: isActive ? Colors.white : Colors.black, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  void _showParticipantsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Участники / Participants",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: myUserAvatar.isNotEmpty ? NetworkImage(myUserAvatar) : null,
                  child: myUserAvatar.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text("$myUserName (Me)", style: const TextStyle(color: Colors.white)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(signaling.isMicOn ? Icons.mic : Icons.mic_off,
                        color: signaling.isMicOn ? Colors.green : Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Icon(signaling.isCameraOn ? Icons.videocam : Icons.videocam_off,
                        color: signaling.isCameraOn ? Colors.green : Colors.redAccent, size: 20),
                  ],
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: otherUserAvatar.isNotEmpty ? NetworkImage(otherUserAvatar) : null,
                  child: otherUserAvatar.isEmpty ? const Icon(Icons.person_outline) : null,
                ),
                title: Text(otherUserName, style: const TextStyle(color: Colors.white)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(otherMicOn ? Icons.mic : Icons.mic_off,
                        color: otherMicOn ? Colors.green : Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Icon(otherCamOn ? Icons.videocam : Icons.videocam_off,
                        color: otherCamOn ? Colors.green : Colors.redAccent, size: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
"""

start_str = "  @override\n  Widget build(BuildContext context) {"
if start_str in text:
    prefix = text.split(start_str)[0]
    final_text = prefix + new_build_method
    with open(r"f:\skillswap\lib\webrtc\video_call_screen.dart", "w", encoding="utf-8") as f:
        f.write(final_text)
    print("Success")
else:
    print("Could not find start_str")
