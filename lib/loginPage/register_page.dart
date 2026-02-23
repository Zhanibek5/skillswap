import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skillswap/loginPage/auth_service.dart';
import 'package:skillswap/loginPage/verify_email.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillswap/background/backgroundColor.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  TextEditingController controllerEmail = TextEditingController();
  TextEditingController controllerPassword = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String errorMessage = '';
  bool _obscurePassword = true;

  @override
  void dispose() {
    controllerEmail.dispose();
    controllerPassword.dispose();
    super.dispose();
  }

  void register() async {
    try {
      await authService.value.createAccount(
        email: controllerEmail.text,
        password: controllerPassword.text,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailPage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'invalid-email':
            errorMessage = 'email_badly_formatted'.tr();
            break;
          case 'email-already-in-use':
            errorMessage = 'email_already_in_use'.tr();
            break;
          default:
            errorMessage = 'error'.tr();
        }
      });
    }
  }

  void popPage() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            'register'.tr(),
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
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
                    const SizedBox(height: 20),

                    // Title
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
                      'sign_up_with_email'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF203068),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // EMAIL FIELD
                    TextFormField(
                      controller: controllerEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                          labelText: 'email'.tr(),
                          prefixIcon: Icon(
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
                          )),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'please_enter_email'.tr();
                        }
                        if (!value.contains('@')) {
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
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),

                    const SizedBox(height: 25),

                    // BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            register();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1E88E5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'register'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Already have account?
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'already_have_account'.tr(),
                          style: TextStyle(
                            color: Color(0xFF203068),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'login'.tr(),
                            style: TextStyle(
                              color: Color(0xFF1E88E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 35),
                    Center(
                      child: Text(
                        "SkillSwap",
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ));
  }
}
