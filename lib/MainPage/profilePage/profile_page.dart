import 'package:flutter/material.dart';
import 'edit_profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:skillswap/background/backgroundColor.dart';
import 'package:skillswap/settings_provider.dart';

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

  Widget _darkBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0B1A30),
            Color(0xFF1A2D4D),
            Color(0xFF0E1A32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<SettingsProvider>().isDarkMode;

    return Scaffold(
        backgroundColor: dark ? const Color(0xFF0B1A30) : null,
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
                  dark ? _darkBackground() : const Backgroundcolor(),
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
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: dark
                                  ? const [
                                      Color(0xFF182741),
                                      Color(0xFF203155),
                                    ]
                                  : const [
                                      Color(0xFF1A73E8),
                                      Color(0xFF4A90E2),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: dark
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.4),
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
                                      style: TextStyle(color: dark ? Colors.white : Colors.grey[600]),
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
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            adminTitle,
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
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
                                  foregroundColor: Colors.black,
                                ),
                                child: Text('edit'.tr(), style: const TextStyle(color: Colors.black)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statItem(dark, '⭐', '0', 'rating'.tr()),
                            _statItem(dark, '⏱', '2h', 'balance'.tr()),
                            _statItem(dark, '🌐', languagesText, 'language'.tr()),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ===== MY SKILLS =====
                        _sectionTitle(dark, 'my_skills'.tr()),
                        Container(
                          decoration: _boxDecoration(dark),
                          child: Column(
                            children: [
                              skillsList(dark, skillsTeach),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ===== WANT TO LEARN =====
                        _sectionTitle(dark, 'want_to_learn'.tr()),
                        Container(
                          decoration: _boxDecoration(dark),
                          child: Column(
                            children: [
                              skillsList(dark, skillsLearn),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ===== TIME BANK =====
                        _sectionTitle(dark, 'time_bank'.tr()),
                        Container(
                            padding: const EdgeInsets.all(16),
                            decoration: _boxDecoration(dark),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('earned'.tr(),
                                        style: TextStyle(
                                            color: dark ? Colors.white : Colors.black)),
                                    SizedBox(width: 4),
                                    Text(
                                      '0h',
                                      style: TextStyle(
                                          color: dark ? Colors.white : Colors.black),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('spent'.tr(),
                                        style: TextStyle(
                                            color: dark ? Colors.white : Colors.black)),
                                    SizedBox(width: 4),
                                    Text('0h',
                                        style: TextStyle(
                                            color: dark ? Colors.white : Colors.black)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('balance:'.tr(),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: dark ? Colors.white : Colors.black)),
                                    SizedBox(width: 4),
                                    Text('0h',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: dark ? Colors.white : Colors.black)),
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
                            color: dark ? const Color(0xFF1A2438) : Colors.white,
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
                                                fontSize: 16,
                                                color: dark ? Colors.white : Colors.black),
                                          ),
                                          Text(
                                            canTeach
                                                ? 'Available to teach'
                                                : 'Not teaching now',
                                            style: TextStyle(
                                                color: dark ? Colors.grey[400] : Colors.grey[600],
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
                              Divider(
                                height: 24,
                                thickness: 1,
                                color: dark ? Colors.white24 : Colors.grey[300],
                              ),

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
                                                fontSize: 16,
                                                color: dark ? Colors.white : Colors.black),
                                          ),
                                          Text(
                                            canLearn
                                                ? 'Available to learn'
                                                : 'Not learning now',
                                            style: TextStyle(
                                                color: dark ? Colors.grey[400] : Colors.grey[600],
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

  static Widget _statItem(bool dark, String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: dark ? Colors.white : const Color(0xFF203068),
          ),
        ),
        Text(label, style: TextStyle(color: dark ? Colors.grey[300] : Colors.black54)),
      ],
    );
  }

  static Widget _sectionTitle(bool dark, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: dark ? Colors.white : const Color(0xFF203068),
          ),
        ),
      ),
    );
  }

  static Widget _skillRow(bool dark, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dark ? Colors.lightBlueAccent : const Color(0xFF1E88E5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget skillsList(bool dark, String skillsText) {
    if (skillsText.trim().isEmpty) {
      return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'no_skills_added'.tr(),
                style: TextStyle(color: dark ? Colors.white60 : Colors.grey),
              ),
              const Spacer()
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
            _skillRow(dark, skills[index]),
            if (index != skills.length - 1) _divider(dark),
          ],
        );
      }),
    );
  }

  static Widget _divider(bool dark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: dark ? Colors.white24 : Colors.grey[300],
    );
  }

  static BoxDecoration _boxDecoration(bool dark) {
    return BoxDecoration(
      color: dark ? const Color(0xFF1A2438) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: dark ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
