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
  static const Color _darkCardColor = Color(0xFF0F1F3B);
  static const Color _darkCardBorderColor = Color(0xFF2B4C85);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _darkCardColor : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: isDark
            ? Border.all(color: _darkCardBorderColor.withOpacity(0.45))
            : null,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "filter".tr(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            SizedBox(height: 25),
            Text("activity".tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                )),
            SizedBox(height: 10),
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
            SizedBox(height: 25),
            Text("rating".tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                )),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 5),
                Expanded(
                  child: Slider(
                    value: rating,
                    min: 0,
                    max: 5,
                    divisions: 5,
                    activeColor: const Color(0xFF1E88E5),
                    label: "$rating ${"and_higher".tr()}",
                    onChanged: (value) => setState(() => rating = value),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Text("languages_comfortable".tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                )),
            SizedBox(height: 10),
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
            SizedBox(height: 25),
            Text("age".tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                )),
            SizedBox(height: 10),
            RangeSlider(
              values: RangeValues(
                (minAge ?? 16).toDouble(),
                (maxAge ?? 75).toDouble(),
              ),
              min: 16,
              max: 75,
              divisions: 59,
              activeColor: const Color(0xFF1E88E5),
              inactiveColor: isDark
                  ? _darkCardBorderColor.withOpacity(0.5)
                  : Colors.grey.shade300,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  maxAge != null ? "${maxAge!}" : "max_age".tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            SizedBox(height: 25),
            Text("sex".tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                )),
            SizedBox(height: 10),
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
            SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: ButtonStyle(
                        side: WidgetStateProperty.all(
                            BorderSide(color: Color(0xFF1E88E5)))),
                    onPressed: () {
                      Navigator.pop(context, {
                        'rating': 0.0,
                        'language': null,
                        'sex': null,
                        'minAge': null,
                        'maxAge': null,
                        'activity': 'all',
                        'reset': true,
                      });
                    },
                    child: Text(
                      "reset".tr(),
                      style: TextStyle(color: Color(0xFF1E88E5)),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
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
