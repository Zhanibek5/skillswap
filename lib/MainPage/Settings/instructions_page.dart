import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundColor.dart';

class InstructionsPage extends StatelessWidget {
  const InstructionsPage({super.key});
  static const Color _darkCardColor = Color(0xFF0F1F3B);
  static const Color _darkCardBorderColor = Color(0xFF2B4C85);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'instructions'.tr(),
          style: GoogleFonts.roboto(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Backgroundcolor(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 20,
                ),
                _section(
                  context: context,
                  title: 'app_guide'.tr(),
                  content: 'getting_started'.tr(),
                ),
                SizedBox(height: 20),

                /// 👤 PROFILE SECTION
                _instructionCard(
                  context: context,
                  icon: Icons.person,
                  title: 'profile_setup'.tr(),
                  steps: [
                    'step_complete_profile'.tr(),
                    'step_upload_photo'.tr(),
                    'step_add_skills'.tr(),
                  ],
                ),
                SizedBox(height: 16),

                /// 🎓 TEACHING SECTION
                _instructionCard(
                  context: context,
                  icon: Icons.school,
                  title: 'offer_skill'.tr(),
                  steps: [
                    'step_select_skill'.tr(),
                    'step_set_level'.tr(),
                    'step_wait_request'.tr(),
                  ],
                ),
                SizedBox(height: 16),

                /// 📚 LEARNING SECTION
                _instructionCard(
                  context: context,
                  icon: Icons.book,
                  title: 'request_skill'.tr(),
                  steps: [
                    'step_search_skill'.tr(),
                    'step_view_teacher'.tr(),
                    'step_send_request'.tr(),
                  ],
                ),
                SizedBox(height: 16),

                /// 💬 CHAT SECTION
                _instructionCard(
                  context: context,
                  icon: Icons.chat,
                  title: 'messaging'.tr(),
                  steps: [
                    'step_accept_request'.tr(),
                    'step_start_chat'.tr(),
                    'step_schedule_lesson'.tr(),
                  ],
                ),
                SizedBox(height: 16),

                /// ⏱️ TIME BALANCE SECTION
                _instructionCard(
                  context: context,
                  icon: Icons.timer,
                  title: 'time_balance_info'.tr(),
                  steps: [
                    'step_start_balance'.tr(),
                    'step_earn_time'.tr(),
                    'step_spend_time'.tr(),
                  ],
                ),
                SizedBox(height: 16),

                /// ⭐ RATINGS SECTION
                _instructionCard(
                  context: context,
                  icon: Icons.star,
                  title: 'ratings_reviews'.tr(),
                  steps: [
                    'step_after_lesson'.tr(),
                    'step_rate_user'.tr(),
                    'step_leave_feedback'.tr(),
                  ],
                ),
                SizedBox(height: 20),

                /// 📋 IMPORTANT NOTES
                _section(
                  context: context,
                  title: 'important_notes'.tr(),
                  content: 'community_guidelines'.tr(),
                ),

                SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 📌 SECTION WIDGET
  Widget _section({
    required BuildContext context,
    required String title,
    required String content,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? _darkCardColor : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isDarkMode)
            BoxShadow(
              color: Colors.blue.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
        border: isDarkMode
            ? Border.all(color: _darkCardBorderColor.withOpacity(0.45))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 🎯 INSTRUCTION CARD WITH STEPS
  Widget _instructionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<String> steps,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? _darkCardColor : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isDarkMode)
            BoxShadow(
              color: Colors.blue.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
        border: isDarkMode
            ? Border.all(color: _darkCardBorderColor.withOpacity(0.45))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1E88E5), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...List.generate(
            steps.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
