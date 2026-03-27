import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'skillChip.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/MainPage/chat/chatPage.dart';
import 'package:skillswap/MainPage/chat/chat_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skillswap/MainPage/skillMain.dart';
import 'package:skillswap/MainPage/admin/report_dialog.dart';
import 'package:provider/provider.dart';
import 'package:skillswap/settings_provider.dart';

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
    final dark = context.watch<SettingsProvider>().isDarkMode;
    final data = widget.userData;

    final firstName = data['firstName'] ?? '';
    final age = data['age'] ?? '';
    final photoUrl = data['photoUrl'] ?? '';
    final rating = (data['rating'] ?? 0).toDouble();

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
            color: dark ? const Color(0xFF1A2438) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: dark ? Colors.black.withOpacity(0.3) : Colors.black12,
                blurRadius: 10,
              )
            ],
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
                                return const Icon(Icons.person, size: 40);
                              },
                            )
                          : const Icon(Icons.person, size: 40),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$firstName, $age",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white : Colors.black,
                          ),
                        ),
                        if (widget.mode == 'learn') ...[
                          Text(
                            skillsT.isNotEmpty
                                ? "Teaches: ${skillsT.join(', ')}"
                                : "No skills yet",
                            style: TextStyle(
                              color: dark ? Colors.grey[300] : Colors.grey,
                            ),
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
                            style: TextStyle(
                              color: dark ? Colors.grey[300] : Colors.grey,
                            ),
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
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber),
                          Text(
                            " $rating",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: dark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        tooltip: 'Report User',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          ReportDialog.show(context, widget.userId, 'profile');
                        },
                      ),
                    ],
                  )
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
                              Icon(Icons.language, size: 18, color: dark ? Colors.white : Colors.black),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  languages.join(" / "),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: dark ? Colors.white : Colors.black),
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
                      backgroundColor: const Color(0xFF4A9FFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Exchange",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        Positioned(
            top: -18,
            left: 90,
            right: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1A2438) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(width: 0.5, color: dark ? Colors.white24 : Colors.grey),
                boxShadow: [
                  BoxShadow(
                    color: dark ? Colors.black54 : Colors.black38,
                    blurRadius: 10,
                    offset: const Offset(2, 2),
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
        Positioned(
          bottom: -10, // Картадан төмен
          left: 90,
          right: 90,
          child: ElevatedButton.icon(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5F5F5),
              foregroundColor: Colors.black87,
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(width: 1, color: Color(0xFFE0E0E0))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: Icon(Icons.chat_bubble_outline, color: Colors.amber[600]),
            label: Text("feedback".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
