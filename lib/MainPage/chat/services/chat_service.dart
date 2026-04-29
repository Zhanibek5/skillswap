import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId, // needed to update participants effectively
    required String text,
    String type = 'text',
    Map<String, dynamic>? replyTo,
  }) async {
    if (text.trim().isEmpty) return;

    final messageData = {
      'senderId': senderId,
      'text': text,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [senderId],
    };

    if (replyTo != null) {
      messageData['replyTo'] = replyTo;
    }

    final chatRef = _firestore.collection('chats').doc(chatId);

    await chatRef.collection('messages').add(messageData);

    await chatRef.set({
      'participants': [senderId, receiverId],
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastType': type,
    }, SetOptions(merge: true));
  }
}
