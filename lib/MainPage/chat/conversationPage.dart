import 'package:flutter/material.dart';
import 'package:skillswap/MainPage/chat/messagePage.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150'),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aruzhan'),
                Text(
                  'English Teacher',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF5036D5),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              // TODO: schedule lesson
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MessageBubble(
                  text: 'Hi! Are you available today?',
                  isMe: false,
                ),
                MessageBubble(
                  text: 'Yes, after 6 PM',
                  isMe: true,
                ),
                MessageBubble(
                  text: 'Great, let’s schedule!',
                  isMe: false,
                ),
              ],
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  // ✏️ INPUT FIELD
  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type a message',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF5036D5),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () {
                // TODO: send message
              },
            ),
          ),
        ],
      ),
    );
  }
}
