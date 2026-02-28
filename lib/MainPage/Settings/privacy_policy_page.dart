import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundColor.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SkillSwap Privacy Policy',
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF203068),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('1. Introduction'),
                    _buildSectionContent(
                        'Welcome to SkillSwap. We value your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and safeguard your information when you use our application to exchange skills.'),
                    const SizedBox(height: 16),
                    _buildSectionTitle('2. Information We Collect'),
                    _buildSectionContent(
                        'We collect information you provide directly to us, such as when you create an account, update your profile, and list skills you can teach or want to learn. This includes your name, email address, profile picture, and communication within the app.'),
                    const SizedBox(height: 16),
                    _buildSectionTitle('3. How We Use Your Information'),
                    _buildSectionContent(
                        'The information we collect is used to matched you with other users for skill exchange, maintain your account, improve our services, and communicate with you about updates and community guidelines.'),
                    const SizedBox(height: 16),
                    _buildSectionTitle('4. Data Sharing and Disclosure'),
                    _buildSectionContent(
                        'SkillSwap does not sell your personal data. We may share your public profile information (such as your name and listed skills) with other users to facilitate skill exchanges.'),
                    const SizedBox(height: 16),
                    _buildSectionTitle('5. Data Security'),
                    _buildSectionContent(
                        'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, and destruction. However, no data transmission over the Internet can be guaranteed to be 100% secure.'),
                    const SizedBox(height: 16),
                    _buildSectionTitle('6. Your Rights'),
                    _buildSectionContent(
                        'You have the right to access, update, or delete your account information at any time within the app settings. You can also contact us for any privacy-related inquiries.'),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Last updated: ${DateTime.now().year}',
                        style: TextStyle(
                          color: Colors.grey,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF203068),
      ),
    );
  }

  Widget _buildSectionContent(String content) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: Text(
        content,
        style: TextStyle(
          fontSize: 14,
          color: Colors.black87,
          height: 1.5,
        ),
      ),
    );
  }
}
