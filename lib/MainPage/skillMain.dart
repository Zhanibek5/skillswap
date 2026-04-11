import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skillswap/MainPage/Settings/appSettings.dart';
import 'chat/chats_list_page.dart';
import 'profilePage/profile_page.dart';
import 'search/searchPage.dart';
import 'admin/banned_page.dart';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

final GlobalKey<_SkillMainPageState> mainPageKey =
    GlobalKey<_SkillMainPageState>();

class SkillMainPage extends StatefulWidget {
  final int initialIndex;

  SkillMainPage({Key? key, this.initialIndex = 1}) : super(key: mainPageKey);

  @override
  State<SkillMainPage> createState() => _SkillMainPageState();
}

class _SkillMainPageState extends State<SkillMainPage> {
  static const Color _darkCardColor = Color(0xFF0F1F3B);
  static const Color _darkCardBorderColor = Color(0xFF2B4C85);
  late int _selectedIndex;

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    requestNotificationPermission();
    saveFcmToken();
    listenTokenRefresh();
  }

  @override
  void didUpdateWidget(covariant SkillMainPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  void listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([newToken])
      });
    });
  }

  Future<void> requestNotificationPermission() async {
    await Permission.notification.request();
  }

  Future<void> saveFcmToken() async {
    String? token = await FirebaseMessaging.instance.getToken();

    if (token == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'fcmTokens': FieldValue.arrayUnion([token])
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final isBanned = data['isBanned'] ?? false;
          final banExpiration = data['banExpiration'] as Timestamp?;
          final banReason = data['banReason'];

          if (isBanned) {
            if (banExpiration != null &&
                banExpiration.toDate().isBefore(DateTime.now())) {
              // Ban expired automatically
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'isBanned': false,
                'banReason': FieldValue.delete(),
                'banExpiration': FieldValue.delete(),
              });
            } else {
              return BannedPage(
                  reason: banReason, expiration: banExpiration?.toDate());
            }
          }
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
                child: _buildCustomNavBar(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomNavBar(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.15),
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
              color: isDark
                  ? _darkCardColor.withOpacity(0.9)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(40),
              border: isDark
                  ? Border.all(
                      color: _darkCardBorderColor.withOpacity(0.45),
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(context, Icons.chat, 'chat'.tr(), 0),
                _navItem(context, Icons.search, 'search'.tr(), 1),
                _navItem(context, Icons.settings, 'settings'.tr(), 2),
                _navItem(context, Icons.person_outline, 'profile'.tr(), 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? primaryColor 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(
                icon,
                key: ValueKey<bool>(isSelected),
                color: isSelected 
                    ? Colors.white 
                    : (isDark ? Colors.white70 : const Color(0xFF1E88E5)),
                size: isSelected ? 24 : 22,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
