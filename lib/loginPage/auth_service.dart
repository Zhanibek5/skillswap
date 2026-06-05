import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    return await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  Future<void> resetPassword({
    required String email,
  }) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateUsername({
    required String username,
  }) async {
    return currentUser!.updateDisplayName(username);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final uid = user.uid;

    AuthCredential credential =
        EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);

    // 1. Delete profile photo from Storage
    try {
      final photoRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child(uid)
          .child('avatar.jpg');
      await photoRef.delete();
    } catch (e) {
      debugPrint("Photo deletion skipped or failed: $e");
    }

    final firestore = FirebaseFirestore.instance;

    // 2. Delete related reviews
    try {
      final reviewsTo = await firestore
          .collection('reviews')
          .where('toUserId', isEqualTo: uid)
          .get();
      for (var doc in reviewsTo.docs) {
        await doc.reference.delete();
      }

      final reviewsFrom = await firestore
          .collection('reviews')
          .where('fromUserId', isEqualTo: uid)
          .get();
      for (var doc in reviewsFrom.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Error deleting reviews: $e");
    }

    // 3. Delete related reports
    try {
      final reportsBy = await firestore
          .collection('reports')
          .where('reporterId', isEqualTo: uid)
          .get();
      for (var doc in reportsBy.docs) {
        await doc.reference.delete();
      }

      final reportsOf = await firestore
          .collection('reports')
          .where('reportedUserId', isEqualTo: uid)
          .get();
      for (var doc in reportsOf.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Error deleting reports: $e");
    }

    // 4. Delete user document from Firestore
    try {
      await firestore.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint("Error deleting user document: $e");
    }

    // 5. Finally, delete the Auth account
    await user.delete();
    await firebaseAuth.signOut();
  }

  Future<void> resetPasswordFromCurrentPasword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    AuthCredential credential =
        EmailAuthProvider.credential(email: email, password: currentPassword);
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }
}
