import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:easy_localization/easy_localization.dart';

class SavedVideosList extends StatelessWidget {
  const SavedVideosList({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('saved_video_in_history'.tr())),
        body: Center(child: Text('not_logged_in'.tr())),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('saved_video_in_history'.tr()),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('video_history')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('error_loading_video_history'.tr()));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'no_saved_videos'.tr(),
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final teacherName = data['teacherName'] ?? 'Unknown User';
              final createdAt = data['createdAt'] as Timestamp?;
              final dateStr = createdAt != null
                  ? DateFormat('dd MMM yyyy, HH:mm').format(createdAt.toDate())
                  : 'unknown_date'.tr();

              // Here we assume video is mock/preview
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.video_library, color: Colors.white),
                  ),
                  title: Text(
                    '${'call_with'.tr()} $teacherName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('${'saved_on'.tr()} $dateStr'),
                  ),
                  trailing: const Icon(Icons.play_circle_fill,
                      color: Colors.blueAccent, size: 32),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VideoPlayerScreen(teacherName: teacherName),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String teacherName;
  const VideoPlayerScreen({Key? key, required this.teacherName})
      : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${'call_with'.tr()} ${widget.teacherName}'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 80),
            const SizedBox(height: 20),
            Text(
              'video_not_recorded'.tr(),
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'webrtc_note'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
