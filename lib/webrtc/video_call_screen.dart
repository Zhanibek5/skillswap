import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audio_session/audio_session.dart';
import 'signaling.dart';

class VideoCallScreen extends StatefulWidget {
  final String? specificRoomId;
  final bool isCaller;
  final String? otherUserId;
  final int expectedDurationMinutes;
  final String? role;

  const VideoCallScreen({
    super.key,
    this.specificRoomId,
    this.isCaller = false,
    this.otherUserId,
    this.expectedDurationMinutes = 60,
    this.role,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Timer? _callTimer;
  int _secondsRemaining = 0;
  int _secondsSpent = 0;
  bool _callActuallyStarted = false;

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString()}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else {
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
  }

  String? roomId;
  bool callStarted = false;
  bool _isLeaving = false;
  bool _renderersReady = false;
  String _connectionStatus = 'Starting...';

  String otherUserName = "Other Participant";
  String otherUserAvatar = "";
  String myUserName = "Me";
  String myUserAvatar = "";

  bool otherMicOn = true;
  bool otherCamOn = true;

  StreamSubscription? _roomSub;

  @override
  void initState() {
    super.initState();
    _fetchUsersData();
    _listenToRoomStatus();
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
        if (status.contains('IceConnectionStateDisconnected') ||
            status.contains('IceConnectionStateClosed') ||
            status.contains('IceConnectionStateFailed') ||
            status.contains('ConnectionStateDisconnected') ||
            status.contains('ConnectionStateClosed') ||
            status.contains('ConnectionStateFailed')) {
          _leaveCall(callFinished: true);
        } else if (status.contains('IceConnectionStateConnected') ||
            status.contains('ConnectionStateConnected')) {
          if (!_callActuallyStarted) {
            _callActuallyStarted = true;

            final startTime = DateTime.now();
            final expectedSeconds = widget.expectedDurationMinutes * 60;
            bool warned5m = false;
            bool warned1m = false;
            bool warned10s = false;

            _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted) {
                timer.cancel();
                return;
              }

              final now = DateTime.now();
              int elapsedSeconds = now.difference(startTime).inSeconds;
              int remaining = expectedSeconds - elapsedSeconds;

              setState(() {
                _secondsSpent = elapsedSeconds;
                _secondsRemaining = remaining > 0 ? remaining : 0;
              });

              if (_secondsRemaining <= 5 * 60 &&
                  _secondsRemaining > 60 &&
                  !warned5m) {
                warned5m = true;
                _showWarning('5 минут қалды / 5 minutes left');
              } else if (_secondsRemaining <= 60 &&
                  _secondsRemaining > 10 &&
                  !warned1m) {
                warned1m = true;
                _showWarning('1 минут қалды / 1 minute left');
              } else if (_secondsRemaining <= 10 &&
                  _secondsRemaining > 0 &&
                  !warned10s) {
                warned10s = true;
                _showWarning('10 секунд қалды / 10 seconds left');
              } else if (_secondsRemaining <= 0) {
                _leaveCall(callFinished: true);
                timer.cancel();
              }
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Участник қосылды / Participant joined'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
            ),
          );
        }
      }
    };
    signaling.onScreenShareStateChange = () {
      if (mounted) {
        setState(() {});
      }
    };
    _initializeRenderers();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _updateMyMediaStatus();
    });
  }

  Future<void> _fetchUsersData() async {
    final currId = FirebaseAuth.instance.currentUser?.uid;
    if (currId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          myUserName = doc.data()?['name'] ?? "Me";
          myUserAvatar = doc.data()?['profilePic'] ?? "";
        });
      }
    }
    if (widget.otherUserId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          otherUserName = doc.data()?['name'] ?? "Other Participant";
          otherUserAvatar = doc.data()?['profilePic'] ?? "";
        });
      }
    }
  }

  void _listenToRoomStatus() {
    if (widget.specificRoomId != null) {
      _roomSub = FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.specificRoomId)
          .snapshots()
          .listen((snap) {
        if (snap.exists && mounted) {
          final data = snap.data()!;
          String myRole = widget.isCaller ? 'caller' : 'callee';
          String otherRole = widget.isCaller ? 'callee' : 'caller';

          if (data.containsKey('status_$otherRole')) {
            setState(() {
              otherMicOn = data['status_$otherRole']['mic'] ?? true;
              otherCamOn = data['status_$otherRole']['cam'] ?? true;
            });
          }
        }
      });
    }
  }

  void _updateMyMediaStatus() async {
    if (widget.specificRoomId != null) {
      String myRole = widget.isCaller ? 'caller' : 'callee';
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.specificRoomId)
          .set({
        'status_$myRole': {
          'mic': signaling.isMicOn,
          'cam': signaling.isCameraOn,
        }
      }, SetOptions(merge: true));
    }
  }

  Future<void> _initializeRenderers() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.videoChat,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
      await session.setActive(true);
    } catch (e) {
      print("AudioSession configuration error: $e");
    }

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

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _leaveCall({bool callFinished = false}) async {
    if (_isLeaving) return;
    _isLeaving = true;
    _callTimer?.cancel();

    // Balance calculation
    if (_secondsSpent > 0 && widget.role != null) {
      int minutesSpent = (_secondsSpent / 60).ceil();
      if (minutesSpent > widget.expectedDurationMinutes) {
        minutesSpent = widget.expectedDurationMinutes;
      }

      if (minutesSpent > 0) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final userRef =
              FirebaseFirestore.instance.collection('users').doc(uid);
          try {
            await FirebaseFirestore.instance
                .runTransaction((transaction) async {
              final snap = await transaction.get(userRef);
              if (snap.exists) {
                final data = snap.data()!;
                int bal = data['balance'] ?? 120;
                int earn = data['timeEarned'] ?? 0;
                int spent = data['timeSpent'] ?? 0;

                if (widget.role == 'teach') {
                  bal += minutesSpent;
                  earn += minutesSpent;
                } else if (widget.role == 'learn') {
                  bal -= minutesSpent;
                  spent += minutesSpent;
                }
                transaction.update(userRef, {
                  'balance': bal,
                  'timeEarned': earn,
                  'timeSpent': spent,
                });
              }
            });
          } catch (e) {
            print("Error updating balance: $e");
          }
        }
      }
    }

    if (mounted) {
      Navigator.pop(context, callFinished);
    }

    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      print("Error resetting AudioSession: $e");
    }

    unawaited(signaling.hangUp());
  }

  @override
  void dispose() {
    if (!_isLeaving) {
      _isLeaving = true;
      unawaited(signaling.hangUp());
    }

    _roomSub?.cancel();
    textEditingController.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
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
                            Icon(Icons.screen_share,
                                color: Colors.white, size: 60),
                            SizedBox(height: 16),
                            Text(
                              "You are sharing\nyour screen",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : RTCVideoView(
                        _remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatDuration(_secondsRemaining > 0
                                    ? _secondsRemaining
                                    : widget.expectedDurationMinutes * 60),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Row(children: [
                              IconButton(
                                icon: const Icon(Icons.screen_share,
                                    color: Colors.white),
                                onPressed: () async {
                                  try {
                                    await signaling
                                        .toggleScreenShare(_localRenderer);
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Could not share screen: ${e.toString().split('\n').first}")),
                                      );
                                    }
                                  }
                                  if (mounted) setState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.people,
                                    color: Colors.white),
                                onPressed: () {
                                  _showParticipantsBottomSheet();
                                },
                              ),
                            ])
                          ]),
                    ),
                  ])),

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
                            final videoTrack = signaling.localStream!
                                .getVideoTracks()
                                .firstWhere((track) => track.kind == 'video');
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
                      icon: signaling.isCameraOn
                          ? Icons.videocam
                          : Icons.videocam_off,
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
                          child: const Icon(Icons.call_end,
                              color: Colors.white, size: 28),
                        ),
                        SizedBox(height: 8),
                        const Text("Завершить",
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

            // Manual forms overlay if needed (fallback)
            if (widget.specificRoomId == null &&
                !callStarted &&
                _renderersReady)
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
                                  await [
                                    Permission.camera,
                                    Permission.microphone
                                  ].request();
                                  await signaling.openUserMedia(
                                      _localRenderer, _remoteRenderer);
                                  if (mounted) setState(() {});
                                } catch (e) {
                                  print(e);
                                }
                              },
                              child: const Text("Open camera & mic"),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () async {
                                if (!_renderersReady) return;
                                try {
                                  roomId = await signaling
                                      .createRoom(_remoteRenderer);
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
                        SizedBox(height: 16),
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
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  if (!_renderersReady) return;
                                  try {
                                    await signaling.joinRoom(
                                        textEditingController.text,
                                        _remoteRenderer);
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
            child: Icon(icon,
                color: isActive ? Colors.white : Colors.black, size: 28),
          ),
        ),
        SizedBox(height: 8),
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
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: myUserAvatar.isNotEmpty
                      ? NetworkImage(myUserAvatar)
                      : null,
                  child: myUserAvatar.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text("$myUserName (Me)",
                    style: const TextStyle(color: Colors.white)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(signaling.isMicOn ? Icons.mic : Icons.mic_off,
                        color:
                            signaling.isMicOn ? Colors.green : Colors.redAccent,
                        size: 20),
                    SizedBox(width: 8),
                    Icon(
                        signaling.isCameraOn
                            ? Icons.videocam
                            : Icons.videocam_off,
                        color: signaling.isCameraOn
                            ? Colors.green
                            : Colors.redAccent,
                        size: 20),
                  ],
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: otherUserAvatar.isNotEmpty
                      ? NetworkImage(otherUserAvatar)
                      : null,
                  child: otherUserAvatar.isEmpty
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                title: Text(otherUserName,
                    style: const TextStyle(color: Colors.white)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(otherMicOn ? Icons.mic : Icons.mic_off,
                        color: otherMicOn ? Colors.green : Colors.redAccent,
                        size: 20),
                    SizedBox(width: 8),
                    Icon(otherCamOn ? Icons.videocam : Icons.videocam_off,
                        color: otherCamOn ? Colors.green : Colors.redAccent,
                        size: 20),
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
