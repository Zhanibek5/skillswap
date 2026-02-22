import 'package:flutter/material.dart';
import 'skillChip.dart';
import 'package:easy_localization/easy_localization.dart';

class FilterSheet extends StatefulWidget {
  final double minRating;
  final String? selectedLanguage;
  final String? selectedSex;
  final int? minAge;
  final int? maxAge;
  final String? activity;

  const FilterSheet(
      {super.key,
      required this.minRating,
      this.selectedLanguage,
      this.selectedSex,
      this.minAge,
      this.maxAge,
      this.activity});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  double rating = 0;
  String? language;
  int? minAge;
  int? maxAge;
  String activityStatus = "all";

  final List<String> languageCodes = ["KZ", "RU", "EN"];
  final Map<String, String> languageMap = {
    "KZ": "Kazakh".tr(),
    "RU": "Russian".tr(),
    "EN": "English".tr(),
  };

  final List<String> sexCodes = ["male", "female", "other"];
  final Map<String, String> sexMap = {
    "male": "male".tr(),
    "female": "female".tr(),
    "other": "other".tr(),
  };
  Set<String> selectedSexes = {};

  @override
  void initState() {
    super.initState();
    rating = widget.minRating;
    language = widget.selectedLanguage;
    minAge = widget.minAge;
    maxAge = widget.maxAge;
    activityStatus = widget.activity ?? "all";

    if (widget.selectedSex != null) {
      selectedSexes = widget.selectedSex?.split(',').toSet() ?? {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "filter".tr(),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 25),

            Text("activity".tr(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              children: [
                SkillChip(
                  label: "all".tr(),
                  isSelected: activityStatus == "all",
                  onTap: () {
                    setState(() {
                      activityStatus = "all";
                    });
                  },
                ),
                SkillChip(
                  label: "Only Active".tr(),
                  isSelected: activityStatus == "active",
                  onTap: () {
                    setState(() {
                      activityStatus = "active";
                    });
                  },
                ),
                SkillChip(
                  label: "Only Passive".tr(),
                  isSelected: activityStatus == "passive",
                  onTap: () {
                    setState(() {
                      activityStatus = "passive";
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 25),

            /// ⭐ Рейтинг
            Text("rating".tr(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 5),
                Expanded(
                  child: Slider(
                    value: rating,
                    min: 0,
                    max: 5,
                    divisions: 5,
                    activeColor: const Color(0xFF6A3FDB),
                    label: "$rating ${"and_higher".tr()}",
                    onChanged: (value) => setState(() => rating = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            /// 🌍 Тілдер
            Text("languages_comfortable".tr(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: languageCodes.map((code) {
                final isSelected =
                    language != null && language!.split(',').contains(code);

                return SkillChip(
                  label: languageMap[code]!,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        final items = language!.split(',');
                        items.remove(code);
                        language = items.isEmpty ? null : items.join(',');
                      } else {
                        language = language == null ? code : "$language,$code";
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 25),

            Text("age".tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                )),
            const SizedBox(height: 10),

// Slider диапазоны
            RangeSlider(
              values: RangeValues(
                (minAge ?? 16).toDouble(),
                (maxAge ?? 75).toDouble(),
              ),
              min: 16,
              max: 75,
              divisions: 59,
              activeColor: const Color(0xFF6A3FDB),
              inactiveColor: Colors.grey.shade300,
              labels: RangeLabels(
                "${minAge ?? 16}",
                "${maxAge ?? 75}",
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  minAge = values.start.round();
                  maxAge = values.end.round();
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  minAge != null ? "${minAge!}" : "min_age".tr(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  maxAge != null ? "${maxAge!}" : "max_age".tr(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),

            const SizedBox(height: 25),

            /// ⚧ Жыныс
            Text("sex".tr(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: sexCodes.map((code) {
                final isSelected = selectedSexes.contains(code);

                return SkillChip(
                  label: sexMap[code]!,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedSexes.remove(code);
                      } else {
                        selectedSexes.add(code);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            /// ✅ Түймешелер
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigator-пен тек filter мәндерін емес, SearchPage-де қолданылатын мәндерді де reset етеміз
                      Navigator.pop(context, {
                        'rating': 0.0,
                        'language': null,
                        'sex': null,
                        'minAge': null,
                        'maxAge': null,
                        'activity': 'all',
                        'reset': true, // қосымша flag
                      });
                    },
                    child: Text("reset".tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A3FDB),
                    ),
                    onPressed: () {
                      Navigator.pop(context, {
                        'rating': rating,
                        'language': language,
                        'sex': selectedSexes.isEmpty
                            ? null
                            : selectedSexes.join(','),
                        'minAge': minAge,
                        'maxAge': maxAge,
                        'activity': activityStatus,
                      });
                    },
                    child: Text(
                      "show_results".tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
