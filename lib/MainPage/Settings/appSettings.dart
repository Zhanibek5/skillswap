import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/loginPage/change_password_page.dart';
import 'package:skillswap/loginPage/reset_password_page.dart';
import 'package:skillswap/loginPage/delete_account_page.dart';
import 'package:skillswap/loginPage/login_page.dart';
import 'package:skillswap/MainPage/Settings/privacy_policy_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillswap/background/backgroundColor.dart';
import 'package:skillswap/MainPage/admin/users_management_page.dart';
import 'package:skillswap/MainPage/admin/reports_management_page.dart';
import 'package:skillswap/MainPage/admin/admin_list_page.dart';
import 'instructions_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  String _selectedLanguage = "Қазақша";

  void _showLanguageDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('select_language'.tr()),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _languageOption(Locale('en')),
              _languageOption(Locale('kk')),
              _languageOption(Locale('ru')),
            ],
          ),
        );
      },
    );
  }

  Widget _languageOption(Locale locale) {
    String label;
    if (locale.languageCode == 'en') {
      label = 'english'.tr();
    } else if (locale.languageCode == 'kk')
      label = 'kazakh'.tr();
    else
      label = 'russian'.tr();

    return ListTile(
      title: Text(label),
      onTap: () async {
        await context.setLocale(locale);
        // Persist selection
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_language', locale.languageCode);
        Navigator.of(context).pop();
        setState(() {
          _selectedLanguage = label;
        });
      },
    );
  }

  String _getCurrentLanguageLabel(BuildContext context) {
    final code = context.locale.languageCode;
    if (code == 'en') return 'english'.tr();
    if (code == 'kk') return 'kazakh'.tr();
    return 'russian'.tr();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'settings'.tr(),
          style: GoogleFonts.roboto(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final photoUrl = data['photoUrl'];
          final firstName = data['firstName'] ?? '';
          final lastName = data['lastName'] ?? '';
          final role = data['role'] ?? 'user';

          final displayName = (firstName?.trim().isNotEmpty == true ||
                  lastName?.trim().isNotEmpty == true)
              ? '${firstName ?? ''} ${lastName ?? ''}'.trim()
              : 'username'.tr();

          return Stack(
            children: [
              _background(),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 110, 20, 120),
                child: Column(
                  children: [
                    /// 👤 PROFILE CENTERED
                    Column(
                      children: [
                        SizedBox(
                          height: 10,
                        ),
                        CircleAvatar(
                          radius: 65,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              photoUrl != null && photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                          child: photoUrl == null
                              ? const Icon(Icons.person, size: 80)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          FirebaseAuth.instance.currentUser!.email ?? '',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        // const SizedBox(height: 10),

                        /// ✏️ EDIT PROFILE BUTTON
                        // OutlinedButton(
                        //   style: OutlinedButton.styleFrom(
                        //     foregroundColor: Colors.white,
                        //     side: const BorderSide(color: Colors.white),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(20),
                        //     ),
                        //   ),
                        //   onPressed: () {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (_) => const EditProfilePage(),
                        //       ),
                        //     );
                        //   },
                        //   child: Text('edit_profile'.tr()),
                        // ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    /// 👮 ADMIN CARD
                    if (role == 'admin' || role == 'moderator') ...[
                      _card(
                        children: [
                          _item(
                              Icons.manage_accounts,
                              'Manage Users',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const UsersManagementPage(),
                                  ),
                                );
                              },
                            ),
                            _divider(),
                            _item(
                              Icons.report_problem,
                              'Manage Reports',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReportsManagementPage(),
                                  ),
                                );
                              },
                            ),
                            _divider(),
                            _item(
                              Icons.admin_panel_settings,
                              'Other Admins',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminListPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    /// ⚙️ GENERAL SETTINGS CARD
                    _card(
                      children: [
                        _item(
                          Icons.language,
                          _getCurrentLanguageLabel(context),
                          onTap: _showLanguageDialog,
                        ),
                        _divider(),
                        _item(
                          Icons.lock_outline,
                          'change_password'.tr(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChangePasswordPage()),
                            );
                          },
                        ),
                        _divider(),
                        _item(
                          Icons.lock_reset,
                          'reset_password1'.tr(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResetPasswordPage(
                                  email: FirebaseAuth
                                          .instance.currentUser!.email ??
                                      '',
                                ),
                              ),
                            );
                          },
                        ),
                        _divider(),
                        _item(
                          Icons.privacy_tip_outlined,
                          'privacy_policy'.tr(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyPage(),
                              ),
                            );
                          },
                        ),
                        _divider(),
                        _item(
                          Icons.help_outline,
                          'instructions'.tr(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InstructionsPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    /// ⚠️ ACCOUNT CARD
                    _card(
                      children: [
                        _item(
                          Icons.logout,
                          'logout'.tr(),
                          danger: true,
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginPage()),
                              (route) => false,
                            );
                          },
                        ),
                        _divider(),
                        _item(
                          Icons.delete_forever,
                          'delete_account'.tr(),
                          danger: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DeleteAccountPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 🌈 SAME BACKGROUND
  Widget _background() {
    return Backgroundcolor();
  }

  /// 📦 CARD
  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
      child: Column(children: children),
    );
  }

  /// ➡️ TILE
  Widget _item(
    IconData icon,
    String text, {
    bool danger = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(icon, color: danger ? Colors.red : Colors.black),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: danger ? Colors.red : Colors.black,
                fontSize: 15,
              ),
            ),
            // const Spacer(),
            // const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1),
    );
  }
}
