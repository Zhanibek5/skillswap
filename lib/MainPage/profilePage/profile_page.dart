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
  static const Color _darkCardColor = Color(0xFF0F1F3B);
  static const Color _darkCardBorderColor = Color(0xFF2B4C85);

  @override
  void initState() {
    super.initState();
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
      return 'yesterday'.tr();
    }

    return DateFormat('dd MMM').format(date);
  }

  void _openFeedbackSheet(String mode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? _darkCardColor
                : Colors.white,
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
                    Text(
                      mode == 'learn'
                          ? 'learners_feedback'.tr()
                          : 'teachers_feedback'.tr(),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
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
                child: _buildFeedbackContent(mode),
              ),
            ],
          ),
        );
      },
    );
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
              final rating = (data['teacherRating'] ?? 0).toDouble();
              final int balanceMinutes =
                  (data['timeBalance'] ?? data['balance'] ?? 120);
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
                              colors: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const [Color(0xFF173A6D), Color(0xFF0F1F3B)]
                                  : [
                                      const Color(0xFF1A73E8),
                                      const Color(0xFF4A90E2)
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blue.withOpacity(0.15)
                                    : Colors.white.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Border.all(
                                    color:
                                        _darkCardBorderColor.withOpacity(0.45),
                                  )
                                : null,
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 45,
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF122A66)
                                            : Colors.grey.shade200,
                                    backgroundImage:
                                        photoUrl != null && photoUrl.isNotEmpty
                                            ? NetworkImage(photoUrl)
                                            : null,
                                    child: photoUrl == null || photoUrl.isEmpty
                                        ? const Icon(Icons.person, size: 60)
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'welcome'.tr(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          (data['firstName'] != null &&
                                                  data['firstName']
                                                      .toString()
                                                      .isNotEmpty)
                                              ? firstName.trim()
                                              : 'username'.tr(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (role == 'admin' ||
                                            role == 'moderator') ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              adminTitle,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const EditProfilePage(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? _darkCardColor
                                            : Colors.white,
                                    foregroundColor: const Color(0xFF1E88E5),
                                  ),
                                  child: Text('edit'.tr()),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _statItem(context, '⭐',
                                "${rating.toStringAsFixed(1)}", 'rating'.tr()),
                            _statItem(
                                context,
                                '⏱',
                                _formatHoursMinutes(balanceMinutes),
                                'balance'.tr()),
                            _statItem(
                                context, '🌐', languagesText, 'language'.tr()),
                          ],
                        ),

                        SizedBox(height: 24),

                        // ===== MY SKILLS =====
                        _sectionTitle(context, 'my_skills'.tr()),
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
                        _sectionTitle(context, 'want_to_learn'.tr()),
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
                        _sectionTitle(context, 'time_bank'.tr()),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 1),
                            decoration: _boxDecoration(context),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: _timeBankColumn(
                                    icon: Icons.arrow_upward_rounded,
                                    iconColor: Colors.green,
                                    iconBgColor: Colors.green.withOpacity(0.1),
                                    label: 'earned'.tr(),
                                    value: _formatHoursMinutes(timeEarned),
                                    valueColor: Colors.green,
                                  ),
                                ),
                                Container(
                                  height: 50,
                                  width: 1,
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.2),
                                ),
                                Expanded(
                                  child: _timeBankColumn(
                                    icon: Icons.account_balance_wallet_rounded,
                                    iconColor: const Color(0xFF1E88E5),
                                    iconBgColor: const Color(0xFF1E88E5)
                                        .withOpacity(0.1),
                                    label: 'balance'.tr(),
                                    value: _formatHoursMinutes(balanceMinutes),
                                    valueColor: const Color(0xFF1E88E5),
                                    isMain: true,
                                  ),
                                ),
                                Container(
                                  height: 50,
                                  width: 1,
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.2),
                                ),
                                Expanded(
                                  child: _timeBankColumn(
                                    icon: Icons.arrow_downward_rounded,
                                    iconColor: Colors.red,
                                    iconBgColor: Colors.red.withOpacity(0.1),
                                    label: 'spent'.tr(),
                                    value: _formatHoursMinutes(timeSpent),
                                    valueColor: Colors.red,
                                  ),
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
                                            'can_teach'.tr(),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          Text(
                                            canTeach
                                                ? 'available_to_teach'.tr()
                                                : 'not_teaching_now'.tr(),
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.white70
                                                    : Colors.grey[600],
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
                                            'can_learn'.tr(),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          Text(
                                            canLearn
                                                ? 'available_to_learn'.tr()
                                                : 'not_learning_now'.tr(),
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.white70
                                                    : Colors.grey[600],
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
                          decoration: _boxDecoration(context, borderRadius: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// TITLE
                              Row(
                                children: [
                                  Icon(Icons.rate_review,
                                      color: Color(0xFF1E88E5)),
                                  SizedBox(width: 8),
                                  Text(
                                    'feedback'.tr(),
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
                                'see_feedback'.tr(),
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),

                              const SizedBox(height: 15),

                              /// BUTTON
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _openFeedbackSheet('learn');
                                  },
                                  icon: const Icon(Icons.visibility),
                                  label: Text('learners_feedback'.tr()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _openFeedbackSheet('teach');
                                  },
                                  icon: const Icon(Icons.visibility),
                                  label: Text('teachers_feedback'.tr()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
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
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
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
                              Row(
                                children: [
                                  Icon(Icons.video_library,
                                      color: Color(0xFF1E88E5)),
                                  SizedBox(width: 8),
                                  Text(
                                    'history'.tr(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'watch_saved_videos'.tr(),
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : Colors.black54,
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
                                  icon: const Icon(Icons.play_circle_fill),
                                  label: Text('saved_video_history'.tr()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
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

  Widget _buildFeedbackContent(String mode) {
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
              final isDark = Theme.of(context).brightness == Brightness.dark;

              final avg = mode == 'learn'
                  ? (data['teacherRating'] ?? 0).toDouble()
                  : (data['learnerRating'] ?? 0).toDouble();

              final count = mode == 'learn'
                  ? (data['teacherReviewCount'] ?? 0)
                  : (data['learnerReviewCount'] ?? 0);

              return Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  Text(
                    " ${avg.toStringAsFixed(1)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'reviews'.tr(namedArgs: {'count': count.toString()}),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ),
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
                  .where('toUserId', isEqualTo: uid)
                  .where('role',
                      isEqualTo: mode == 'learn' ? 'teacher' : 'learner')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(child: Text('no_feedback'.tr()));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final rating = (data['rating'] ?? 0).toDouble();
                    final comment = data['comment'] ?? '';
                    final timestamp = data['createdAt'];
                    final username = data['fromUserName'] ?? 'Username';
                    final photoUrl = data['fromUserPhoto'];

                    final timeText = formatTime(timestamp);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? _darkCardColor
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(15),
                        border: Theme.of(context).brightness == Brightness.dark
                            ? Border.all(
                                color: _darkCardBorderColor.withOpacity(0.4),
                              )
                            : null,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                        style: TextStyle(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white60
                                              : Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 10),

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
            ),
          ),
        ],
      ),
    );
  }

  // ===== WIDGETS =====

  String _formatHoursMinutes(int totalMinutes) {
    final int safeMinutes = totalMinutes < 0 ? 0 : totalMinutes;
    final int hours = safeMinutes ~/ 60;
    final int minutes = safeMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  Widget _timeBankColumn({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
    required Color valueColor,
    bool isMain = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(isMain ? 10 : 8),
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: isMain ? 28 : 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isMain ? 18 : 16,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isMain ? 14 : 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _statItem(
      BuildContext context, String emoji, String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF203068),
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF203068),
          ),
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

  static BoxDecoration _boxDecoration(
    BuildContext context, {
    double borderRadius = 16,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? _darkCardColor : Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        if (isDark)
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        if (!isDark)
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
      ],
      border: isDark
          ? Border.all(color: _darkCardBorderColor.withOpacity(0.45))
          : null,
    );
  }
}
