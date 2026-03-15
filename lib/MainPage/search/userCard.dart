import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'skillChip.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/MainPage/chat/chatPage.dart';
import 'package:skillswap/MainPage/chat/chat_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skillswap/MainPage/skillMain.dart';
import 'package:skillswap/MainPage/admin/report_dialog.dart';

class UserCard extends StatefulWidget {
  final String userId;
  final String mode;
  final Map<String, dynamic> userData;

  const UserCard({
    super.key,
    required this.userId,
    required this.mode,
    required this.userData,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<UserCard> {
  Set<String> selectedSkills = {};
  String formatTime(timestamp) {
    if (timestamp == null) return '';

    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return DateFormat('HH:mm').format(date);
    }

    if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      return "Yesterday";
    }

    return DateFormat('dd MMM').format(date);
  }

  void _openFeedbackSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Feedback",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _buildFeedbackContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  void startChat({
    required String currentUserId,
    required String otherUserId,
    required List<String> selectedSkills,
    required String mode, // learn or teach
    required BuildContext context,
  }) async {
    final chatId = generateChatId(currentUserId, otherUserId);

    final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);

    final doc = await chatDoc.get();

    if (!doc.exists) {
      await chatDoc.set({
        'participants': [currentUserId, otherUserId],
        'learnerId': mode == 'learn' ? currentUserId : otherUserId,
        'teacherId': mode == 'teach' ? currentUserId : otherUserId,
        'lastMessage': '',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastSkill': selectedSkills.join(', '),
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatId: chatId,
          otherUserId: otherUserId,
          selectedSkills: selectedSkills,
          mode: mode,
        ),
      ),
    ).then((_) {
      mainPageKey.currentState?.changeTab(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.userData;

    final firstName = data['firstName'] ?? '';
    final age = data['age'] ?? '';
    final photoUrl = data['photoUrl'] ?? '';
    final rating = (data['ratingAverage'] ?? 0).toDouble();

    final skillsTeach = data['skillsTeach']?.toString() ?? '';
    final List<String> skillsT = skillsTeach
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final skillsLearn = data['skillsLearn']?.toString() ?? '';
    final List<String> skillsL = skillsLearn
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final skillsToShow = widget.mode == 'learn' ? skillsT : skillsL;

    final languages = List<String>.from(data['languages'] ?? []);

    final bool canTeach = data['canTeach'] ?? true;
    final bool canLearn = data['canLearn'] ?? true;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.fromLTRB(12, 25, 12, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.grey.shade200,
                    child: ClipOval(
                      child: photoUrl != null && photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.person, size: 40);
                              },
                            )
                          : Icon(Icons.person, size: 40),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$firstName, $age",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.mode == 'learn') ...[
                          Text(
                            skillsT.isNotEmpty
                                ? "Teaches: ${skillsT.join(', ')}"
                                : "No skills yet",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          // const SizedBox(height: 3),
                          // Row(
                          //   children: [
                          //     Icon(
                          //       Icons.circle,
                          //       size: 12,
                          //       color: canLearn ? Colors.green : Colors.red,
                          //     ),
                          //     const SizedBox(width: 6),
                          //     Text(
                          //       canLearn
                          //           ? "Ready to learn"
                          //           : "Not learning now",
                          //       style: TextStyle(
                          //         color:
                          //             canLearn ? Colors.green : Colors.red,
                          //         fontWeight: FontWeight.w600,
                          //       ),
                          //     ),
                          //   ],
                          // ),
                        ] else ...[
                          Text(
                            skillsL.isNotEmpty
                                ? "Wants to learn: ${skillsL.join(', ')}"
                                : "No skills yet",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          // const SizedBox(height: 3),
                          // Row(
                          //   children: [
                          //     Icon(
                          //       Icons.circle,
                          //       size: 12,
                          //       color: canTeach ? Colors.green : Colors.red,
                          //     ),
                          //     const SizedBox(width: 6),
                          //     Text(
                          //       canTeach
                          //           ? "Ready to teach"
                          //           : "Not teaching now",
                          //       style: TextStyle(
                          //         color:
                          //             canTeach ? Colors.green : Colors.red,
                          //         fontWeight: FontWeight.w600,
                          //       ),
                          //     ),
                          //   ],
                          // ),
                        ]
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (widget.mode == 'learn')
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber),
                            Text(
                              " ${rating.toStringAsFixed(1)}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      IconButton(
                        icon: const Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 20),
                        tooltip: 'Report User',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          ReportDialog.show(context, widget.userId, 'profile');
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (skillsToShow.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: skillsToShow.map((skill) {
                    final isSelected = selectedSkills.contains(skill);

                    return SkillChip(
                      label: skill,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedSkills.remove(skill);
                          } else {
                            selectedSkills.add(skill);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: languages.isNotEmpty
                        ? Row(
                            children: [
                              const Icon(Icons.language, size: 18),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  languages.join(" / "),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox(),
                  ),
                  ElevatedButton(
                    onPressed: selectedSkills.isEmpty
                        ? null
                        : () async {
                            final currentUserId =
                                FirebaseAuth.instance.currentUser!.uid;

                            // Current user profile тексеру
                            final currentUserDoc = await FirebaseFirestore
                                .instance
                                .collection('users')
                                .doc(currentUserId)
                                .get();

                            final currentUserData = currentUserDoc.data();

                            if (currentUserData?['profileCompleted'] != true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Profile is not complete. Please complete it first."),
                                ),
                              );
                              return;
                            }

                            // 🔥 OTHER USER ACTIVITY CHECK
                            final otherUserDoc = await FirebaseFirestore
                                .instance
                                .collection('users')
                                .doc(widget.userId)
                                .get();

                            final otherUserData = otherUserDoc.data();

                            if (widget.mode == 'learn') {
                              if (otherUserData?['canTeach'] != true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "This user is not teaching currently."),
                                  ),
                                );
                                return;
                              }
                            } else {
                              if (otherUserData?['canLearn'] != true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "This user is not learning currently."),
                                  ),
                                );
                                return;
                              }
                            }

                            // ✅ БӘРІ ДҰРЫС БОЛСА CHAT БАСТАЙМЫЗ
                            startChat(
                              currentUserId: currentUserId,
                              otherUserId: widget.userId,
                              selectedSkills: selectedSkills.toList(),
                              mode: widget.mode,
                              context: context,
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Exchange",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
            top: -18,
            left: 90,
            right: 90,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(width: 0.5, color: Colors.grey),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 10,
                    offset: Offset(2, 2),
                  )
                ],
              ),
              child: Column(
                children: [
                  if (widget.mode == 'learn') ...[
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: canTeach ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          canTeach ? "Ready to teach" : "Not teaching now",
                          style: TextStyle(
                            color: canTeach ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: canLearn ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          canLearn ? "Ready to learn" : "Not learning now",
                          style: TextStyle(
                            color: canLearn ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            )),
        if (widget.mode == 'learn')
          Positioned(
            bottom: -10,
            left: 90,
            right: 90,
            child: ElevatedButton.icon(
              onPressed: () {
                _openFeedbackSheet();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(width: 0.5, color: Colors.grey)),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: Icon(Icons.chat_bubble_outline, color: Colors.yellow[700]),
              label: Text("feedback".tr()),
            ),
          ),
      ],
    );
  }

  Widget _buildFeedbackContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          /// ⭐ AVERAGE RATING
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const SizedBox();
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;

              final avg = (data['ratingAverage'] ?? 0).toDouble();
              final count = (data['ratingCount'] ?? 0);

              return Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  Text(
                    " ${avg.toStringAsFixed(1)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    "  ($count reviews)",
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 15),

          /// 📝 REVIEWS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('teacherId', isEqualTo: widget.userId)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("No feedback yet"));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final rating = (data['rating'] ?? 0).toDouble();
                    final comment = data['comment'] ?? '';
                    final timestamp = data['createdAt'];
                    final learnerID = data['learnerId'];

                    final timeText = formatTime(timestamp);

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(learnerID)
                          .snapshots(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return const SizedBox();
                        }

                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        final username = userData['firstName'] ?? 'Username';
                        final photoUrl = userData['photoUrl'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// 👤 USER INFO
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundImage: photoUrl != null
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: photoUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        username,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      Row(
                                        children: [
                                          ...List.generate(
                                            5,
                                            (index) => Icon(
                                              index < rating
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              size: 18,
                                              color: Colors.amber,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            timeText,
                                            style: const TextStyle(
                                                color: Colors.black45),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              SizedBox(
                                height: 10,
                              ),

                              /// 💬 COMMENT
                              if (comment.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(comment),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
