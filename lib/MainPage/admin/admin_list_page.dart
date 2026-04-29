import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skillswap/MainPage/search/userCard.dart';
import 'package:skillswap/background/backgroundColor.dart';

class AdminListPage extends StatelessWidget {
  const AdminListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double topPadding =
        MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'admin_moderators'.tr(),
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        centerTitle: true,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (isDarkMode)
            Backgroundcolor()
          else
            Container(color: Theme.of(context).scaffoldBackgroundColor),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('role', whereIn: ['admin', 'moderator']).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'no_admins_found'.tr(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                );
              }

              final admins = snapshot.data!.docs
                  .where((doc) => doc.id != currentUid)
                  .toList();

              if (admins.isEmpty) {
                return Center(
                  child: Text(
                    'no_other_admins'.tr(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, 20),
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
        ],
      ),
    );
  }
}
