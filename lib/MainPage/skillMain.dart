import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:skillswap/settings_provider.dart';
import 'package:skillswap/MainPage/Settings/appSettings.dart';
import 'chat/chats_list_page.dart';
import 'profilePage/profile_page.dart';
import 'search/searchPage.dart';
import 'admin/banned_page.dart';
import 'dart:ui';

final GlobalKey<_SkillMainPageState> mainPageKey =
    GlobalKey<_SkillMainPageState>();

class SkillMainPage extends StatefulWidget {
  SkillMainPage({Key? key}) : super(key: mainPageKey);

  @override
  State<SkillMainPage> createState() => _SkillMainPageState();
}

class _SkillMainPageState extends State<SkillMainPage> {
  int _selectedIndex = 1;

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    EasyLocalization.of(context)!.locale;
    setState(() {});
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final isBanned = data['isBanned'] ?? false;
            final banExpiration = data['banExpiration'] as Timestamp?;
            final banReason = data['banReason'];
            
            if (isBanned) {
              if (banExpiration != null && banExpiration.toDate().isBefore(DateTime.now())) {
                // Ban expired automatically
                FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                  'isBanned': false,
                  'banReason': FieldValue.delete(),
                  'banExpiration': FieldValue.delete(),
                });
              } else {
                return BannedPage(reason: banReason, expiration: banExpiration?.toDate());
              }            }
          }
        return Scaffold(
          extendBody: true, // Blur үшін маңызды
          body: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: const [
                  ChatsListPage(),
                  SearchPage(),
                  SettingsPage(),
                  ProfilePage(),
                ],
              ),

              /// CUSTOM BOTTOM BAR
              Positioned(
                left: 20,
                right: 20,
                bottom: 15,
                child: _buildCustomNavBar(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomNavBar() {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    final barColor = isDark ? const Color(0xFF1E2A3F).withOpacity(0.85) : Colors.white.withOpacity(0.92);
    final iconBaseColor = isDark ? Colors.grey[300]! : const Color(0xFF1E88E5);
    final selectedBgColor = isDark ? const Color(0xFF2A3A5C) : const Color(0xFF1E88E5);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 25,
            spreadRadius: 5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(Icons.chat, 'chat'.tr(), 0, iconBaseColor, selectedBgColor),
                _navItem(Icons.search, 'search'.tr(), 1, iconBaseColor, selectedBgColor),
                _navItem(Icons.settings, 'settings'.tr(), 2, iconBaseColor, selectedBgColor),
                _navItem(Icons.person_outline, 'profile'.tr(), 3, iconBaseColor, selectedBgColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, Color baseIconColor, Color selectedBgColor) {
    bool isSelected = _selectedIndex == index;
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    final iconColor = isSelected ? Colors.white : baseIconColor;
    final textColor = isSelected ? Colors.white : (isDark ? Colors.grey[300]! : Colors.black);
    final bgColor = isSelected
        ? selectedBgColor
        : (isDark ? const Color(0xFF24344F).withOpacity(0.85) : Colors.white.withOpacity(0.05));

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor),
            if (isSelected)
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
