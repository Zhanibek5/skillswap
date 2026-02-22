import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillswap/MainPage/Settings/appSettings.dart';
import 'chat/chatPage.dart';
import 'profilePage/profile_page.dart';
import 'search/searchPage.dart';

class SkillMainPage extends StatefulWidget {
  const SkillMainPage({Key? key}) : super(key: key);

  @override
  State<SkillMainPage> createState() => _SkillMainPageState();
}

class _SkillMainPageState extends State<SkillMainPage> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Locale өзгергенде қайта build жасау
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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Text(""),
          //Text(""),
          //ChatPage(),
          SearchPage(),
          SettingsPage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF5036D5),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'chat'.tr(),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'search'.tr(),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'settings'.tr(),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'profile'.tr(),
          ),
        ],
      ),
    );
  }
}
