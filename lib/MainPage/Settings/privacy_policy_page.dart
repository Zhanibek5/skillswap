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
                      ? Border.all(color: _darkCardBorderColor.withOpacity(0.45))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SkillSwap Privacy Policy',
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF203068),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, '1. Introduction'),
                    _buildSectionContent(
                        context,
                        'Welcome to SkillSwap. We value your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and safeguard your information when you use our application to exchange skills.'),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, '2. Information We Collect'),
                    _buildSectionContent(
                        context,
                        'We collect information you provide directly to us, such as when you create an account, update your profile, and list skills you can teach or want to learn. This includes your name, email address, profile picture, and communication within the app.'),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, '3. How We Use Your Information'),
                    _buildSectionContent(
                        context,
                        'The information we collect is used to matched you with other users for skill exchange, maintain your account, improve our services, and communicate with you about updates and community guidelines.'),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, '4. Data Sharing and Disclosure'),
                    _buildSectionContent(
                        context,
                        'SkillSwap does not sell your personal data. We may share your public profile information (such as your name and listed skills) with other users to facilitate skill exchanges.'),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, '5. Data Security'),
                    _buildSectionContent(
                        context,
                        'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, and destruction. However, no data transmission over the Internet can be guaranteed to be 100% secure.'),
                    SizedBox(height: 16),
                    _buildSectionTitle(context, '6. Your Rights'),
                    _buildSectionContent(
                        context,
                        'You have the right to access, update, or delete your account information at any time within the app settings. You can also contact us for any privacy-related inquiries.'),
                    SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Last updated: ${DateTime.now().year}',
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
