import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillswap/loginPage/auth_service.dart';
import 'app_data.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundColor.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  static const Color _darkCardColor = Color(0xFF0F1F3B);
  static const Color _darkCardBorderColor = Color(0xFF2B4C85);
  static const Color _accentColor = Color(0xFF1E88E5);
  final formKey = GlobalKey<FormState>();
  TextEditingController controllerEmail = TextEditingController();
  TextEditingController controllerPassword = TextEditingController();
  String errorMessage = '';
  bool _obscurePassword = true;

  void deleteAccount() async {
    try {
      await authService.value.deleteAccount(
          email: controllerEmail.text, password: controllerPassword.text);
      AppData.navBarCurrentIndexNotifier.value = 0;
      AppData.onboardingCurrentIndexNotifier = 0;
      popPage();
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'invalid-email') {
          errorMessage = 'email_badly_formatted'.tr();
        } else {
          errorMessage = 'email_or_password_incorrect'.tr();
        }
      });
    }
  }

  void popPage() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    controllerEmail.dispose();
    controllerPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            'delete_account'.tr(),
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Backgroundcolor(),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),

                    Center(
                      child: SizedBox(
                        width: 400,
                        height: 400,
                        child: Image(
                          image: AssetImage('assets/logoWithName.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    Text(
                      'delete_account_warning'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode
                            ? Colors.white70
                            : const Color(0xFF203068),
                      ),
                    ),

                    SizedBox(height: 30),

                    // EMAIL FIELD
                    TextFormField(
                      controller: controllerEmail,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      cursorColor: _accentColor,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor:
                            isDarkMode ? _darkCardColor : Colors.white.withOpacity(0.95),
                        labelText: 'email'.tr(),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: isDarkMode
                              ? Colors.white70
                              : const Color(0xFF203068),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? _darkCardBorderColor.withOpacity(0.55)
                                : const Color(0xFF203068),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _accentColor,
                            width: 1.4,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.white70
                              : const Color(0xFF203068),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'please_enter_email'.tr();
                        }
                        if (!value.contains("@")) {
                          return 'email_not_valid'.tr();
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 20),

                    // PASSWORD FIELD
                    TextFormField(
                      controller: controllerPassword,
                      obscureText: _obscurePassword,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      cursorColor: _accentColor,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor:
                            isDarkMode ? _darkCardColor : Colors.white.withOpacity(0.95),
                        labelText: 'password'.tr(),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: isDarkMode
                              ? Colors.white70
                              : const Color(0xFF203068),
                        ),
                        suffixIcon: IconButton(
                          color: isDarkMode
                              ? Colors.white70
                              : const Color(0xFF203068),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword =
                                  !_obscurePassword; // көрінетін/жасырын режимді ауыстыру
                            });
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDarkMode
                                ? _darkCardBorderColor.withOpacity(0.55)
                                : const Color(0xFF203068),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _accentColor,
                            width: 1.4,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.white70
                              : const Color(0xFF203068),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'please_enter_password'.tr();
                        }
                        if (value.length < 6) {
                          return 'password_min_6'.tr();
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 20),

                    // ERROR MESSAGE
                    if (errorMessage.isNotEmpty)
                      Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),

                    SizedBox(height: 30),

                    // DELETE ACCOUNT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            deleteAccount();
                          }
                        },
                        child: Text(
                          'delete_account'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 75),
                    Center(
                      child: Text(
                        "SkillSwap",
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ));
  }
}
