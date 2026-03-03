import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillswap/MainPage/Settings/appSettings.dart';
import 'chat/chats_list_page.dart';
import 'profilePage/profile_page.dart';
import 'search/searchPage.dart';
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
  }

  Widget _buildCustomNavBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 25,
            spreadRadius: 5,
            offset: Offset(0, 8),
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
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(Icons.chat, 'chat'.tr(), 0),
                _navItem(Icons.search, 'search'.tr(), 1),
                _navItem(Icons.settings, 'settings'.tr(), 2),
                _navItem(Icons.person_outline, 'profile'.tr(), 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        decoration: BoxDecoration(
          color:
              isSelected ? Color(0xFF1E88E5) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color:
                    isSelected ? Colors.white : Color(0xFF1E88E5) // Black icons
                ),
            if (isSelected)
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
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
