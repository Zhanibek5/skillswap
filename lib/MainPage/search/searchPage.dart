import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'searchHeader.dart';
import 'userCard.dart';
import 'filter.dart';
import 'package:easy_localization/easy_localization.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  String searchQuery = '';
  String mode = 'learn';

  double minRating = 0;
  String? selectedLanguage;
  String? selectedSex;
  int? minAge;
  int? maxAge;
  String? selectedActivity;

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
    Query query = FirebaseFirestore.instance.collection('users');

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
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [
            0.0,
            0.4,
            0.75,
            1.0,
          ],
          colors: const [
            Color(0xFF1565C0),
            Color(0xFF1E88E5),
            Color(0xFFE3F2FD),
            Colors.white,
          ],
        )),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              SearchHeader(
                onSearchChanged: (value) {
                  setState(() => searchQuery = value);
                },
                onModeChanged: (value) {
                  setState(() => mode = value);
                },
                onFilterTap: openFilter,
              ),
              const SizedBox(height: 20),
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
                          List<String>.from(data['languages'] ?? []);

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
                              final inSkills = skills.any((skill) =>
                                  skill.toLowerCase().contains(word));
                              return inName || inSkills;
                            });

                      final matchesRating = rating >= minRating;

                      final matchesLanguage = selectedLanguage == null ||
                          languages.any((lang) =>
                              selectedLanguage!.split(',').contains(lang));

                      final selectedSexList = selectedSex?.split(',') ?? [];

                      final matchesSex = selectedSexList.isEmpty
                          ? true
                          : selectedSexList.contains(sex);

                      final matchesAge = (minAge == null || age >= minAge!) &&
                          (maxAge == null || age <= maxAge!);

                      final matchesActivity =
                          selectedActivity == null || selectedActivity == 'all'
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

                    if (filteredUsers.isEmpty) {
                      return Center(
                        child: Text(
                          "User not found".tr(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF203068),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        return UserCard(
                          userId: filteredUsers[index].id,
                          mode: mode,
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 40),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
