import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatPage.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatsListPage extends StatefulWidget {
  const ChatsListPage({super.key});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  String searchText = "";

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          /// TITLE
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 16, top: 60),
            child: Text(
              "SkillSwap",
              style: GoogleFonts.roboto(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E88E5),
              ),
            ),
          ),

          /// SEARCH
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value.toLowerCase();
                  });
                },
                style: const TextStyle(color: Colors.grey),
                decoration: const InputDecoration(
                  hintText: "Search by name or skill",
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ),
          ),

          /// CHAT LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: currentUserId)
                  //   .orderBy('lastTimestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chats = snapshot.data!.docs;

                if (chats.isEmpty) {
                  return Center(
                    child: Text(
                      "No chats yet",
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final participants =
                        List<String>.from(chat['participants']);

                    final otherUserId =
                        participants.firstWhere((id) => id != currentUserId);

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUserId)
                          .snapshots(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return const SizedBox();
                        }

                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>;

                        final name = userData['firstName'] ?? 'No name';
                        final photoUrl = userData['photoUrl'] ?? '';
                        final skill = chat['lastSkill'] ?? '';

                        final lastType = chat['lastType'] ?? 'text';
                        String lastMessage = chat['lastMessage'] ?? '';

                        /// SYSTEM MESSAGE TEXT
                        if (lastType == 'system_meeting_created') {
                          lastMessage = "📅 Кездесу жоспарланды";
                        }

                        if (lastType == 'system_meeting_10min') {
                          lastMessage = "⏰ 10 минут қалды";
                        }

                        if (lastType == 'system_meeting_started') {
                          lastMessage = "🔔 Кездесу басталды";
                        }

                        if (lastType == 'audio') {
                          lastMessage = "🎤 Voice message";
                        }

                        final timestamp = chat['lastTimestamp'];
                        final timeText = formatTime(timestamp);

                        /// SEARCH FILTER
                        final nameLower = name.toLowerCase();
                        final skillLower = skill.toLowerCase();

                        if (searchText.isNotEmpty &&
                            !nameLower.contains(searchText) &&
                            !skillLower.contains(searchText)) {
                          return const SizedBox();
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          padding: const EdgeInsets.all(5),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    chatId: chat.id,
                                    otherUserId: otherUserId,
                                    selectedSkills:
                                        (chat['lastSkill'] as String)
                                            .split(',')
                                            .map((e) => e.trim())
                                            .where((e) => e.isNotEmpty)
                                            .toList(),
                                    mode: 'learn',
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                /// AVATAR
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
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(Icons.person,
                                                  size: 33);
                                            },
                                          )
                                        : const Icon(Icons.person, size: 28),
                                  ),
                                ),

                                const SizedBox(width: 14),

                                /// TEXT AREA
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              "$name • $skill",
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.roboto(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            timeText,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
