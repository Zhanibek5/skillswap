import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'signaling.dart';

class VideoCallScreen extends StatefulWidget {
  final String? specificRoomId;
  final bool isCaller;

  const VideoCallScreen({
    super.key,
    this.specificRoomId,
    this.isCaller = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final Signaling signaling = Signaling();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final TextEditingController textEditingController = TextEditingController();

  String? roomId;
  bool callStarted = false;
  bool _isLeaving = false;
  bool _renderersReady = false;
  String _connectionStatus = 'Starting...';

  @override
  void initState() {
    super.initState();
    signaling.onAddRemoteStream = (stream) {
      _remoteRenderer.srcObject = stream;
      if (mounted) {
        setState(() {
          _connectionStatus = 'Remote stream received';
        });
      }
    };
    signaling.onConnectionStatusChange = (status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
        });
      }
    };
    signaling.onScreenShareStateChange = () {
      if (mounted) {
        setState(() {});
      }
    };
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    if (!mounted) return;
    setState(() {
      _renderersReady = true;
    });

    if (widget.specificRoomId != null) {
      textEditingController.text = widget.specificRoomId!;
      await _autoStartCall();
    }
  }

  Future<void> _autoStartCall() async {
    if (!_renderersReady) return;

    try {
      await [Permission.camera, Permission.microphone].request();
      
      await signaling.openUserMedia(_localRenderer, _remoteRenderer);
      if (mounted) {
        setState(() {
          _connectionStatus =
              widget.isCaller ? 'Creating room...' : 'Joining room...';
        });
      }

      if (widget.isCaller) {
        roomId = await signaling.createRoom(
          _remoteRenderer,
          specificRoomId: widget.specificRoomId,
        );
        if (mounted) {
          setState(() {
            callStarted = true;
            _connectionStatus = 'Waiting for other participant...';
          });
        }
        return;
      }

      await Future.delayed(const Duration(seconds: 2));
      await signaling.joinRoom(widget.specificRoomId!, _remoteRenderer);
      if (mounted) {
        setState(() {
          callStarted = true;
          _connectionStatus = 'Connected to room, waiting for media...';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = 'Error: $e';
      });
    }
  }

  Future<void> _leaveCall({bool callFinished = false}) async {
    if (_isLeaving) return;
    _isLeaving = true;

    await signaling.hangUp();

    if (!mounted) return;
    Navigator.pop(context, callFinished);
  }

  @override
  void dispose() {
    if (!_isLeaving) {
      _isLeaving = true;
      unawaited(signaling.hangUp());
    }

    textEditingController.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _leaveCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _leaveCall(),
          ),
          title: const Text("Кездесу / Meeting", style: TextStyle(color: Colors.white, fontSize: 18)),
          centerTitle: true,
          backgroundColor: Colors.grey.shade900,
          elevation: 0,
        ),
        body: Column(
          children: [
            if (widget.specificRoomId == null) ...[
              if (!_renderersReady)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      if (!_renderersReady) return;
                      try {
                        await [Permission.camera, Permission.microphone].request();
                        await signaling.openUserMedia(
                          _localRenderer,
                          _remoteRenderer,
                        );
                        if (mounted) {
                          setState(() {});
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _connectionStatus = 'Error: $e';
                          });
                        }
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
                        if (mounted) {
                          setState(() {});
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _connectionStatus = 'Error: $e';
                          });
                        }
                      }
                    },
                    child: const Text("Create room"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(8),
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
                      onPressed: () async {
                        if (!_renderersReady) return;
                        try {
                          await signaling.joinRoom(
                            textEditingController.text,
                            _remoteRenderer,
                          );
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _connectionStatus = 'Error: $e';
                            });
                          }
                        }
                      },
                      child: const Text("Join room"),
                    ),
                  ],
                ),
              ),
            ] else if (!callStarted) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text("Қосылуда... / Connecting...", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _connectionStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.specificRoomId == null || callStarted) ...[
              Expanded(
                child: signaling.isScreenSharing
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              color: Colors.black,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.screen_share, color: Colors.white, size: 60),
                                    SizedBox(height: 16),
                                    Text(
                                      "You are sharing\nyour screen",
                                      style: TextStyle(color: Colors.white, fontSize: 18),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            width: 120,
                            height: 160,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade800),
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
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              color: Colors.black,
                              child: Stack(
                                children: [
                                  RTCVideoView(
                                    _remoteRenderer,
                                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                  ),
                                  const Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Text(
                                      "Other",
                                      style: TextStyle(color: Colors.white, backgroundColor: Colors.black45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(top: 2),
                              color: Colors.black,
                              child: Stack(
                                children: [
                                  RTCVideoView(
                                    _localRenderer,
                                    mirror: true,
                                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                  ),
                                  const Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Text(
                                      "Me",
                                      style: TextStyle(color: Colors.white, backgroundColor: Colors.black45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                color: Colors.grey.shade900,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
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
                          color: signaling.isMicOn
                              ? Colors.grey.shade800
                              : Colors.redAccent,
                        ),
                        child: Icon(
                          signaling.isMicOn ? Icons.mic : Icons.mic_off,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
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
                          color: signaling.isCameraOn
                              ? Colors.grey.shade800
                              : Colors.redAccent,
                        ),
                        child: Icon(
                          signaling.isCameraOn ? Icons.videocam : Icons.videocam_off,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        try {
                          await signaling.toggleScreenShare(_localRenderer);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Could not share screen: ${e.toString().split('\n').first}")),
                            );
                          }
                        }
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: signaling.isScreenSharing
                              ? Colors.blueAccent
                              : Colors.grey.shade800,
                        ),
                        child: Icon(
                          signaling.isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
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
                                  const Text("Участники / Participants", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 16),
                                  ListTile(
                                    leading: const CircleAvatar(child: Icon(Icons.person)),
                                    title: const Text("Me (Сіз / Вы)", style: TextStyle(color: Colors.white)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(signaling.isMicOn ? Icons.mic : Icons.mic_off, color: signaling.isMicOn ? Colors.green : Colors.redAccent, size: 20),
                                        const SizedBox(width: 8),
                                        Icon(signaling.isCameraOn ? Icons.videocam : Icons.videocam_off, color: signaling.isCameraOn ? Colors.green : Colors.redAccent, size: 20),
                                      ],
                                    ),
                                  ),
                                  const ListTile(
                                    leading: CircleAvatar(child: Icon(Icons.person_outline)),
                                    title: Text("Other Participant", style: TextStyle(color: Colors.white)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.mic, color: Colors.green, size: 20),
                                        SizedBox(width: 8),
                                        Icon(Icons.videocam, color: Colors.green, size: 20),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade800,
                        ),
                        child: const Icon(Icons.people, color: Colors.white, size: 24),
                      ),
                    ),
                    FloatingActionButton(
                      backgroundColor: Colors.redAccent,
                      elevation: 0,
                      onPressed: () => _leaveCall(callFinished: true),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
