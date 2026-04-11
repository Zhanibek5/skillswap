import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatPage.dart';
import '../support/support_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundColor.dart';

class ChatsListPage extends StatefulWidget {
  const ChatsListPage({super.key});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  String searchText = "";
  static const Color _darkCardColor = Color(0xFF0F1F3B);
  static const Color _darkCardBorderColor = Color(0xFF2B4C85);
  static const Color _darkInputColor = Color(0xFF122A66);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Backgroundcolor(),
          SafeArea(
            child: Column(
              children: [
                /// TITLE
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(left: 16, top: 12, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "SkillSwap",
                        style: GoogleFonts.roboto(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E88E5),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SupportPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.support_agent_outlined),
                        color: isDark ? Colors.white70 : Colors.grey[700],
                        tooltip: 'support'.tr(),
                      ),
                    ],
                  ),
                ),

                /// SEARCH
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isDark ? _darkCardColor : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: isDark
                          ? Border.all(
                              color: _darkCardBorderColor.withOpacity(0.45),
                            )
                          : null,
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          searchText = value.toLowerCase();
                        });
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                      decoration: InputDecoration(
                        hintText: "Search by name or skill",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(10),
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
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final chats = snapshot.data!.docs.toList();

                      // Sort by lastTimestamp descending
                      chats.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final Timestamp? aTime = aData['lastTimestamp'] as Timestamp?;
                        final Timestamp? bTime = bData['lastTimestamp'] as Timestamp?;
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime);
                      });

                      if (chats.isEmpty) {
                        return Center(
                          child: Text(
                            "No chats yet",
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              color: isDark ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 10, bottom: 20),
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final chatData = chat.data() as Map<String, dynamic>;

                          final participants =
                              List<String>.from(chatData['participants'] ?? []);

                          final otherUserId = participants.firstWhere(
                            (id) => id != currentUserId,
                            orElse: () => participants.isNotEmpty
                                ? participants.first
                                : currentUserId,
                          );

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

                              final userData = userSnapshot.data!.data()
                                  as Map<String, dynamic>;

                              bool isSupportAgent = chatData['isSupport'] == true &&
                                  userData['role'] == 'admin';
                              final name = isSupportAgent
                                  ? 'Support'
                                  : (userData['firstName'] ?? 'No name');
                              final photoUrl = isSupportAgent
                                  ? 'https://cdn-icons-png.flaticon.com/512/3249/3249962.png'
                                  : (userData['photoUrl'] ?? '');
                              final skill = chatData['lastSkill'] ?? '';
                              final lastType = chatData['lastType'] ?? 'text';
                              String lastMessage = chatData['lastMessage'] ?? '';

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

                              final timestamp = chatData['lastTimestamp'];
                              final timeText = formatTime(timestamp);
                              final chatMode = chatData['isSupport'] == true
                                  ? 'support'
                                  : (chatData['teacherId'] == currentUserId
                                      ? 'teach'
                                      : 'learn');

                              /// SEARCH FILTER
                              final nameLower = name.toLowerCase();
                              final skillLower = skill.toLowerCase();

                              if (searchText.isNotEmpty &&
                                  !nameLower.contains(searchText) &&
                                  !skillLower.contains(searchText)) {
                                return const SizedBox();
                              }
                              final isLast = index == chats.length - 1;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(
                                          chatId: chat.id,
                                          otherUserId: otherUserId,
                                          selectedSkills:
                                              (chatData['lastSkill']?.toString() ??
                                                      '')
                                                  .split(',')
                                                  .map((e) => e.trim())
                                                  .where((e) => e.isNotEmpty)
                                                  .toList(),
                                          mode: chatMode,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.transparent
                                          : Colors.white,
                                      border: isLast
                                          ? null
                                          : Border(
                                              bottom: BorderSide(
                                                color: isDark
                                                    ? _darkCardBorderColor
                                                        .withOpacity(0.35)
                                                    : Colors.black12,
                                                width: 0.8,
                                              ),
                                            ),
                                    ),
                                    child: Row(
                                      children: [
                                        /// AVATAR
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: isDark
                                              ? _darkInputColor
                                              : Colors.grey.shade200,
                                          child: ClipOval(
                                            child: photoUrl.isNotEmpty
                                                ? Image.network(
                                                    photoUrl,
                                                    width: 56,
                                                    height: 56,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const Icon(
                                                        Icons.person,
                                                        size: 33,
                                                      );
                                                    },
                                                  )
                                                : const Icon(
                                                    Icons.person,
                                                    size: 28,
                                                  ),
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
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      "$name • $skill",
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: GoogleFonts.roboto(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isDark
                                                            ? Colors.white
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    timeText,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? Colors.white60
                                                          : Colors.grey,
                                                    ),
                                                  )
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                lastMessage,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white70
                                                      : Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
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
          ),
        ],
      ),
    );
  }
}
