import 'package:flutter/material.dart';
import 'package:skillswap/MainPage/chat/chatPage.dart';

/// A thin wrapper around [ChatPage] that pre-configures the parameters
/// required for a support conversation with the hard‑coded admin user.
///
/// Having a separate widget gives us a distinct file that can be opened and
/// modified independently from the main `chatPage.dart` used for regular
/// user‑to‑user discussions.
class SupportChatPage extends StatelessWidget {
  final String chatId;
  final String ticketId;
  final String subject;

  const SupportChatPage({
    Key? key,
    required this.chatId,
    required this.ticketId,
    required this.subject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChatPage(
      chatId: chatId,
      otherUserId: 'admin',
      selectedSkills: [],
      mode: 'support',
    );
  }
}
