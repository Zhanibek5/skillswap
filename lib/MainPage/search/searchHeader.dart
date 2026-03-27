import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skillswap/settings_provider.dart';

class SearchHeader extends StatefulWidget {
  final Function(String) onSearchChanged;
  final Function(String) onModeChanged;
  final VoidCallback onFilterTap;

  const SearchHeader({
    super.key,
    required this.onSearchChanged,
    required this.onModeChanged,
    required this.onFilterTap,
  });

  @override
  State<SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<SettingsProvider>().isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          /// SEARCH FIELD
          Container(
            decoration: BoxDecoration(
              color: dark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              style: TextStyle(color: dark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: "Search skills or people",
                hintStyle: TextStyle(color: dark ? Colors.white60 : Colors.white70),
                prefixIcon: Icon(Icons.search, color: dark ? Colors.white : Colors.white),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onChanged: widget.onSearchChanged,
            ),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: dark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildTab("Learn", 0, dark),
                      _buildTab("Teach", 1, dark),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: widget.onFilterTap,
                child: Icon(
                  Icons.tune,
                  color: dark ? Colors.white : Colors.white,
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTab(String text, int index, bool dark) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedIndex = index);
          widget.onModeChanged(index == 0 ? 'learn' : 'teach');
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (dark ? Color(0xFF1A2438) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Color(0xFF1E88E5) : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
