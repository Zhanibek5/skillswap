import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final List<String> selectedSkills;
  final String mode;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.selectedSkills,
    required this.mode,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController messageController = TextEditingController();
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  FlutterSoundRecorder recorder = FlutterSoundRecorder();
  FlutterSoundPlayer player = FlutterSoundPlayer();
  ScrollController _scrollController = ScrollController();
  
  bool isRecording = false;
  bool isCancelled = false;
  bool isTyping = false;
  String playingUrl = '';

  StreamSubscription? _recordingSubscription;
  Duration _recordingDuration = Duration.zero;

  StreamSubscription? _playbackSubscription;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  Future<void> playAudio(String url, int durationSecs) async {
    try {
      String prevUrl = playingUrl;
      if (player.isPlaying) {
        await player.stopPlayer();
        _playbackSubscription?.cancel();
        setState(() {
          playingUrl = '';
          _playbackPosition = Duration.zero;
        });
        if (prevUrl == url) return; // Toggle logic
      }
      
      setState(() {
        playingUrl = url;
        _playbackDuration = Duration(seconds: durationSecs);
        _playbackPosition = Duration.zero;
      });

      await player.startPlayer(
        fromURI: url,
        codec: Codec.aacADTS, // Явно указываем кодек для удаленных файлов
        whenFinished: () {
          if (mounted) {
            setState(() {
              playingUrl = '';
              _playbackPosition = Duration.zero;
            });
          }
        },
      );

      player.setSubscriptionDuration(const Duration(milliseconds: 50));
      _playbackSubscription = player.onProgress!.listen((e) {
        if (mounted) {
          setState(() {
            _playbackPosition = e.position;
            if (e.duration.inMilliseconds > 0) {
              _playbackDuration = e.duration;
            }
          });
        }
      });
    } catch (e) {
      print("Play error: $e");
      setState(() {
        playingUrl = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Аудио ойнату мүмкін болмады: $e")),
        );
      }
    }
  }

  Future<void> startRecording() async {
    try {
      final tempDir = Directory.systemTemp;
      String filePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      await recorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
        sampleRate: 48000, // Студийное качество (высшая частота дискретизации)
        bitRate: 192000,   // Высокий битрейт для HD звука
        numChannels: 1,    // Моно звук (для голоса лучше моно, убирает странные эффекты "эха" и медлительности)
      );

      recorder.setSubscriptionDuration(const Duration(milliseconds: 50));
      _recordingSubscription = recorder.onProgress!.listen((e) {
        if (mounted) {
          setState(() {
            _recordingDuration = e.duration;
          });
        }
      });
    } catch (e) {
      print("Recorder error: $e");
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    _recordingSubscription?.cancel();
    _playbackSubscription?.cancel();
    recorder.closeRecorder();
    player.closePlayer();
    super.dispose();
  }

  Future<String?> stopRecording() async {
    try {
      _recordingSubscription?.cancel();
      String? path = await recorder.stopRecorder();
      return path; // Жазылған файл жолы
    } catch (e) {
      print("Stop recorder error: $e");
      return null;
    }
  }

  Future<void> requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  Future<String> uploadAudio(String filePath) async {
    File file = File(filePath);
    if (!file.existsSync()) {
      throw Exception("Аудио файл табылған жоқ");
    }
    Reference ref = FirebaseStorage.instance
        .ref()
        .child("audios/${DateTime.now().millisecondsSinceEpoch}.aac");
    // Указываем content type, чтобы плеер знал как его читать
    await ref.putFile(file, SettableMetadata(contentType: 'audio/aac'));
    String url = await ref.getDownloadURL();
    return url; // Осы URL-ді Firestore-ке жазамыз
  }

  void markMessagesAsRead() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .get();

    for (var doc in snapshot.docs) {
      List readBy = doc['readBy'] ?? [];

      if (!readBy.contains(currentUserId)) {
        await doc.reference.update({
          'readBy': FieldValue.arrayUnion([currentUserId])
        });
      }
    }
  }

  Future<void> _sendMeetingMessage(DateTime meetingTime) async {
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages');

    await chatRef.add({
      'senderId': 'system',
      'type': 'system_meeting_created',
      'meetingTime': Timestamp.fromDate(meetingTime),
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [],
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': '📅 Кездесу жоспарланды',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastType': 'system_meeting_created',
    });

    Duration diff = meetingTime.difference(DateTime.now());

    if (diff.inMinutes > 10) {
      Future.delayed(diff - const Duration(minutes: 10), () async {
        await chatRef.add({
          'senderId': 'system',
          'type': 'system_meeting_10min',
          'meetingTime': Timestamp.fromDate(meetingTime),
          'timestamp': FieldValue.serverTimestamp(),
          'readBy': [],
        });

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'lastMessage': '⏰ 10 минут қалды',
          'lastTimestamp': FieldValue.serverTimestamp(),
          'lastType': 'system_meeting_10min',
        });
      });
    }

    if (diff.inSeconds > 0) {
      Future.delayed(diff, () async {
        final startedSnapshot = await chatRef
            .where('type', isEqualTo: 'system_meeting_started')
            .limit(1)
            .get();

        if (startedSnapshot.docs.isEmpty) {
          await chatRef.add({
            'senderId': 'system',
            'type': 'system_meeting_started',
            'meetingTime': Timestamp.fromDate(meetingTime),
            'timestamp': FieldValue.serverTimestamp(),
            'readBy': [],
          });

          await FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .update({
            'lastMessage': '🔔 Кездесу басталды',
            'lastTimestamp': FieldValue.serverTimestamp(),
            'lastType': 'system_meeting_started',
          });
        }
      });
    }
  }

  void _showConfirmDialog(DateTime meetingTime) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Confirm Meeting"),
          content: Text(
              "Meeting Time:\n${meetingTime.day}.${meetingTime.month}.${meetingTime.year}  ${meetingTime.hour}:${meetingTime.minute.toString().padLeft(2, '0')}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Color(0xFF1E88E5)),
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _sendMeetingMessage(meetingTime);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFF1E88E5),
                side: const BorderSide(
                  color: Color(0xFF1E88E5), // шекара түсі
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
              ),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMeetingScheduler() async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E88E5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) return;

    selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Colors.white,
            ),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E88E5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null) return;

    final meetingDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    _showConfirmDialog(meetingDateTime);
  }

  @override
  void initState() {
    super.initState();
    messageController.addListener(() {
      if (mounted) {
        setState(() {
          isTyping = messageController.text.trim().isNotEmpty;
        });
      }
    });
    player.openPlayer();
    recorder.openRecorder();
    checkAndSendInitialMessage();
    checkMeetingReminder();
    markMessagesAsRead();
  }

  Future<void> checkMeetingReminder() async {
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages');

    // Алдымен кездесуді тексеру
    final meetingSnapshot = await chatRef
        .where('type', isEqualTo: 'system_meeting_created')
        .limit(1)
        .get();

    if (meetingSnapshot.docs.isEmpty) return;

    final meetingTime =
        (meetingSnapshot.docs.first['meetingTime'] as Timestamp).toDate();
    final diff = meetingTime.difference(DateTime.now());

    if (diff.inMinutes <= 10 && diff.inMinutes > 0) {
      final tenMinSnapshot = await chatRef
          .where('type', isEqualTo: 'system_meeting_10min')
          .limit(1)
          .get();

      if (tenMinSnapshot.docs.isEmpty) {
        await chatRef.add({
          'senderId': 'system',
          'type': 'system_meeting_10min',
          'meetingTime': Timestamp.fromDate(meetingTime),
          'timestamp': FieldValue.serverTimestamp(),
          'readBy': [],
        });

        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'lastMessage': '⏰ 10 минут қалды',
          'lastTimestamp': FieldValue.serverTimestamp(),
          'lastType': 'system_meeting_10min',
        });
      }
    }

    // if (diff.inSeconds <= 0) {
    //   final startedSnapshot = await chatRef
    //       .where('type', isEqualTo: 'system_meeting_started')
    //       .limit(1)
    //       .get();

    //   if (startedSnapshot.docs.isEmpty) {
    //     await chatRef.add({
    //       'senderId': 'system',
    //       'type': 'system_meeting_started',
    //       'meetingTime': Timestamp.fromDate(meetingTime),
    //       'timestamp': FieldValue.serverTimestamp(),
    //       'readBy': [],
    //     });

    //     await FirebaseFirestore.instance
    //         .collection('chats')
    //         .doc(widget.chatId)
    //         .update({
    //       'lastMessage': '🔔 Кездесу басталды',
    //       'lastTimestamp': FieldValue.serverTimestamp(),
    //       'lastType': 'system_meeting_started',
    //     });
    //   }
    // }
  }

  Future<void> checkAndSendInitialMessage() async {
    final messages = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .limit(1)
        .get();

    if (messages.docs.isEmpty) {
      final text = widget.mode == 'learn'
          ? 'Сәлеметсіз бе! Мен сізден ${widget.selectedSkills.join(", ")} үйренгім келеді.'
          : 'Сәлеметсіз бе! Мен сізге ${widget.selectedSkills.join(", ")} үйреткім келеді.';

      await sendMessage(text);
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'text': text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [currentUserId],
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastType': 'text',
    });

    messageController.clear();
  }

  Future<void> processAndSendAudio(String filePath, int durationSecs) async {
    // 1. Создаем временный документ (для мгновенного отображения в UI)
    DocumentReference docRef = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'audioUrl': 'uploading', // Флаг загрузки
      'duration': durationSecs,
      'type': 'audio',
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [currentUserId],
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': '🎤 Аудио хабарлама',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastType': 'audio',
    });

    try {
      // 2. Фоново загружаем файл в Storage
      String url = await uploadAudio(filePath);
      // 3. Обновляем документ реальной ссылкой
      await docRef.update({'audioUrl': url});
    } catch (e) {
      print("Upload failed: $e");
      await docRef.delete(); // Удаляем сообщение если загрузка не удалась
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Аудио жүктеу мүмкін болмады: $e")),
        );
      }
    }
  }

  String formatAudioDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String formatRecordingDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final ms = (d.inMilliseconds % 1000) ~/ 100;
    return '${m.toString()}:${s.toString().padLeft(2, '0')},$ms';
  }

  Widget buildWaveform(String url, bool isMe, int durationSecs) {
    bool isPlaying = playingUrl == url;
    double progress = 0;
    if (isPlaying && _playbackDuration.inMilliseconds > 0) {
      progress = _playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds;
    }

    var rg = Random(url.hashCode);
    int barsCount = 30;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(barsCount, (index) {
        double height = rg.nextDouble() * 15 + 5;
        bool isPlayed = (index / barsCount) <= progress;
        
        Color barColor;
        if (isMe) {
           barColor = isPlayed ? Colors.white : Colors.white.withOpacity(0.4);
        } else {
           barColor = isPlayed ? const Color(0xFF1E88E5) : Colors.grey.shade300;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  String formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    final now = DateTime.now();

    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/back.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.otherUserId)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
              final userName = userData['firstName'] ?? 'No Name';
              final photoUrl = userData['photoUrl'] ?? '';

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(
                        top: 50, left: 5, right: 16, bottom: 12),
                    color: Colors.white,
                    child: Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey.shade200,
                          child: ClipOval(
                            child: photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.person, size: 28);
                                    },
                                  )
                                : Icon(Icons.person, size: 33),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                widget.selectedSkills.join(", "),
                                style: const TextStyle(
                                    color: Colors.black38, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_month,
                              color: Colors.black),
                          onPressed: () {
                            _openMeetingScheduler();
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .collection('messages')
                          .orderBy('timestamp')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final messages = snapshot.data!.docs;

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        });

                        if (messages.isNotEmpty) {
                          final lastMsg = messages.last;
                          final lastData =
                              lastMsg.data() as Map<String, dynamic>;
                          List readBy = lastData['readBy'] ?? [];

                          if (lastMsg['senderId'] != currentUserId &&
                              !readBy.contains(currentUserId)) {
                            lastMsg.reference.update({
                              'readBy': FieldValue.arrayUnion([currentUserId])
                            });
                          }
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            final data = msg.data() as Map<String, dynamic>;
                            final type = data['type'] ?? 'text';
                            if (type != null &&
                                type.toString().startsWith('system_')) {
                              DateTime? meetingDt;
                              if (data['meetingTime'] != null) {
                                meetingDt =
                                    (data['meetingTime'] as Timestamp).toDate();
                              }

                              return Center(
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Stack(
                                    children: [
                                      /// MAIN CONTENT
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (type ==
                                              'system_meeting_created') ...[
                                            const Text(
                                              "📅 Кездесу жоспарланды",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            if (meetingDt != null)
                                              Text(
                                                "${meetingDt.day}.${meetingDt.month}.${meetingDt.year}  ${meetingDt.hour}:${meetingDt.minute.toString().padLeft(2, '0')}",
                                              ),
                                          ],
                                          if (type == 'system_meeting_10min')
                                            const Text("⏰ 10 минут қалды"),
                                          if (type ==
                                              'system_meeting_started') ...[
                                            const Text(
                                              "🔔 Кездесу басталды",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            ElevatedButton(
                                              onPressed: () {},
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.blueAccent,
                                                foregroundColor: Colors.white,
                                                shadowColor: Colors.black54,
                                                elevation: 5,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                  vertical: 5,
                                                ),
                                              ),
                                              child: const Text(
                                                "Қосылу",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                          ],
                                          const SizedBox(height: 20),
                                        ],
                                      ),

                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Text(
                                          formatTime(msg['timestamp']),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final isMe = data['senderId'] == currentUserId;
                            List readBy = data['readBy'] ?? [];

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.75),
                                margin: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFF1E88E5)
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 0),
                                    bottomRight: Radius.circular(isMe ? 0 : 16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (type == 'audio' && data['audioUrl'] != null)
                                      Builder(
                                        builder: (context) {
                                          final int audioDuration = data['duration'] ?? 0;
                                          final bool isPlaying = playingUrl == data['audioUrl'];
                                          final bool isUploading = data['audioUrl'] == 'uploading';
                                          
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: isMe ? Colors.white : const Color(0xFF1E88E5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: isUploading
                                                    ? Padding(
                                                        padding: const EdgeInsets.all(12),
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          color: isMe ? const Color(0xFF1E88E5) : Colors.white,
                                                        ),
                                                      )
                                                    : GestureDetector(
                                                        onTap: () => playAudio(data['audioUrl'], audioDuration),
                                                        child: Icon(
                                                          isPlaying ? Icons.pause : Icons.play_arrow,
                                                          color: isMe ? const Color(0xFF1E88E5) : Colors.white,
                                                          size: 28,
                                                        ),
                                                      ),
                                                ),
                                                const SizedBox(width: 10),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    buildWaveform(data['audioUrl'], isMe, audioDuration),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      isPlaying 
                                                        ? formatAudioDuration(_playbackPosition.inSeconds) 
                                                        : formatAudioDuration(audioDuration),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: isMe ? Colors.white.withOpacity(0.8) : Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      )
                                    else
                                      Text(
                                        data['text'] ?? '',
                                        style: TextStyle(
                                          color: isMe ? Colors.white : Colors.black,
                                          fontSize: 15,
                                        ),
                                      ),
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          formatTime(msg['timestamp']),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isMe
                                                ? Colors.white70
                                                : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (isMe)
                                          SizedBox(
                                            width: 20,
                                            height: 16,
                                            child: Stack(
                                              children: [
                                                Positioned(
                                                  left: 0,
                                                  child: Icon(
                                                    Icons.done,
                                                    size: 16,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                                if (readBy.contains(
                                                    widget.otherUserId))
                                                  Positioned(
                                                    left: 5,
                                                    child: Icon(
                                                      Icons.done,
                                                      size: 16,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        // /// Emoji / Attach button
                        // IconButton(
                        //   icon: const Icon(Icons.emoji_emotions_outlined,
                        //       color: Colors.grey),
                        //   onPressed: () {
                        //     // Add emoji picker logic here
                        //   },
                        // ),
                        // IconButton(
                        //   icon: const Icon(Icons.attach_file, color: Colors.grey),
                        //   onPressed: () {
                        //     // Add file picker logic here
                        //   },
                        // ),

                        /// Text input field
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: isRecording
                                ? ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 25,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          formatRecordingDuration(_recordingDuration), 
                                          style: const TextStyle(color: Colors.black, fontSize: 16)
                                        ),
                                        const Spacer(),
                                        const Text("< Влево — отмена", style: TextStyle(color: Colors.grey, fontSize: 14)),
                                      ],
                                    ),
                                  )
                                : ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 120, // max height for multi-line
                                    ),
                                    child: Scrollbar(
                                      child: TextField(
                                        controller: messageController,
                                        maxLines: null,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        decoration: const InputDecoration(
                                          hintText: "Message...",
                                          border: InputBorder.none,
                                          isCollapsed: true, // remove extra padding
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        if (isTyping)
                          Container(
                            width: 45,
                            height: 45,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E88E5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                sendMessage(messageController.text);
                              },
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Аудио жазу үшін басып тұрыңыз"),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            onLongPressStart: (details) async {
                              await requestMicrophonePermission();
                              isCancelled = false;
                              setState(() {
                                _recordingDuration = Duration.zero;
                                isRecording = true;
                              });
                              await startRecording();
                            },
                            onLongPressMoveUpdate: (details) async {
                              if (details.localOffsetFromOrigin.dx < -50) {
                                if (!isCancelled && isRecording) {
                                  isCancelled = true;
                                  await stopRecording();
                                  setState(() {
                                    isRecording = false;
                                  });
                                }
                              }
                            },
                            onLongPressEnd: (details) async {
                              if (!isCancelled && isRecording) {
                                int durSecs = _recordingDuration.inSeconds;
                                String? path = await stopRecording();
                                setState(() {
                                  isRecording = false; // Мгновенно убираем UI записи
                                });
                                if (path != null) {
                                  // Запускаем фоновую загрузку (без await, чтобы UI не зависал)
                                  processAndSendAudio(path, durSecs);
                                }
                              }
                            },
                            onLongPressCancel: () async {
                              if (isRecording) {
                                await stopRecording();
                                setState(() {
                                  isRecording = false;
                                  isCancelled = true;
                                });
                              }
                            },
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E88E5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mic,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                ],
              );
            },
          )
        ],
      ),
    );
  }
}
