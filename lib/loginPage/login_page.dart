import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillswap/loginPage/auth_service.dart';
import 'package:skillswap/MainPage/skillMain.dart';
import 'package:google_fonts/google_fonts.dart';
import 'reset_password_page.dart';
import 'package:easy_localization/easy_localization.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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

  void signIn() async {
    try {
      await authService.value.signIn(
          email: controllerEmail.text, password: controllerPassword.text);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SkillMainPage()),
      );
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
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            'login'.tr(),
            style: GoogleFonts.roboto(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          // backgroundColor: Colors.white,
          elevation: 0,
          backgroundColor: Colors.transparent,
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
                      'enterEmailPassword'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF203068),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // EMAIL
                    TextFormField(
                      controller: controllerEmail,
                      keyboardType: TextInputType.emailAddress,
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
                          )),
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

                    // PASSWORD
                    TextFormField(
                      controller: controllerPassword,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'password'.tr(),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF203068),
                        ),
                        labelStyle: TextStyle(
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
                              _obscurePassword = !_obscurePassword;
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

                    // ERROR
                    if (errorMessage.isNotEmpty)
                      Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),

                    const SizedBox(height: 25),

                    // LOGIN BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            signIn();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF203068),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'login'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // REGISTER NAVIGATION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'dont_have_account'.tr(),
                          style: TextStyle(
                            color: Color(0xFF203068),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(
                                context, 'loginPage/register_page.dart');
                          },
                          child: Text('register'.tr(),
                              style: TextStyle(
                                color: Color(0xFF5036D5),
                              )),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('forgot_password'.tr(),
                            style: TextStyle(
                              color: Color(0xFF203068),
                            )),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(
                                context, 'loginPage/reset_password_page.dart');
                          },
                          child: Text('reset_password'.tr(),
                              style: TextStyle(
                                color: Color(0xFF5036D5),
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
