import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<DocumentReference> createMeeting(
      String user1Id, String user2Id) async {
    final meeting = await _firestore.collection('meetings').add({
      'user1Id': user1Id,
      'user2Id': user2Id,
      'user1Joined': false,
      'user2Joined': false,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'waiting',
      'duration': 60,
      'user1JoinTime': null,
      'user2JoinTime': null,
    });
    return meeting;
  }

  Future<DocumentSnapshot> getMeeting(String meetingId) async {
    return await _firestore.collection('meetings').doc(meetingId).get();
  }

  Future<void> joinMeeting(String meetingId, String userId) async {
    final meetingRef = _firestore.collection('meetings').doc(meetingId);
    final doc = await meetingRef.get();
    if (!doc.exists) return;

    Map<String, dynamic> update = {};
    if (doc['user1Id'] == userId) {
      update['user1Joined'] = true;
      update['user1JoinTime'] = FieldValue.serverTimestamp();
    } else if (doc['user2Id'] == userId) {
      update['user2Joined'] = true;
      update['user2JoinTime'] = FieldValue.serverTimestamp();
    }
    update['status'] = 'active';
    await meetingRef.update(update);
  }

  Future<void> leaveMeeting(String meetingId, String userId) async {
    final meetingRef = _firestore.collection('meetings').doc(meetingId);
    final doc = await meetingRef.get();
    if (!doc.exists) return;

    Map<String, dynamic> update = {};
    if (doc['user1Id'] == userId) {
      update['user1Joined'] = false;
    } else if (doc['user2Id'] == userId) {
      update['user2Joined'] = false;
    }
    update['status'] = 'finished';
    await meetingRef.update(update);
  }

  // Auto leave & penalty check
  Future<void> checkAutoLeave(String meetingId) async {
    final meetingRef = _firestore.collection('meetings').doc(meetingId);
    final doc = await meetingRef.get();
    if (!doc.exists) return;

    final now = DateTime.now();
    final createdAt = (doc['createdAt'] as Timestamp).toDate();

    final diff = now.difference(createdAt).inMinutes;

    final user1Joined = doc['user1Joined'];
    final user2Joined = doc['user2Joined'];

    if (diff >= 10) {
      if (user1Joined && !user2Joined) {
        // user2 missed -> notify + leave
        // TODO: send notification to user1
        await meetingRef.update({
          'status': 'finished',
          'user2Joined': false,
          'user2Penalty': 0.5, // 0.5 hour penalty
        });
      } else if (!user1Joined && user2Joined) {
        // user1 missed -> notify + leave
        await meetingRef.update({
          'status': 'finished',
          'user1Joined': false,
          'user1Penalty': 0.5,
        });
      } else if (!user1Joined && !user2Joined) {
        // Both missed -> notify chat
        await meetingRef.update({
          'status': 'finished',
          'user1Penalty': 0.5,
          'user2Penalty': 0.5,
          'message': 'Please schedule another meeting time',
        });
      }
    }
  }
}
