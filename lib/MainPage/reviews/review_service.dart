import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> submitReview({
    required String teacherId,
    required String meetingId,
    required double rating,
    required String comment,
  }) async {
    final String learnerId = _auth.currentUser!.uid;

    final teacherRef = _firestore.collection('users').doc(teacherId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(teacherRef);

      if (!snapshot.exists) return;

      final data = snapshot.data()!;

      double currentAverage = (data['ratingAverage'] ?? 0).toDouble();

      int currentCount = (data['ratingCount'] ?? 0);

      double newAverage =
          ((currentAverage * currentCount) + rating) / (currentCount + 1);

      transaction.update(teacherRef, {
        'ratingAverage': newAverage,
        'ratingCount': currentCount + 1,
      });
    });

    // Review сақтау (бөлек)
    await _firestore.collection('reviews').add({
      "teacherId": teacherId,
      "learnerId": learnerId,
      "meetingId": meetingId,
      "rating": rating,
      "comment": comment,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }
}
