import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:audio_session/audio_session.dart';
import 'package:skillswap/MainPage/admin/report_dialog.dart';
import 'package:skillswap/webrtc/video_call_screen.dart' as importWebrtc;
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:skillswap/MainPage/reviews/review_dialog.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' as foundation;

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

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final TextEditingController messageController = TextEditingController();
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  FlutterSoundRecorder recorder = FlutterSoundRecorder();
  FlutterSoundPlayer player = FlutterSoundPlayer();
  final ScrollController _scrollController = ScrollController();

  bool isRecording = false;
  bool isCancelled = false;
  bool isTyping = false;
  String playingUrl = '';
  late String otherUserId = widget.otherUserId;
  bool isLoading = true;

  StreamSubscription? _recordingSubscription;
  Duration _recordingDuration = Duration.zero;

  StreamSubscription? _playbackSubscription;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  bool amILearner = false;
  bool amITeacher = false;
  bool chatLoaded = false;
  bool isEmojiVisible = false;
  Map<String, dynamic>? replyToMessage;
  String? editMessageId;
  final FocusNode focusNode = FocusNode();

  bool get shouldInitiateVideoCall {
    // Ұялы телефондар арасында қателік кетпеуі үшін (біреуі Caller, екіншісі Callee болуы шарт),
    // ID-лерді салыстырып, әрқашан біреуі ғана Caller болатындай етіп жасаймыз:
    return currentUserId.compareTo(otherUserId) < 0;
  }

  Future<void> loadChatInfo() async {
    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();

    final data = chatDoc.data()!;

    if (!mounted) return;

    setState(() {
      amILearner = data['learnerId'] == currentUserId;
      amITeacher = data['teacherId'] == currentUserId;
      chatLoaded = true;
    });
  }

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
        codec: Codec.aacMP4, // Ең тұрақты кодек
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
      String filePath =
          '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await recorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacMP4,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
        audioSource: AudioSource
            .microphone, // Изменение микрофона на стандартный (без фильтров "рации")
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

  Future<void> _setActive(bool isActive) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .set({
      'activeUsers': {uid: isActive},
      'lastActiveTime.$uid': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    _setActive(isActive);
  }

  @override
  void dispose() {
    messageController.dispose();
    _recordingSubscription?.cancel();
    _playbackSubscription?.cancel();
    recorder.closeRecorder();
    player.closePlayer();
    _setActive(false);
    WidgetsBinding.instance.removeObserver(this); // 🔥 IMPORTANT

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
        .child("audios/${DateTime.now().millisecondsSinceEpoch}.m4a");
    // Указываем content type, чтобы плеер знал как его читать
    await ref.putFile(file, SettableMetadata(contentType: 'audio/mp4'));
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

  Future<void> _sendMeetingMessage(DateTime meetingTime, int duration) async {
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages');

    await chatRef.add({
      'senderId': currentUserId,
      'type': 'system_meeting_created',
      'meetingTime': Timestamp.fromDate(meetingTime),
      'duration': duration,
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
  }

  void _showConfirmDialog(DateTime meetingTime) {
    int selectedDuration = 60; // Default 1 hour
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            title: const Text("Confirm Meeting"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    "Meeting Time:\n${meetingTime.day}.${meetingTime.month}.${meetingTime.year}  ${meetingTime.hour}:${meetingTime.minute.toString().padLeft(2, '0')}"),
                const SizedBox(height: 20),
                const Text("Duration (minutes):"),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: selectedDuration > 5
                          ? () {
                              setState(() {
                                selectedDuration -= 5;
                              });
                            }
                          : null,
                    ),
                    Text(
                      "$selectedDuration min",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: selectedDuration < 180
                          ? () {
                              setState(() {
                                selectedDuration += 5;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
                Slider(
                  value: selectedDuration.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  activeColor: const Color(0xFF1E88E5),
                  onChanged: (double value) {
                    setState(() {
                      selectedDuration = value.toInt();
                    });
                  },
                )
              ],
            ),
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
                  await _sendMeetingMessage(meetingTime, selectedDuration);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E88E5),
                  side: const BorderSide(
                    color: Color(0xFF1E88E5),
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
        });
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E88E5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            dialogTheme: DialogThemeData(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white),
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
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Color(0xFF1E1E1E)
                  : Colors.white,
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
    _markAsRead();
    _setActive(true);
    WidgetsBinding.instance.addObserver(this); // 🔥 ADD THIS
    loadChatData();
    loadChatInfo();
    messageController.addListener(() {
      if (mounted) {
        setState(() {
          isTyping = messageController.text.trim().isNotEmpty;
        });
      }
    });

    _initAudio();
    checkAndSendInitialMessage();
    markMessagesAsRead();
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'unreadCount.$currentUserId': 0,
    });
  }

  Future<void> _markAsRead() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'unreadCount.$currentUserId': 0,
    });
  }

  Future<void> _initAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
                AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage
              .media, // media вместо voiceCommunication предотвращает эхоподавление и рацию
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
        androidWillPauseWhenDucked: true,
      ));
    } catch (e) {
      print('Audio session config error: $e');
    }

    await player.openPlayer();
    await recorder.openRecorder();
  }

  Future<void> checkAndSendInitialMessage() async {
    if (widget.mode == 'support' ||
        widget.mode == 'admin_view' ||
        widget.mode == 'support_admin') {
      return;
    }

    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();

    final chatData = chatDoc.data();
    if (chatData != null && chatData['initialMessageSent'] == true) {
      return;
    }

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

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({'initialMessageSent': true});
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    if (editMessageId != null) {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(editMessageId)
          .update({
        'text': text,
        'isEdited': true,
      });
      setState(() {
        editMessageId = null;
        replyToMessage = null;
      });
      messageController.clear();
      return;
    }

    final messageData = {
      'senderId': currentUserId,
      'text': text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [currentUserId],
    };

    if (replyToMessage != null) {
      messageData['replyTo'] = {
        'text': replyToMessage!['text'] ?? 'Attachment',
        'senderId': replyToMessage!['senderId'],
      };
    }

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add(messageData);

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastType': 'text',
    });

    setState(() {
      replyToMessage = null;
    });
    messageController.clear();
  }

  Future<void> clearChat(bool forEveryone) async {
    final messages = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .get();

    for (var doc in messages.docs) {
      if (forEveryone) {
        await doc.reference.delete();
      } else {
        await doc.reference.update({
          'deletedFor': FieldValue.arrayUnion([currentUserId])
        });
      }
    }

    // Update the last message text in the chat root document
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': '',
      'lastType': 'text',
    });
  }

  Future<void> sendAttachment(String fileType, File file, String caption,
      {String? originalFileName, int? fileSize}) async {
    originalFileName ??= file.path.split('/').last;
    fileSize ??= file.lengthSync();

    final docRef = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': currentUserId,
      'text': 'uploading',
      'localPath': file.path,
      'type': fileType,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [currentUserId],
      'isUploading': true,
      'caption': caption,
      'fileName': originalFileName,
      'fileSize': fileSize,
    });

    String fileNameStr =
        "${DateTime.now().millisecondsSinceEpoch}_$originalFileName";
    Reference ref = FirebaseStorage.instance
        .ref()
        .child("chats/${widget.chatId}/$fileNameStr");
    await ref.putFile(file);
    String url = await ref.getDownloadURL();

    await docRef.update({
      'text': url,
      'isUploading': false,
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': caption.isNotEmpty
          ? caption
          : (fileType == 'image' ? '📷 Изображение' : '📁 Файл'),
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastType': fileType,
    });
  }

  Future<void> _showMultiMediaPreview(List<File> files, String fileType) async {
    if (files.isEmpty) return;
    final TextEditingController captionController = TextEditingController();
    bool sent = false;

    await showDialog(
        context: context,
        useSafeArea: false,
        barrierColor: Colors.black,
        builder: (context) {
          return Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                  child: Column(children: [
                Row(children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context)),
                  Text(
                      fileType == 'image'
                          ? 'Выбрано: ${files.length}'
                          : 'Выбран 1 файл',
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          fontSize: 18)),
                ]),
                Expanded(
                  child: Center(
                    child: fileType == 'image'
                        ? (files.length == 1
                            ? Image.file(files.first)
                            : GridView.builder(
                                padding: const EdgeInsets.all(8),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8),
                                itemCount: files.length,
                                itemBuilder: (_, i) =>
                                    Image.file(files[i], fit: BoxFit.cover),
                              ))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.insert_drive_file,
                                  color: Colors.blueAccent, size: 80),
                              const SizedBox(height: 20),
                              Text(files.first.path.split('/').last,
                                  style: TextStyle(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Color(0xFF1E1E1E)
                                          : Colors.white,
                                      fontSize: 18),
                                  textAlign: TextAlign.center),
                              Text(
                                  "${(files.first.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB",
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 14)),
                            ],
                          ),
                  ),
                ),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    child: Row(children: [
                      Expanded(
                          child: TextField(
                        controller: captionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Добавить подпись...",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      )),
                      IconButton(
                          icon: CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.send,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Color(0xFF1E1E1E)
                                    : Colors.white,
                                size: 20),
                          ),
                          onPressed: () {
                            sent = true;
                            Navigator.pop(context);
                          })
                    ]))
              ])));
        });

    if (sent) {
      if (files.length == 1) {
        sendAttachment(fileType, files.first, captionController.text);
      } else {
        for (int i = 0; i < files.length; i++) {
          final isLast = i == files.length - 1;
          sendAttachment(
              fileType, files[i], isLast ? captionController.text : '');
        }
      }
    }
  }

  void _showContextMenuForAlbum(
      List<DocumentSnapshot> aDocs, Map<String, dynamic> data, bool isMe) {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Ответить'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      replyToMessage = {
                        'text': '📷 Альбом',
                        'senderId': data['senderId'],
                      };
                    });
                    focusNode.requestFocus();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Удалить',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    for (var doc in aDocs) {
                      await doc.reference.delete();
                    }

                    // Fetch the latest message remaining to update the chat room's lastMessage
                    final lastMessageQuery = await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .limit(1)
                        .get();

                    String newLastMessage = '';
                    String newLastType = 'text';

                    if (lastMessageQuery.docs.isNotEmpty) {
                      final data = lastMessageQuery.docs.first.data();
                      newLastMessage =
                          data.containsKey('text') ? data['text'] : '';
                      newLastType =
                          data.containsKey('type') ? data['type'] : 'text';

                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .update({
                        'lastMessage': newLastMessage,
                        'lastType': newLastType,
                        if (data['timestamp'] != null)
                          'lastTimestamp': data['timestamp'],
                      });
                    } else {
                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .update({
                        'lastMessage': '',
                        'lastType': 'text',
                      });
                    }
                  },
                ),
              ],
            ),
          );
        });
  }

  void _showContextMenu(
      String messageId, Map<String, dynamic> data, bool isMe) {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Ответить'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      replyToMessage = {
                        'text': data['text'],
                        'senderId': data['senderId'],
                      };
                    });
                    focusNode.requestFocus();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Копировать'),
                  onTap: () {
                    Navigator.pop(context);
                    foundation.defaultTargetPlatform ==
                                foundation.TargetPlatform.iOS ||
                            foundation.defaultTargetPlatform ==
                                foundation.TargetPlatform.android
                        ? Clipboard.setData(
                            ClipboardData(text: data['text'] ?? ''))
                        : null;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Скопировано')));
                  },
                ),
                if (isMe && data['type'] == 'text')
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Изменить'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        editMessageId = messageId;
                        messageController.text = data['text'];
                      });
                      focusNode.requestFocus();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Удалить',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    // 1. Delete the message
                    await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.chatId)
                        .collection('messages')
                        .doc(messageId)
                        .delete();

                    // 2. Fetch the latest message remaining to update the chat room's lastMessage
                    final lastMessageQuery = await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.chatId)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .limit(1)
                        .get();

                    String newLastMessage = '';
                    String newLastType = 'text';

                    if (lastMessageQuery.docs.isNotEmpty) {
                      final data = lastMessageQuery.docs.first.data();
                      newLastMessage =
                          data.containsKey('text') ? data['text'] : '';
                      newLastType =
                          data.containsKey('type') ? data['type'] : 'text';

                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .update({
                        'lastMessage': newLastMessage,
                        'lastType': newLastType,
                        if (data['timestamp'] != null)
                          'lastTimestamp': data['timestamp'],
                      });
                    } else {
                      // Chat is empty now
                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .update({
                        'lastMessage': '',
                        'lastType': 'text',
                      });
                    }
                  },
                ),
              ],
            ),
          );
        });
  }

  void _showAttachmentsMenu() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachOption(Icons.image, Colors.purple, "Gallery",
                    () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickMultiImage();
                  if (picked.isNotEmpty) {
                    _showMultiMediaPreview(
                        picked.map((e) => File(e.path)).toList(), 'image');
                  }
                }),
                _buildAttachOption(Icons.camera_alt, Colors.pink, "Camera",
                    () async {
                  Navigator.pop(context);
                  final picked =
                      await ImagePicker().pickImage(source: ImageSource.camera);
                  if (picked != null) {
                    _showMultiMediaPreview([File(picked.path)], 'image');
                  }
                }),
                _buildAttachOption(
                    Icons.insert_drive_file, Colors.orange, "File", () async {
                  Navigator.pop(context);
                  final picked = await FilePicker.platform.pickFiles();
                  if (picked != null && picked.files.single.path != null) {
                    _showMultiMediaPreview(
                        [File(picked.files.single.path!)], 'file');
                  }
                }),
              ],
            ),
          );
        });
  }

  Widget _buildAttachOption(
      IconData icon, Color color, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildImageItem(Map<String, dynamic> data) {
    final isUploading = data['isUploading'] == true;
    final fileExists =
        data['localPath'] != null && File(data['localPath']).existsSync();

    Widget imageWidget;
    if (isUploading) {
      imageWidget = Stack(
        fit: StackFit.expand,
        children: [
          if (fileExists)
            Image.file(File(data['localPath']), fit: BoxFit.cover)
          else
            Container(color: Colors.grey[300]),
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    } else {
      imageWidget = Image.network(data['text'],
          fit: BoxFit.cover,
          errorBuilder: (context, err, stack) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Stack(fit: StackFit.expand, children: [
              Container(color: Colors.grey[300]),
              const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent)),
            ]);
          });
    }

    return GestureDetector(
      onTap: () {
        if (!isUploading) launchUrl(Uri.parse(data['text']));
      },
      child: imageWidget,
    );
  }

  Future<void> processAndSendAudio(String filePath, int durationSecs) async {
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
      progress =
          _playbackPosition.inMilliseconds / _playbackDuration.inMilliseconds;
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

  Future<void> loadChatData() async {
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();

    final data = doc.data();

    if (data != null && data['participants'] != null) {
      List participants = data['participants'];

      final currentUser = FirebaseAuth.instance.currentUser?.uid ?? '';

      final newOtherUserId = participants.firstWhere(
        (id) => id != currentUser,
        orElse: () => '',
      );
      if (newOtherUserId.isNotEmpty && newOtherUserId != otherUserId) {
        if (mounted) {
          setState(() {
            if (newOtherUserId.isNotEmpty) {
              setState(() {
                otherUserId = newOtherUserId;
              });
            }
          });
        }
      }
    }

    // setState(() {
    //   isLoading = false;
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black
                : null,
            child: Opacity(
              opacity:
                  Theme.of(context).brightness == Brightness.dark ? 0.5 : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      Theme.of(context).brightness == Brightness.dark
                          ? "assets/backgr black tg.jpg"
                          : "assets/back.png",
                    ),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    // Убрали затемнение, чтобы картинка была видна полностью
                    colorFilter: null,
                  ),
                ),
              ),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(otherUserId)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

              bool isSupportAgent =
                  widget.mode == 'support' && userData['role'] == 'admin';
              final userName = isSupportAgent
                  ? 'Support'
                  : (userData['firstName'] ?? 'No Name');
              final photoUrl = isSupportAgent
                  ? 'https://cdn-icons-png.flaticon.com/512/3249/3249962.png'
                  : (userData['photoUrl'] ?? '');

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(
                        top: 50, left: 5, right: 16, bottom: 12),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF161616)
                        : Colors.white,
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black),
                          onPressed: () {
                            Navigator.pop(context); // ChatsListPage сақталады
                          },
                        ),
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF2A2E35)
                                  : Colors.grey.shade200,
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
                                style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                overflow: TextOverflow.ellipsis,
                                !chatLoaded
                                    ? ""
                                    : amILearner
                                        ? "Teacher: ${widget.selectedSkills.join(", ")}"
                                        : "Learner: ${widget.selectedSkills.join(", ")}",
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white54
                                      : Colors.black38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.mode != 'support' &&
                            widget.mode != 'support_admin' &&
                            widget.mode != 'admin_view') ...[
                          IconButton(
                            icon: const Icon(Icons.warning_amber_rounded,
                                color: Colors.red),
                            onPressed: () {
                              ReportDialog.show(context, otherUserId, 'chat',
                                  targetId: widget.chatId);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.calendar_month,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black),
                            onPressed: () {
                              _openMeetingScheduler();
                            },
                          ),
                          // PopupMenuButton<String>(
                          //   icon: Icon(Icons.more_vert,
                          //       color: Theme.of(context).brightness ==
                          //               Brightness.dark
                          //           ? Colors.white
                          //           : Colors.black),
                          //   onSelected: (value) {
                          //     if (value == 'clear_me') clearChat(false);
                          //     if (value == 'clear_all') clearChat(true);
                          //   },
                          //   itemBuilder: (context) => [
                          //     const PopupMenuItem(
                          //       value: 'clear_me',
                          //       child: Text('Очистить для меня'),
                          //     ),
                          //     const PopupMenuItem(
                          //       value: 'clear_all',
                          //       child: Text('Очистить для всех'),
                          //     ),
                          //   ],
                          // ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final rawDocs = snapshot.data!.docs;

                        if (rawDocs.isNotEmpty) {
                          final lastMsg = rawDocs.first;
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

                        List<dynamic> uiItems = [];
                        int i = 0;
                        while (i < rawDocs.length) {
                          final doc = rawDocs[i];
                          final data = doc.data() as Map<String, dynamic>;
                          final type = data['type'];

                          if (type == 'image') {
                            List<DocumentSnapshot> albumDocs = [doc];
                            int j = i + 1;
                            while (j < rawDocs.length) {
                              final nextDoc = rawDocs[j];
                              final nextData =
                                  nextDoc.data() as Map<String, dynamic>;
                              if (nextData['type'] == 'image' &&
                                  nextData['senderId'] == data['senderId']) {
                                final t1 = (doc['timestamp'] as Timestamp?)
                                        ?.toDate() ??
                                    DateTime.now();
                                final t2 = (nextDoc['timestamp'] as Timestamp?)
                                        ?.toDate() ??
                                    t1;
                                if (t1.difference(t2).inMinutes.abs() <= 15) {
                                  albumDocs.add(nextDoc);
                                  j++;
                                  if (albumDocs.length == 10) break;
                                } else {
                                  break;
                                }
                              } else {
                                break;
                              }
                            }
                            if (albumDocs.length > 1) {
                              uiItems.add({
                                'isAlbum': true,
                                'docs': albumDocs,
                                'senderId': data['senderId']
                              });
                              i = j;
                              continue;
                            }
                          }

                          uiItems.add(doc);
                          i++;
                        }

                        if (uiItems.isEmpty) {
                          return Center(
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF2C2538).withOpacity(
                                        0.85) // Telegram like purplish dark grey
                                    : Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Здесь пока ничего нет...",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Отправьте сообщение или нажмите на приветствие ниже.",
                                    style: TextStyle(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  const Text("👋",
                                      style: TextStyle(fontSize: 48)),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          reverse: true,
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          itemCount: uiItems.length,
                          itemBuilder: (context, index) {
                            final item = uiItems[index];
                            final bool isAlbum =
                                item is Map && item['isAlbum'] == true;

                            if (isAlbum) {
                              final List<DocumentSnapshot> aDocs = item['docs'];
                              final isMe = item['senderId'] == currentUserId;
                              final newestData =
                                  aDocs.first.data() as Map<String, dynamic>;
                              String? albumCaption = newestData['caption'];

                              return SwipeTo(
                                onRightSwipe: (details) {
                                  setState(() {
                                    replyToMessage = {
                                      'text': '📷 Альбом',
                                      'senderId': newestData['senderId'],
                                    };
                                  });
                                  focusNode.requestFocus();
                                },
                                child: GestureDetector(
                                  onLongPress: () {
                                    _showContextMenuForAlbum(
                                        aDocs, newestData, isMe);
                                  },
                                  child: Align(
                                    alignment: isMe
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.75),
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 8),
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? const Color(0xFF1E88E5)
                                            : (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? const Color(0xFF232530)
                                                : Colors.white),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft:
                                              Radius.circular(isMe ? 16 : 0),
                                          bottomRight:
                                              Radius.circular(isMe ? 0 : 16),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          GridView.builder(
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              shrinkWrap: true,
                                              gridDelegate:
                                                  SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount:
                                                    aDocs.length == 2 ||
                                                            aDocs.length == 4
                                                        ? 2
                                                        : 3,
                                                crossAxisSpacing: 2,
                                                mainAxisSpacing: 2,
                                              ),
                                              itemCount: aDocs.length,
                                              itemBuilder: (context, idx) {
                                                final doc = aDocs.reversed
                                                    .toList()[idx];
                                                final data = doc.data()
                                                    as Map<String, dynamic>;
                                                return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: _buildImageItem(data),
                                                );
                                              }),
                                          if (albumCaption != null &&
                                              albumCaption.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(6.0),
                                              child: Text(
                                                albumCaption,
                                                style: TextStyle(
                                                  color: isMe
                                                      ? Colors.white
                                                      : (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black),
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                right: 6, bottom: 2),
                                            child: Text(
                                              formatTime(
                                                  newestData['timestamp']),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: isMe
                                                      ? Colors.white70
                                                      : Colors.grey),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final msg = item as DocumentSnapshot;
                            final data = msg.data() as Map<String, dynamic>;
                            final List deletedFor = data['deletedFor'] ?? [];
                            if (deletedFor.contains(currentUserId)) {
                              return const SizedBox();
                            }

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
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF232530)
                                            .withOpacity(0.9)
                                        : Colors.grey.shade200,
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
                                              onPressed: () async {
                                                // 1. Join Video Call
                                                int duration =
                                                    data['duration'] ?? 60;
                                                final callDone =
                                                    await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => importWebrtc
                                                        .VideoCallScreen(
                                                      specificRoomId:
                                                          widget.chatId,
                                                      isCaller:
                                                          shouldInitiateVideoCall,
                                                      otherUserId: otherUserId,
                                                      expectedDurationMinutes:
                                                          duration,
                                                      role: widget.mode,
                                                    ),
                                                  ),
                                                );

                                                // 2. Show Review if call finished
                                                if (callDone == true) {
                                                  await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ReviewDialog(
                                                        userName: userName,
                                                        chatId: widget.chatId,
                                                        otherUserId:
                                                            otherUserId,
                                                        selectedSkills: [
                                                          widget.selectedSkills
                                                              .join(", ")
                                                        ],
                                                      ),
                                                    ),
                                                  );

                                                  // Ask to save video history
                                                  bool? saveVideo =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Save Video in History?'),
                                                      content: const Text(
                                                          'Do you want to save this video conference recording?'),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx, false),
                                                          child:
                                                              const Text('No'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx, true),
                                                          child:
                                                              const Text('Yes'),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  if (saveVideo == true) {
                                                    final user = FirebaseAuth
                                                        .instance.currentUser;
                                                    if (user != null) {
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('users')
                                                          .doc(user.uid)
                                                          .collection(
                                                              'video_history')
                                                          .add({
                                                        'chatId': widget.chatId,
                                                        'teacherName': userName,
                                                        'createdAt': FieldValue
                                                            .serverTimestamp(),
                                                      });
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                            content: Text(
                                                                'Video saved in history!')),
                                                      );
                                                    }
                                                  }
                                                }
                                              },
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

                            return SwipeTo(
                              onRightSwipe: (details) {
                                setState(() {
                                  replyToMessage = {
                                    'text': data['text'],
                                    'senderId': data['senderId'],
                                  };
                                });
                                focusNode.requestFocus();
                              },
                              child: GestureDetector(
                                onLongPress: () {
                                  _showContextMenu(msg.id, data, isMe);
                                },
                                child: Align(
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
                                    padding: type == 'image'
                                        ? const EdgeInsets.all(3)
                                        : const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? const Color(0xFF1E88E5)
                                          : (Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF232530)
                                              : Colors.white),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft:
                                            Radius.circular(isMe ? 16 : 0),
                                        bottomRight:
                                            Radius.circular(isMe ? 0 : 16),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (data.containsKey('replyTo'))
                                          Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 5),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              border: Border(
                                                  left: BorderSide(
                                                      color: Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Color(0xFF1E1E1E)
                                                          : Colors.white,
                                                      width: 3)),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              data['replyTo']['text'] ?? '',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: isMe
                                                      ? Colors.white
                                                      : (Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black87)),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (type == 'audio' &&
                                            data['audioUrl'] != null)
                                          Builder(builder: (context) {
                                            final int audioDuration =
                                                data['duration'] ?? 0;
                                            final bool isPlaying =
                                                playingUrl == data['audioUrl'];
                                            final bool isUploading =
                                                data['audioUrl'] == 'uploading';

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 2),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 44,
                                                    height: 44,
                                                    decoration: BoxDecoration(
                                                      color: isMe
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF1E88E5),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: isUploading
                                                        ? Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(12),
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2.5,
                                                              color: isMe
                                                                  ? const Color(
                                                                      0xFF1E88E5)
                                                                  : Colors
                                                                      .white,
                                                            ),
                                                          )
                                                        : GestureDetector(
                                                            onTap: () => playAudio(
                                                                data[
                                                                    'audioUrl'],
                                                                audioDuration),
                                                            child: Icon(
                                                              isPlaying
                                                                  ? Icons.pause
                                                                  : Icons
                                                                      .play_arrow,
                                                              color: isMe
                                                                  ? const Color(
                                                                      0xFF1E88E5)
                                                                  : Colors
                                                                      .white,
                                                              size: 28,
                                                            ),
                                                          ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      buildWaveform(
                                                          data['audioUrl'],
                                                          isMe,
                                                          audioDuration),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        isPlaying
                                                            ? formatAudioDuration(
                                                                _playbackPosition
                                                                    .inSeconds)
                                                            : formatAudioDuration(
                                                                audioDuration),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isMe
                                                              ? Colors.white
                                                                  .withOpacity(
                                                                      0.8)
                                                              : Colors.grey
                                                                  .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          })
                                        else if (type == 'image')
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child: SizedBox(
                                                  width: 250,
                                                  height: 250,
                                                  child: _buildImageItem(data),
                                                ),
                                              ),
                                              if (data['caption'] != null &&
                                                  data['caption']
                                                      .toString()
                                                      .isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 6.0,
                                                          left: 8.0,
                                                          right: 8.0),
                                                  child: Text(
                                                    data['caption'],
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? Colors.white
                                                          : Colors.black,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          )
                                        else if (type == 'file')
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  if (data['isUploading'] !=
                                                      true) {
                                                    launchUrl(
                                                        Uri.parse(data['text']),
                                                        mode: LaunchMode
                                                            .externalApplication);
                                                  }
                                                },
                                                child: SizedBox(
                                                  width: 200,
                                                  child: Row(
                                                    children: [
                                                      Stack(
                                                        alignment:
                                                            Alignment.center,
                                                        children: [
                                                          CircleAvatar(
                                                            radius: 24,
                                                            backgroundColor: isMe
                                                                ? Colors.white24
                                                                : Colors
                                                                    .blueAccent
                                                                    .withOpacity(
                                                                        0.1),
                                                          ),
                                                          if (data[
                                                                  'isUploading'] ==
                                                              true)
                                                            const CircularProgressIndicator(
                                                                color: Colors
                                                                    .white,
                                                                strokeWidth: 2),
                                                          if (data[
                                                                  'isUploading'] !=
                                                              true)
                                                            Icon(
                                                                Icons
                                                                    .insert_drive_file,
                                                                color: isMe
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .blueAccent,
                                                                size: 28),
                                                        ],
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              data['fileName'] ??
                                                                  'Файл',
                                                              style: TextStyle(
                                                                color: isMe
                                                                    ? Colors
                                                                        .white
                                                                    : (Theme.of(context).brightness ==
                                                                            Brightness
                                                                                .dark
                                                                        ? Colors
                                                                            .white
                                                                        : Colors
                                                                            .black),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              data['fileSize'] !=
                                                                      null
                                                                  ? "${(data['fileSize'] / 1024 / 1024).toStringAsFixed(2)} MB"
                                                                  : '',
                                                              style: TextStyle(
                                                                color: isMe
                                                                    ? Colors
                                                                        .white70
                                                                    : Colors
                                                                        .grey,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (data['caption'] != null &&
                                                  data['caption']
                                                      .toString()
                                                      .isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 8.0),
                                                  child: Text(
                                                    data['caption'],
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? Colors.white
                                                          : Colors.black,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          )
                                        else
                                          Text(
                                            data['text'] ?? '',
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : (Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                      : Colors.black),
                                              fontSize: 15,
                                            ),
                                          ),
                                        const SizedBox(height: 5),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (data['isEdited'] == true)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 4.0),
                                                child: Text('изменено',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color: isMe
                                                            ? Colors.white70
                                                            : Colors.grey)),
                                              ),
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
                                                    if (readBy
                                                        .contains(otherUserId))
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
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (widget.mode != 'admin_view')
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (replyToMessage != null || editMessageId != null)
                          Container(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                    editMessageId != null
                                        ? Icons.edit
                                        : Icons.reply,
                                    color: Colors.blueAccent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        editMessageId != null
                                            ? "Изменить сообщение"
                                            : "В ответ",
                                        style: const TextStyle(
                                            color: Colors.blueAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                      Text(
                                        editMessageId != null
                                            ? messageController.text
                                            : (replyToMessage!['text'] ??
                                                'Вложение'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      replyToMessage = null;
                                      if (editMessageId != null) {
                                        editMessageId = null;
                                        messageController.clear();
                                      }
                                    });
                                  },
                                )
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          color: Colors.transparent,
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                    isEmojiVisible
                                        ? Icons.keyboard
                                        : Icons.emoji_emotions_outlined,
                                    color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    isEmojiVisible = !isEmojiVisible;
                                  });
                                  if (isEmojiVisible) {
                                    focusNode.unfocus();
                                  } else {
                                    focusNode.requestFocus();
                                  }
                                },
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF1C1C1E)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: isRecording
                                      ? ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minHeight: 45,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                  formatRecordingDuration(
                                                      _recordingDuration),
                                                  style: TextStyle(
                                                      color: Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black,
                                                      fontSize: 16)),
                                              const Spacer(),
                                              const Text("< Влево — отмена",
                                                  style: TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 14)),
                                            ],
                                          ),
                                        )
                                      : ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight:
                                                120, // max height for multi-line
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Scrollbar(
                                                  child: TextField(
                                                    focusNode: focusNode,
                                                    controller:
                                                        messageController,
                                                    maxLines: null,
                                                    textCapitalization:
                                                        TextCapitalization
                                                            .sentences,
                                                    decoration:
                                                        const InputDecoration(
                                                      hintText: "Message...",
                                                      border: InputBorder.none,
                                                      isCollapsed:
                                                          true, // remove extra padding
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.attach_file,
                                                    color: Colors.grey),
                                                onPressed: _showAttachmentsMenu,
                                              ),
                                            ],
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
                                    icon: Icon(
                                      Icons.send,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Color(0xFF1E1E1E)
                                          : Colors.white,
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
                                        content: Text(
                                            "Аудио жазу үшін басып тұрыңыз"),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  onLongPressStart: (details) async {
                                    await requestMicrophonePermission();
                                    isCancelled = false;
                                    await startRecording(); // Алдымен микрофонды іске қосамыз
                                    // Микрофон іске қосылғаннан КЕЙІН ғана вибрация беріп, UI өзгертеміз:
                                    if (!isCancelled) {
                                      HapticFeedback
                                          .vibrate(); // Телеграм сияқты діріл
                                      setState(() {
                                        _recordingDuration = Duration.zero;
                                        isRecording = true;
                                      });
                                    }
                                  },
                                  onLongPressMoveUpdate: (details) async {
                                    if (details.localOffsetFromOrigin.dx <
                                        -50) {
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
                                      int durSecs =
                                          _recordingDuration.inSeconds;
                                      String? path = await stopRecording();
                                      setState(() {
                                        isRecording =
                                            false; // Мгновенно убираем UI записи
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
                                    decoration: BoxDecoration(
                                      color: Color(0xFF1E88E5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.mic,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Color(0xFF1E1E1E)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isEmojiVisible)
                          SizedBox(
                            height: 250,
                            child: EmojiPicker(
                              onEmojiSelected: (category, emoji) {
                                messageController.text += emoji.emoji;
                              },
                            ),
                          )
                      ],
                    ),
                ],
              );
            },
          )
        ],
      ),
    );
  }
}
