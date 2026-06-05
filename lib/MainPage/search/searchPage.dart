import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'searchHeader.dart';
import 'userCard.dart';
import 'filter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundColor.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  String searchQuery = '';
  String mode = 'learn';
  Map<String, dynamic>? currentUserData;

  double minRating = 0;
  String? selectedLanguage;
  String? selectedSex;
  int? minAge;
  int? maxAge;
  String? selectedActivity;

  int levenshtein(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();

    List<List<int>> dp = List.generate(
      a.length + 1,
      (_) => List.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }

    for (int j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 +
              [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                  .reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return dp[a.length][b.length];
  }

  double similarity(String a, String b) {
    final maxLen = [a.length, b.length].reduce((x, y) => x > y ? x : y);
    if (maxLen == 0) return 1.0;

    final distance = levenshtein(a, b);
    return 1 - (distance / maxLen);
  }

  int calculateMatchScore(
    Map<String, dynamic> currentUser,
    Map<String, dynamic> otherUser,
    String mode,
  ) {
    final currentSkills = (mode == 'learn'
                ? currentUser['skillsLearn']
                : currentUser['skillsTeach'])
            ?.toString()
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .toSet() ??
        {};

    final otherSkills =
        (mode == 'learn' ? otherUser['skillsTeach'] : otherUser['skillsLearn'])
                ?.toString()
                .split(',')
                .map((e) => e.trim().toLowerCase())
                .toSet() ??
            {};

    final currentLangs = List<String>.from(currentUser['languages'] ?? [])
        .map((e) => e.toLowerCase())
        .toSet();

    final otherLangs = List<String>.from(otherUser['languages'] ?? [])
        .map((e) => e.toLowerCase())
        .toSet();

    final skillMatch = currentSkills.intersection(otherSkills).length;
    final langMatch = currentLangs.intersection(otherLangs).length;

    if (skillMatch > 0 && langMatch > 0) return 100;
    if (skillMatch > 0) return 70;
    if (langMatch > 0) return 50;
    return 10;
  }

  @override
  void initState() {
    super.initState();
    loadCurrentUser();
  }

  void loadCurrentUser() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();

    setState(() {
      currentUserData = doc.data();
    });
  }

  void openFilter() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(
        minRating: minRating,
        selectedLanguage: selectedLanguage,
        selectedSex: selectedSex,
        minAge: minAge,
        maxAge: maxAge,
        activity: selectedActivity,
      ),
    );

    if (result != null) {
      if (result['reset'] == true) {
        setState(() {
          minRating = 0;
          selectedLanguage = null;
          selectedSex = null;
          minAge = null;
          maxAge = null;
          selectedActivity = 'all';
        });
      } else {
        setState(() {
          minRating = result['rating'] ?? 0;
          selectedLanguage = result['language'];
          selectedSex = result['sex'];
          minAge = result['minAge'];
          maxAge = result['maxAge'];
          selectedActivity = result['activity'] ?? 'all';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('profileCompleted', isEqualTo: true);
    if (selectedActivity == "active") {
      if (mode == 'learn') {
        query = query.where('canTeach', isEqualTo: true);
      } else {
        query = query.where('canLearn', isEqualTo: true);
      }
    }

    if (selectedActivity == "passive") {
      if (mode == 'learn') {
        query = query.where('canTeach', isEqualTo: false);
      } else {
        query = query.where('canLearn', isEqualTo: false);
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Backgroundcolor(),
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 20),
                SearchHeader(
                  onSearchChanged: (value) {
                    setState(() => searchQuery = value);
                  },
                  onModeChanged: (value) {
                    setState(() => mode = value);
                  },
                  onFilterTap: openFilter,
                ),
                SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: query.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final users = snapshot.data!.docs;

                      final filteredUsers = users.where((doc) {
                        if (doc.id == currentUid) return false;

                        final data = doc.data() as Map<String, dynamic>;

                        final role = data['role'] ?? 'user';
                        if (role == 'admin' || role == 'moderator')
                          return false;

                        final fullName =
                            '${data['firstName']} ${data['lastName']}'
                                .toLowerCase();

                        final skills = mode == 'learn'
                            ? (data['skillsTeach'] ?? '')
                                .toString()
                                .split(',')
                                .map((e) => e.trim())
                                .toList()
                            : (data['skillsLearn'] ?? '')
                                .toString()
                                .split(',')
                                .map((e) => e.trim())
                                .toList();

                        final rating = (data['rating'] ?? 0).toDouble();
                        final age = data['age'] ?? 0;
                        final sex = data['sex'] ?? '';
                        final languages =
                            List<String>.from(data['languages'] ?? [])
                                .map((e) => e.toLowerCase())
                                .toList();

                        final queryWords = searchQuery
                            .toLowerCase()
                            .trim()
                            .split(' ')
                            .where((word) => word.isNotEmpty)
                            .toList();

                        final matchesSearch = queryWords.isEmpty
                            ? true
                            : queryWords.every((word) {
                                final inName = fullName.contains(word);
                                final inSkills = skills.any((skill) {
                                  final s = skill.toLowerCase().trim();
                                  final w = word.toLowerCase().trim();

                                  if (s.contains(w)) return true;

                                  if ((s.length - w.length).abs() <= 2) {
                                    return similarity(s, w) > 0.75;
                                  }

                                  return false;
                                });
                                return inName || inSkills;
                              });

                        final matchesRating = rating >= minRating;

                        final matchesLanguage = selectedLanguage == null ||
                            languages.any((lang) => selectedLanguage!
                                .toLowerCase()
                                .split(',')
                                .contains(lang));

                        final selectedSexList = selectedSex?.split(',') ?? [];

                        final matchesSex = selectedSexList.isEmpty
                            ? true
                            : selectedSexList.contains(sex);

                        final matchesAge = (minAge == null || age >= minAge!) &&
                            (maxAge == null || age <= maxAge!);

                        final matchesActivity = selectedActivity == null ||
                                selectedActivity == 'all'
                            ? true
                            : (mode == 'learn'
                                ? (selectedActivity == 'active'
                                    ? data['canTeach'] == true
                                    : data['canTeach'] == false)
                                : (selectedActivity == 'active'
                                    ? data['canLearn'] == true
                                    : data['canLearn'] == false));

                        return matchesSearch &&
                            matchesRating &&
                            matchesLanguage &&
                            matchesSex &&
                            matchesAge &&
                            matchesActivity;
                      }).toList();

                      if (currentUserData != null) {
                        filteredUsers.sort((a, b) {
                          final dataA = a.data() as Map<String, dynamic>;
                          final dataB = b.data() as Map<String, dynamic>;

                          final scoreA = calculateMatchScore(
                              currentUserData!, dataA, mode);
                          final scoreB = calculateMatchScore(
                              currentUserData!, dataB, mode);

                          return scoreB.compareTo(scoreA); // DESC (high first)
                        });
                      }

                      if (filteredUsers.isEmpty) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        return Center(
                          child: Text(
                            "User not found".tr(),
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF203068),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 20,
                          bottom: 90,
                        ),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final doc = filteredUsers[index];
                          return RepaintBoundary(
                            child: UserCard(
                              userId: doc.id,
                              mode: mode,
                              userData: doc.data() as Map<String, dynamic>,
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => SizedBox(height: 40),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
