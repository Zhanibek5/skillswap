import 'package:flutter/material.dart';

class SkillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SkillChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFF1565C0),
                    Color(0xFF1E88E5),
                  ],
                )
              : null,
          color: isSelected ? null : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2E35) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFF1E88E5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF1E88E5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
