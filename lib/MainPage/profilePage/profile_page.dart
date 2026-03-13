import 'package:flutter/material.dart';
import 'edit_profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundColor.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  @override
  void initState() {
    super.initState();
    _initUserStatus();
  }

  void _initUserStatus() async {
    final doc = FirebaseFirestore.instance.collection('users').doc(uid);
    final snapshot = await doc.get();

    if (!snapshot.exists) {
      // Жаңа user үшін document жасау
      await doc.set({
        'canTeach': true,
        'canLearn': true,
        'timeEarned': 0,
        'timeSpent': 0,
        'balance': 2,
      });
    } else {
      // Егер өрістер жоқ болса, қосу
      final data = snapshot.data()!;
      if (!data.containsKey('canTeach') || !data.containsKey('canLearn')) {
        await doc.update({
          'canTeach': true,
          'canLearn': true,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final data = snapshot.data?.data() ?? {};

              final bool canTeach = data['canTeach'] ?? false;
              final bool canLearn = data['canLearn'] ?? false;

              final String? photoUrl = data['photoUrl'];

              final skillsTeach = data['skillsTeach'] ?? '';
              final skillsLearn = data['skillsLearn'] ?? '';

              final List<String> languages =
                  List<String>.from(data['languages'] ?? []);

              final String languagesText =
                  languages.isNotEmpty ? languages.join(', ') : 'KZ';

              final String firstName = data['firstName']?.toString() ?? '';
              final String lastName = data['lastName']?.toString() ?? '';
              final String role = data['role']?.toString() ?? 'user';
              final String adminTitle = data['adminTitle']?.toString() ?? (role == 'admin' ? 'Main Admin' : 'Moderator');

              return Stack(
                fit: StackFit.expand,
                children: [
                  Backgroundcolor(),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // ===== PROFILE HEADER =====
                        SizedBox(
                          height: 50,
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1A73E8),
                                Color(0xFF4A90E2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white
                                    .withOpacity(0.4), // soft white glow
                                blurRadius: 20,
                                spreadRadius: 2,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage:
                                    photoUrl != null && photoUrl.isNotEmpty
                                        ? NetworkImage(photoUrl)
                                        : null,
                                child: photoUrl == null || photoUrl.isEmpty
                                    ? const Icon(Icons.person, size: 70)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'welcome'.tr(),
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    Text(
                                      (data['firstName'] != null &&
                                              data['firstName']
                                                  .toString()
                                                  .isNotEmpty)
                                          ? (firstName).trim()
                                          : 'username'.tr(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),                                      if (role == 'admin' || role == 'moderator') ...[
                                        SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white24,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            adminTitle,
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],                                    SizedBox(height: 4),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const EditProfilePage(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Color(0xFF1E88E5),
                                ),
                                child: Text('edit'.tr()),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statItem('⭐', '0', 'rating'.tr()),
                            _statItem('⏱', '2h', 'balance'.tr()),
                            _statItem('🌐', languagesText, 'language'.tr()),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ===== MY SKILLS =====
                        _sectionTitle('my_skills'.tr()),
                        Container(
                          decoration: _boxDecoration(),
                          child: Column(
                            children: [
                              skillsList(skillsTeach),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ===== WANT TO LEARN =====
                        _sectionTitle('want_to_learn'.tr()),
                        Container(
                          decoration: _boxDecoration(),
                          child: Column(
                            children: [
                              skillsList(skillsLearn),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ===== TIME BANK =====
                        _sectionTitle('time_bank'.tr()),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: _boxDecoration(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('earned'.tr()),
                                    SizedBox(width: 4),
                                    Text(
                                      '0h',
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('spent'.tr()),
                                    SizedBox(width: 4),
                                    Text('0h'),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('balance:'.tr(),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(width: 4),
                                    Text('0h',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            )),
                        SizedBox(
                          height: 5,
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Can Teach
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.school,
                                          color: Color(0xFF1E88E5), size: 28),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Can Teach',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          Text(
                                            canTeach
                                                ? 'Available to teach'
                                                : 'Not teaching now',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    activeThumbColor: Color(0xFF1E88E5),
                                    value: canTeach,
                                    onChanged: (value) {
                                      setState(() {
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(uid)
                                            .update({'canTeach': value});
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Divider(height: 24, thickness: 1),

                              // Can Learn
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.menu_book,
                                          color: Colors.green, size: 28),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Can Learn',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          Text(
                                            canLearn
                                                ? 'Available to learn'
                                                : 'Not learning now',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    activeThumbColor: Colors.green,
                                    value: canLearn,
                                    onChanged: (value) {
                                      setState(() {
                                        FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(uid)
                                            .update({'canLearn': value});
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 70,
                        ),

                        // ElevatedButton(
                        //     onPressed: () {
                        //       Navigator.push(
                        //         context,
                        //         MaterialPageRoute(
                        //           builder: (_) => const SavedVideosPage(),
                        //         ),
                        //       );
                        //     },
                        //     child: Text("Video"))
                      ],
                    ),
                  ),
                ],
              );
            }));
  }

  // ===== WIDGETS =====

  static Widget _statItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF203068)),
        ),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  static Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF203068)),
        ),
      ),
    );
  }

  static Widget _skillRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF1E88E5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget skillsList(String skillsText) {
    if (skillsText.trim().isEmpty) {
      return Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'no_skills_added'.tr(),
                style: TextStyle(color: Colors.grey),
              ),
              Spacer()
            ],
          ));
    }

    final skills = skillsText
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      children: List.generate(skills.length, (index) {
        return Column(
          children: [
            _skillRow(skills[index]),
            if (index != skills.length - 1) _divider(),
          ],
        );
      }),
    );
  }

  static Widget _divider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
    );
  }

  static BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
