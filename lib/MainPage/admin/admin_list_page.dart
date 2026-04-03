import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skillswap/MainPage/search/userCard.dart';

class AdminListPage extends StatelessWidget {
  const AdminListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin & Moderators'),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .where('role', whereIn: ['admin', 'moderator']).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No admins found.'));
          }

          final admins =
              snapshot.data!.docs.where((doc) => doc.id != currentUid).toList();

          if (admins.isEmpty) {
            return const Center(child: Text('No other admins found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: admins.length,
            itemBuilder: (context, index) {
              final doc = admins[index];
              return UserCard(
                userId: doc.id,
                mode: 'learn', // default mode for layout
                userData: doc.data() as Map<String, dynamic>,
              );
            },
          );
        },
      ),
    );
  }
}
