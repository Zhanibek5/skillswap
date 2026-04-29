import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chatPage.dart';
import '../support/support_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundForChat.dart';

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
  static const Color _darkTextColor = Colors.white;

  String formatTime(Timestamp? timestamp) {
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
      return 'yesterday'.tr();
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
          const BackgroundForChatcolor(),
          SafeArea(
            child: Column(
              children: [
                /// TITLE
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      ),
                    ],
                  ),
                ),

                /// SEARCH
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? _darkCardColor
                          : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          searchText = value.toLowerCase();
                        });
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'search_by_name_or_skill'.tr(),
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

                      /// SORT
                      chats.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;

                        final aTime = aData['lastTimestamp'] as Timestamp?;
                        final bTime = bData['lastTimestamp'] as Timestamp?;

                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;

                        return bTime.compareTo(aTime);
                      });

                      if (chats.isEmpty) {
                        return Center(
                          child: Text('no_chats_yet'.tr()),
                        );
                      }

                      return ListView.builder(
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final chatData = chat.data() as Map<String, dynamic>;

                          final participants =
                              List<String>.from(chatData['participants'] ?? []);

                          final otherUserId = participants.firstWhere(
                            (id) => id != currentUserId,
                            orElse: () => participants.first,
                          );

                          /// 🔥 UNREAD COUNT (FIXED)
                          final unreadMap = chatData['unreadCount'] ?? {};
                          final unread = (unreadMap[currentUserId] ?? 0) as int;

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

                              final name = userData['firstName'] ?? 'User';
                              final photoUrl = userData['photoUrl'] ?? '';
                              final skill = chatData['lastSkill'] ?? '';
                              final chatType = chatData['chatType'] ?? 'basic';

                              String tagText = '';
                              Color tagColor = Colors.blue;
                              Color tagTextColor = Colors.blue;

                              if (chatType == 'contract' && skill.isNotEmpty) {
                                final isTeaching = chatData['teacherId'] == currentUserId;
                                if (isTeaching) {
                                  tagText = '📚 Учит ' + skill;
                                  tagColor = Colors.purple;
                                  tagTextColor = isDark ? Colors.purple[300]! : Colors.purple;
                                } else {
                                  tagText = '🎓 Изучает ' + skill;
                                  tagColor = Colors.green;
                                  tagTextColor = isDark ? Colors.green[300]! : Colors.green[700]!;
                                }
                              }

                              String lastMessage =
                                  chatData['lastMessage'] ?? '';

                              /// SYSTEM MESSAGES
                              final lastType = chatData['lastType'] ?? 'text';

                              if (lastType == 'system_meeting_created') {
                                lastMessage = 'meeting_scheduled_icon'.tr();
                              }
                              if (lastType == 'system_meeting_10min') {
                                lastMessage = 'ten_min_left'.tr();
                              }
                              if (lastType == 'system_meeting_started') {
                                lastMessage = 'meeting_started'.tr();
                              }

                              final timestamp = chatData['lastTimestamp'];
                              final timeText = formatTime(timestamp);

                              /// SEARCH FILTER
                              if (searchText.isNotEmpty &&
                                  !name.toLowerCase().contains(searchText) &&
                                  !skill.toLowerCase().contains(searchText)) {
                                return const SizedBox();
                              }

                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                        chatId: chat.id,
                                        otherUserId: otherUserId,
                                        selectedSkills:
                                            (chatData['lastSkill'] ?? '')
                                                .toString()
                                                .split(',')
                                                .map((e) => e.trim())
                                                .toList(),
                                        mode: 'chat',
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundImage: photoUrl.isNotEmpty
                                            ? NetworkImage(photoUrl)
                                            : null,
                                        child: photoUrl.isEmpty
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
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
                                                  child: Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          chatType == 'contract' ? name : (skill.isEmpty ? name : "$name • $skill"),
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ),
                                                      if (tagText.isNotEmpty) ...[
                                                        const SizedBox(width: 8),
                                                        Flexible(
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: tagColor.withOpacity(0.15),
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(color: tagColor.withOpacity(0.5), width: 0.5),
                                                            ),
                                                            child: Text(
                                                              tagText,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.w600,
                                                                color: tagTextColor,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  timeText,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    lastMessage,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: unread > 0
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: unread > 0
                                                          ? (isDark
                                                              ? Colors.white
                                                              : Colors.black)
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                if (unread > 0)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 6),
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Colors.blue,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Text(
                                                      unread.toString(),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                              ],
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
