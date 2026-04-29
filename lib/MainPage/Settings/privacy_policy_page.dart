import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundColor.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});
  static const Color _darkCardColor = Color(0xFF0F1F3B);
  static const Color _darkCardBorderColor = Color(0xFF2B4C85);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'privacy_policy'.tr(),
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          Backgroundcolor(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? _darkCardColor : Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                      ? Border.all(
                          color: _darkCardBorderColor.withOpacity(0.45))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'privacy_title'.tr(),
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            isDarkMode ? Colors.white : const Color(0xFF203068),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, 'intro_title'.tr()),
                    _buildSectionContent(context, 'intro_text'.tr()),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, 'info_title'.tr()),
                    _buildSectionContent(context, 'info_text'.tr()),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, 'use_title'.tr()),
                    _buildSectionContent(context, 'use_text'.tr()),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, 'share_title'.tr()),
                    _buildSectionContent(context, 'share_text'.tr()),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, 'security_title'.tr()),
                    _buildSectionContent(context, 'security_text'.tr()),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, 'rights_title'.tr()),
                    _buildSectionContent(context, 'rights_text'.tr()),
                    SizedBox(height: 24),
                    Center(
                      child: Text(
                        '${'last_updated'.tr()} ${DateTime.now().year}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDarkMode ? Colors.white : const Color(0xFF203068),
      ),
    );
  }

  Widget _buildSectionContent(BuildContext context, String content) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 14,
          color: isDarkMode ? Colors.white70 : Colors.black87,
          height: 1.5,
        ),
      ),
    );
  }
}
