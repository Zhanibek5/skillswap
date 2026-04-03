import 'package:flutter/material.dart';
import 'edit_profile_page.dart';
import 'saved_videos_list.dart';
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

  String formatTime(timestamp) {
    if (timestamp == null) return '';

    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return DateFormat('HH:mm').format(date);
    }

    if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      return "Yesterday";
    }

    return DateFormat('dd MMM').format(date);
  }

  void _openFeedbackSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Feedback",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _buildFeedbackContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _initUserStatus() async {
    final doc = FirebaseFirestore.instance.collection('users').doc(uid);
    final snapshot = await doc.get();

    if (!snapshot.exists) {
      await doc.set({
        'canTeach': true,
        'canLearn': true,
        'timeEarned': 0,
        'timeSpent': 0,
        'balance': 120, // in minutes
        'ratingAverage': 0,
        'ratingCount': 0,
        'notificationsEnabled': true, // ✅ default ON
      });
    } else {
      final data = snapshot.data()!;

      if (!data.containsKey('canTeach') || !data.containsKey('canLearn')) {
        await doc.update({
          'canTeach': true,
          'canLearn': true,
        });
      }

      if (!data.containsKey('notificationsEnabled')) {
        await doc.update({
          'notificationsEnabled': true,
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
              final rating = (data['ratingAverage'] ?? 0).toDouble();
              final int balanceMinutes = (data['balance'] ?? 120);
              final int timeEarned = (data['timeEarned'] ?? 0);
              final int timeSpent = (data['timeSpent'] ?? 0);


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
              final String adminTitle = data['adminTitle']?.toString() ??
                  (role == 'admin' ? 'Main Admin' : 'Moderator');

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
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: Theme.of(context).brightness == Brightness.dark
                                  ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)] // Elegant dark gradient
                                  : [const Color(0xFF1A73E8), const Color(0xFF4A90E2)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.black.withOpacity(0.6) 
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
                                backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2E35) : Colors.grey.shade200,
                                backgroundImage:
                                    photoUrl != null && photoUrl.isNotEmpty
                                        ? NetworkImage(photoUrl)
                                        : null,
                                child: photoUrl == null || photoUrl.isEmpty
                                    ? Icon(Icons.person, size: 70)
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
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (role == 'admin' ||
                                        role == 'moderator') ...[
                                      SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          adminTitle,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: 4),
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
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
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
                            _statItem('⭐', "${rating.toStringAsFixed(1)}",
                                'rating'.tr()),
                            _statItem('⏱', '2h', 'balance'.tr()),
                            _statItem('🌐', languagesText, 'language'.tr()),
                          ],
                        ),

                        SizedBox(height: 24),

                        // ===== MY SKILLS =====
                        _sectionTitle('my_skills'.tr()),
                        Container(
                          decoration: _boxDecoration(context),
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
                          decoration: _boxDecoration(context),
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
                            decoration: _boxDecoration(context),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.arrow_upward, color: Colors.green, size: 16),
                                    const SizedBox(width: 4),
                                    Text('earned'.tr()),
                                    const SizedBox(width: 4),
                                    Text('h m', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.arrow_downward, color: Colors.red, size: 16),
                                    const SizedBox(width: 4),
                                    Text('spent'.tr()),
                                    const SizedBox(width: 4),
                                    Text('h m', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet, color: Color(0xFF1E88E5), size: 16),
                                    const SizedBox(width: 4),
                                    Text('balance:'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    Text('h m', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E88E5))),
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
                          decoration: _boxDecoration(context),
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
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// TITLE
                              Row(
                                children: const [
                                  Icon(Icons.rate_review,
                                      color: Color(0xFF1E88E5)),
                                  SizedBox(width: 8),
                                  Text(
                                    "Feedback",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              /// DESCRIPTION
                              Text(
                                "See what other users wrote about you.",        
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                                ),
                              ),

                              const SizedBox(height: 15),

                              /// BUTTON
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _openFeedbackSheet();
                                  },
                                  icon: const Icon(Icons.visibility),
                                  label: const Text("View Feedback"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),

                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SavedVideosList(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.video_library),
                                  label: const Text("Saved Video in History"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
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

  Widget _buildFeedbackContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          /// ⭐ AVERAGE RATING
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                return const SizedBox();
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;

              final avg = (data['ratingAverage'] ?? 0).toDouble();
              final count = (data['ratingCount'] ?? 0);

              return Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  Text(
                    " ${avg.toStringAsFixed(1)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    "  ($count reviews)",
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 15),

          /// 📝 REVIEWS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('teacherId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("No feedback yet"));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final rating = (data['rating'] ?? 0).toDouble();
                    final comment = data['comment'] ?? '';
                    final timestamp = data['createdAt'];
                    final learnerID = data['learnerId'];

                    final timeText = formatTime(timestamp);

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(learnerID)
                          .snapshots(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return const SizedBox();
                        }

                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        final username = userData['firstName'] ?? 'Username';
                        final photoUrl = userData['photoUrl'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// 👤 USER INFO
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundImage: photoUrl != null
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: photoUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        username,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      Row(
                                        children: [
                                          ...List.generate(
                                            5,
                                            (index) => Icon(
                                              index < rating
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              size: 18,
                                              color: Colors.amber,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            timeText,
                                            style: const TextStyle(
                                                color: Colors.black45),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              SizedBox(
                                height: 10,
                              ),

                              /// 💬 COMMENT
                              if (comment.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(comment),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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

  static BoxDecoration _boxDecoration(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
    );
  }
}
