import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminListPage extends StatelessWidget {
  const AdminListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double topPadding =
        MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'admin_moderators'.tr(),
          style: GoogleFonts.roboto(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black),
        ),
        centerTitle: true,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          isDarkMode
              ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.35, 0.7, 1.0],
                      colors: [
                        Color(0xFF0A1734),
                        Color(0xFF0E214A),
                        Color(0xFF122A66),
                        Color(0xFF0D1B3E),
                      ],
                    ),
                  ),
                )
              : Container(
                  color: Colors.white,
                ),
          // Container(color: Theme.of(context).scaffoldBackgroundColor),
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
                  final userData = doc.data() as Map<String, dynamic>;
                  return _buildAdminCard(context, userData, isDarkMode);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(
      BuildContext context, Map<String, dynamic> data, bool isDarkMode) {
    final firstName = data['firstName']?.toString().trim() ?? '';
    final lastName = data['lastName']?.toString().trim() ?? '';
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final displayName = fullName.isNotEmpty ? fullName : 'username'.tr();
    final email = data['email']?.toString() ?? '';
    final photoUrl = data['photoUrl']?.toString() ?? '';
    final role = data['role']?.toString() ?? '';

    Color roleColor;
    if (role.toLowerCase() == 'admin') {
      roleColor = Colors.green.shade600;
    } else if (role.toLowerCase() == 'moderator') {
      roleColor = Colors.red.shade600;
    } else {
      roleColor = Colors.grey.shade600;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDarkMode ? Colors.transparent : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? const Color(0xFF2B4C85) : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF2B4C85) : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 38,
                backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Icon(Icons.person,
                        size: 38,
                        color: isDarkMode ? Colors.white70 : Colors.grey[400])
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.roboto(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (email.isNotEmpty && email != 'null')
                    Row(
                      children: [
                        Text(
                          '@ ',
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            email,
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  if (role.isNotEmpty && role != 'null')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
