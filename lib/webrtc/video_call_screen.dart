import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audio_session/audio_session.dart';
import 'package:easy_localization/easy_localization.dart';
import 'signaling.dart';

class VideoCallScreen extends StatefulWidget {
  final String? specificRoomId;
  final bool isCaller;
  final String? otherUserId;
  final int expectedDurationMinutes;
  final String? role;
  final String? meetingId;
  final DateTime? meetingTime;

  const VideoCallScreen({
    super.key,
    this.specificRoomId,
    this.isCaller = false,
    this.otherUserId,
    this.expectedDurationMinutes = 60,
    this.role,
    this.meetingId,
    this.meetingTime,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Signaling signaling = Signaling();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final TextEditingController textEditingController = TextEditingController();

  Timer? _callTimer;
  int _secondsRemaining = 0;
  int _secondsSpent = 0;
  bool _callActuallyStarted = false;
  int _maxCallDurationMinutes = 60;

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
        final st = status.toLowerCase();
        final isConnectionEvent = st.startsWith('ice connection') || st.startsWith('connection:');
        
        if (st.contains('disconnected') ||
            st.contains('closed') ||
            st.contains('failed')) {
          if (isConnectionEvent) {
            _leaveCall(callFinished: true);
          }
        } else if (st.contains('connected')) {
          if (isConnectionEvent && !_callActuallyStarted) {
            _callActuallyStarted = true;

            final startTime = DateTime.now();
            // 💡 Используем _maxCallDurationMinutes, который мы вычислили ранее!
            final expectedSeconds = _maxCallDurationMinutes * 60;
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
          final roomMeetingId = data['meetingId']?.toString();
          final isSameMeeting = widget.meetingId == null ||
              roomMeetingId == null ||
              roomMeetingId == widget.meetingId;
          final status = data['status']?.toString();

          if (isSameMeeting && (status == 'expired' || status == 'completed')) {
            _showWarning(status == 'expired'
                ? 'meeting_expired'.tr()
                : 'meeting_completed'.tr());
            _leaveCall(callFinished: status == 'completed');
            return;
          }

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

  DateTime? get _joinDeadline =>
      widget.meetingTime?.add(const Duration(minutes: 10));

  Future<void> _markMeetingExpired() async {
    if (widget.specificRoomId == null) return;

    final data = <String, dynamic>{
      'status': 'expired',
      'expiredAt': FieldValue.serverTimestamp(),
      'preserveRoom': true,
    };

    if (widget.meetingId != null) {
      data['meetingId'] = widget.meetingId;
    }
    if (widget.meetingTime != null) {
      data['meetingTime'] = Timestamp.fromDate(widget.meetingTime!);
      data['joinDeadline'] = Timestamp.fromDate(_joinDeadline!);
    }

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.specificRoomId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> _addMeetingStatusMessage({
    required String type,
    required String lastMessage,
    required int durationMinutes,
  }) async {
    if (widget.specificRoomId == null || widget.meetingId == null) return;

    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.specificRoomId);
    final messageRef =
        chatRef.collection('messages').doc('${type}_${widget.meetingId}');

    final messageData = <String, dynamic>{
      'senderId': 'system',
      'type': type,
      'meetingId': widget.meetingId,
      'duration': durationMinutes,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [],
    };

    if (widget.meetingTime != null) {
      messageData['meetingTime'] = Timestamp.fromDate(widget.meetingTime!);
      messageData['joinDeadline'] = Timestamp.fromDate(_joinDeadline!);
    }

    await messageRef.set(messageData, SetOptions(merge: true));
    await chatRef.update({
      'lastMessage': lastMessage,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastType': type,
    });
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

      String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final deadline = _joinDeadline;
      if (deadline != null && DateTime.now().isAfter(deadline)) {
        await _markMeetingExpired();
        await _addMeetingStatusMessage(
          type: 'system_meeting_expired',
          lastMessage: 'meeting_expired',
          durationMinutes: widget.expectedDurationMinutes,
        );
        _showWarning('meeting_expired'.tr());
        if (mounted) Navigator.pop(context);
        return;
      }

      // 💡 Проверяем баланс Learner'а
      String learnerId =
          widget.role == 'learn' ? currentUserId : (widget.otherUserId ?? '');
      int learnerBalance = 0;

      if (learnerId.isNotEmpty) {
        DocumentSnapshot learnerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(learnerId)
            .get();
        if (learnerDoc.exists) {
          var lData = learnerDoc.data() as Map<String, dynamic>;
          learnerBalance = lData['timeBalance'] ?? lData['balance'] ?? 0;
        }
      }

      if (learnerBalance <= 0) {
        _showWarning("Недостаточно времени. Баланс минут: 0.");
        Navigator.pop(context);
        return;
      }

      // Лимит звонка не может превышать ни ожидаемое время, ни текущий баланс
      setState(() {
        _maxCallDurationMinutes =
            widget.expectedDurationMinutes < learnerBalance
                ? widget.expectedDurationMinutes
                : learnerBalance;
      });

      // Проверим срок комнаты ДО попытки подключить камеру (для caller тоже чтобы не открывать если всё пропало)
      if (widget.specificRoomId != null) {
        DocumentSnapshot checkSn = await FirebaseFirestore.instance
            .collection('rooms')
            .doc(widget.specificRoomId)
            .get();

        if (checkSn.exists) {
          var checkData = checkSn.data() as Map<String, dynamic>;
          String s = checkData['status'] ?? '';
          final roomMeetingId = checkData['meetingId']?.toString();
          final sameMeeting =
              widget.meetingId == null || roomMeetingId == widget.meetingId;
          Timestamp? cTime = checkData['createdAt'];

          if (sameMeeting && (s == 'expired' || s == 'completed')) {
            _showWarning("Конференция уже закрыта или была отменена.");
            Navigator.pop(context);
            return;
          }

          if (sameMeeting && cTime != null && s == 'waiting') {
            if (DateTime.now().difference(cTime.toDate()).inMinutes >= 10) {
              await FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(widget.specificRoomId)
                  .set({
                'status': 'expired',
                'expiredAt': FieldValue.serverTimestamp(),
                'meetingId': widget.meetingId,
                if (widget.meetingTime != null)
                  'meetingTime': Timestamp.fromDate(widget.meetingTime!),
                if (_joinDeadline != null)
                  'joinDeadline': Timestamp.fromDate(_joinDeadline!),
                'preserveRoom': true,
              }, SetOptions(merge: true));
              await _addMeetingStatusMessage(
                type: 'system_meeting_expired',
                lastMessage: 'meeting_expired',
                durationMinutes: widget.expectedDurationMinutes,
              );

              _showWarning(
                  "Время ожидания вышло. Конференция закрыта(10 мин).");
              Navigator.pop(context);
              return;
            }
          }
        }
      }

      await signaling.openUserMedia(_localRenderer, _remoteRenderer);
      if (mounted) {
        setState(() {
          _connectionStatus =
              widget.isCaller ? 'Creating room...' : 'Joining room...';
        });
      }

      if (widget.isCaller) {
        String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
        roomId = await signaling.createRoom(
          _remoteRenderer,
          specificRoomId: widget.specificRoomId,
          callerId: currentUserId,
          receiverId: widget.otherUserId,
          role: widget.role,
          meetingId: widget.meetingId,
          meetingTime: widget.meetingTime,
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

      await signaling.joinRoom(
        widget.specificRoomId!,
        _remoteRenderer,
        role: widget.role,
        userId: currentUserId,
      );
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

    // 💡 Этап 4: Атомарная транзакция для безопасного списания баланса
    if (widget.specificRoomId != null && widget.role != null) {
      int minutesSpent = (_secondsSpent / 60).ceil();
      if (minutesSpent > _maxCallDurationMinutes) {
        minutesSpent = _maxCallDurationMinutes;
      }

      bool completedWritten = false;

      if (minutesSpent > 0 || _callActuallyStarted) {
        try {
          final roomRef = FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.specificRoomId);

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final roomSnap = await transaction.get(roomRef);
            if (!roomSnap.exists) return;

            final roomData = roomSnap.data() as Map<String, dynamic>;
            String status = roomData['status'] ?? '';

            // Если кто-то уже закрыл звонок и списал баланс — выходим
            if (status == 'completed' || status == 'expired') return;
            if (status != 'active' && !_callActuallyStarted) return;

            String teacherId = roomData['teacherId'] ?? '';
            String learnerId = roomData['learnerId'] ?? '';

            if (minutesSpent > 0 && teacherId.isNotEmpty) {
              final teacherRef =
                  FirebaseFirestore.instance.collection('users').doc(teacherId);
              final tSnap = await transaction.get(teacherRef);
              if (tSnap.exists) {
                var tData = tSnap.data() as Map<String, dynamic>;
                int tBal = tData['timeBalance'] ?? tData['balance'] ?? 0;
                int tEarn = tData['timeEarned'] ?? 0;

                transaction.update(teacherRef, {
                  'timeBalance': tBal + minutesSpent,
                  'balance': tBal +
                      minutesSpent, // Обновляем оба поля для обратной совместимости
                  'timeEarned': tEarn + minutesSpent,
                });
              }
            }

            if (minutesSpent > 0 && learnerId.isNotEmpty) {
              final learnerRef =
                  FirebaseFirestore.instance.collection('users').doc(learnerId);
              final lSnap = await transaction.get(learnerRef);
              if (lSnap.exists) {
                var lData = lSnap.data() as Map<String, dynamic>;
                int lBal = lData['timeBalance'] ?? lData['balance'] ?? 0;
                int lSpent = lData['timeSpent'] ?? 0;

                transaction.update(learnerRef, {
                  'timeBalance': lBal - minutesSpent,
                  'balance': lBal - minutesSpent,
                  'timeSpent': lSpent + minutesSpent,
                });
              }
            }

            // Помечаем комнату как завершенную
            transaction.update(roomRef, {
              'status': 'completed',
              'endedAt': FieldValue.serverTimestamp(),
              'durationMinutes': minutesSpent,
              'preserveRoom': true,
              if (widget.meetingId != null) 'meetingId': widget.meetingId,
              if (widget.meetingTime != null)
                'meetingTime': Timestamp.fromDate(widget.meetingTime!),
              if (_joinDeadline != null)
                'joinDeadline': Timestamp.fromDate(_joinDeadline!),
            });
            completedWritten = true;
          });
          if (completedWritten) {
            await _addMeetingStatusMessage(
              type: 'system_meeting_completed',
              lastMessage: 'meeting_completed',
              durationMinutes: minutesSpent,
            );
            callFinished = true;
          }
        } catch (e) {
          print("Error executing safe balance transaction: $e");
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
