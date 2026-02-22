import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillswap/loginPage/auth_service.dart';
import 'app_data.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [
                    0.0,
                    0.10,
                    0.15,
                    0.35,
                    0.45,
                    0.58,
                    1.0,
                  ],
                  colors: [
                    Color(0xFF3594DD),
                    Color(0xFF5036D5),
                    Color(0xFF5B16D0),
                    Color(0xFF7A5DE8),
                    Color(0xFFB8B0F5),
                    Color(0xFFF2F1FD),
                    Colors.white,
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

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
                    const SizedBox(height: 10),

                    Text(
                      'delete_account_warning'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF203068),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // EMAIL FIELD
                    TextFormField(
                      controller: controllerEmail,
                      decoration: InputDecoration(
                        labelText: 'email'.tr(),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFF203068),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF203068),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF203068),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelStyle: TextStyle(
                          color: Color(0xFF203068),
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

                    const SizedBox(height: 20),

                    // PASSWORD FIELD
                    TextFormField(
                      controller: controllerPassword,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'password'.tr(),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF203068),
                        ),
                        suffixIcon: IconButton(
                          color: Color(0xFF203068),
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
                            color: Color(0xFF203068),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF203068),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelStyle: TextStyle(
                          color: Color(0xFF203068),
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

                    const SizedBox(height: 20),

                    // ERROR MESSAGE
                    if (errorMessage.isNotEmpty)
                      Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),

                    const SizedBox(height: 30),

                    // DELETE ACCOUNT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF203068),
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
                    const SizedBox(height: 75),
                    Center(
                      child: Text(
                        "SkillSwap",
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ));
  }
}
