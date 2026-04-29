import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> submitReview({
    required String toUserId,
    required String meetingId,
    required double rating,
    required String comment,
  }) async {
    final String fromUserId = _auth.currentUser!.uid;
    String role;
    final userDoc = await _firestore.collection('users').doc(fromUserId).get();

    final userData = userDoc.data();

    final userName = userData?['firstName'] ?? 'User';
    final photoUrl = userData?['photoUrl'] ?? '';
    final existing = await _firestore
        .collection('reviews')
        .where('meetingId', isEqualTo: meetingId)
        .where('fromUserId', isEqualTo: fromUserId)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('already_reviewed_meeting'.tr());
    }

    final chatDoc = await _firestore.collection('chats').doc(meetingId).get();

    if (!chatDoc.exists) {
      print("Chat not found");
      return;
    }

    final data = chatDoc.data();
    if (data == null) return;

    bool isFromTeacher = data['teacherId'] == fromUserId;

    if (isFromTeacher) {
      role = "learner"; // teacher → learner
    } else {
      role = "teacher"; // learner → teacher
    }

    final userRef = _firestore.collection('users').doc(toUserId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      if (!snapshot.exists) return;

      final userData = snapshot.data()!;

      if (isFromTeacher) {
        // 🔥 teacher → learner
        double currentAvg = (userData['learnerRating'] ?? 0).toDouble();
        int count = (userData['learnerReviewCount'] ?? 0).toInt();
        double newAvg = ((currentAvg * count) + rating) / (count + 1);

        transaction.update(userRef, {
          'learnerRating': newAvg,
          'learnerReviewCount': count + 1,
        });
      } else {
        // 🔥 learner → teacher
        double currentAvg = (userData['teacherRating'] ?? 0).toDouble();
        int count = (userData['teacherReviewCount'] ?? 0).toInt();
        double newAvg = ((currentAvg * count) + rating) / (count + 1);

        transaction.update(userRef, {
          'teacherRating': newAvg,
          'teacherReviewCount': count + 1,
        });
      }
    });

    // 🔥 review сақтау
    await _firestore.collection('reviews').add({
      "fromUserId": fromUserId,
      "toUserId": toUserId,
      "fromUserName": userName,
      "fromUserPhoto": photoUrl,
      "meetingId": meetingId,
      "rating": rating,
      "comment": comment,
      "role": role, // 🔥 ОСЫ ЖЕРГЕ ҚОСАСЫҢ
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}
