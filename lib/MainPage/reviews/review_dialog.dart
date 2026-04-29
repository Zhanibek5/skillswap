import 'package:flutter/material.dart';
import 'star_rating_widget.dart';
import 'review_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

class ReviewDialog extends StatefulWidget {
  final String userName;
  final String chatId;
  final String otherUserId;
  final List<String> selectedSkills;

  const ReviewDialog({
    super.key,
    required this.userName,
    required this.chatId,
    required this.otherUserId,
    required this.selectedSkills,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  double rating = 0;
  final TextEditingController controller = TextEditingController();
  final ReviewService reviewService = ReviewService();
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  bool chatLoaded = false;
  bool amILearner = false;
  bool amITeacher = false;

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

  @override
  void initState() {
    super.initState();
    loadChatInfo();
  }

  Future<String> getTeacherId(String chatId) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final chatDoc =
        await FirebaseFirestore.instance.collection('chats').doc(chatId).get();

    List participants = chatDoc['participants'];

    participants.remove(currentUserId);

    return participants.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<DocumentSnapshot>(
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
          final photoUrl = userData['photoUrl'] ?? '';
          final userName = userData['firstName'] ?? 'No Name';

          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 30,
                    color: Colors.black26,
                    offset: Offset(0, 15),
                  )
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// Close Button
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ),

                    SizedBox(height: 5),

                    /// Title
                    Text(
                      'how_was_lesson'.tr(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 5),

                    Text(
                      'feedback_help_improve'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),

                    SizedBox(height: 20),

                    /// Teacher Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.grey.shade300,
                            child: ClipOval(
                              child: photoUrl.isNotEmpty
                                  ? Image.network(
                                      photoUrl,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.person, size: 30),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  overflow: TextOverflow.ellipsis,
                                  !chatLoaded
                                      ? ""
                                      : amILearner
                                          ? "${'teacher'.tr()} ${widget.selectedSkills.join(", ")}"
                                          : "${'learner'.tr()} ${widget.selectedSkills.join(", ")}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),

                    SizedBox(height: 22),

                    /// Rating
                    Text(
                      'rate_user'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade800,
                      ),
                    ),

                    SizedBox(height: 6),

                    StarRatingWidget(
                      onRatingChanged: (value) {
                        setState(() {
                          rating = value;
                        });
                      },
                    ),

                    SizedBox(height: 22),

                    /// Comment
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'write_feedback'.tr(),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    /// Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: const BorderSide(color: Color(0xFF1E88E5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              'skip'.tr(),
                              style: TextStyle(color: Color(0xFF1E88E5)),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF42A5F5),
                                  Color(0xFF1E88E5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (rating == 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('rate_required'.tr()),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  await reviewService.submitReview(
                                    toUserId: widget.otherUserId,
                                    meetingId: widget.chatId,
                                    rating: rating,
                                    comment: controller.text,
                                  );

                                  Navigator.pop(context);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'submit'.tr(),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
