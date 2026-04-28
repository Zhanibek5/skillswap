import 'package:flutter/material.dart';

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
  static const Color _darkCardColor = Color(0xFF0F1F3B);
  static const Color _darkCardBorderColor = Color(0xFF2B4C85);
  static const Color _darkInputColor = Color(0xFF122A66);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          /// SEARCH FIELD
          Container(
            decoration: BoxDecoration(
              color: isDark ? _darkCardColor : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: isDark
                  ? Border.all(color: _darkCardBorderColor.withOpacity(0.45))
                  : null,
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search skills or people",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.white,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onChanged: widget.onSearchChanged,
            ),
          ),

          SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? _darkInputColor
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: isDark
                        ? Border.all(
                            color: _darkCardBorderColor.withOpacity(0.4))
                        : null,
                  ),
                  child: Stack(
                    children: [
                      // Moving indicator
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.fastOutSlowIn,
                        alignment: selectedIndex == 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E88E5),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Tabs
                      Row(
                        children: [
                          _buildTab("Learn", 0),
                          _buildTab("Teach", 1),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: widget.onFilterTap,
                child: const Icon(
                  Icons.tune,
                  color: Colors.white,
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedIndex = index);
          widget.onModeChanged(index == 0 ? 'learn' : 'teach');
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 600),
            curve: Curves.fastOutSlowIn,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }
}
