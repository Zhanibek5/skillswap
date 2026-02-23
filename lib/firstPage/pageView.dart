import 'package:flutter/material.dart';
import 'package:skillswap/loginPage/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundColor.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  String _selectedLanguage = "Қазақша";
  ButtonStyle commonButtonStyle = ElevatedButton.styleFrom(
    minimumSize: const Size(150, 50), // same width & height for all buttons
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
  );

  final List<Map<String, String>> _pages = [
    {
      "image": "assets/onboarding_1.png",
      "title": 'onboard_title_1',
      "desc": 'onboard_desc_1',
    },
    {
      "image": "assets/onboarding_2.png",
      "title": 'onboard_title_2',
      "desc": 'onboard_desc_2',
    },
    {
      "image": "assets/onboarding_3.png",
      "title": 'onboard_title_3',
      "desc": 'onboard_desc_3',
    },
    {
      "image": "assets/onboarding_4.png",
      "title": 'onboard_title_4',
      "desc": 'onboard_desc_4',
    },
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showLanguageDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
    if (locale.languageCode == 'en')
      label = 'english'.tr();
    else if (locale.languageCode == 'kk')
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [
                  0.0,
                  0.15,
                  0.30,
                  0.45,
                  0.60,
                  0.75,
                  0.90,
                  1.0,
                ],
                colors: [
                  Color(0xFF0D47A1), // deep blue
                  Color(0xFF1565C0),
                  Color(0xFF1976D2),
                  Color(0xFF1E88E5),
                  Color(0xFF42A5F5),
                  Color(0xFF90CAF9),
                  Color(0xFFE3F2FD),
                  Colors.white,
                ],
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 300,
                            width: 300,
                            child: Image.asset(
                              page["image"]!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            page["title"]!.tr(),
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            page["desc"]!.tr(),
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.all(5),
                    height: 8,
                    width: _currentPage == index ? 25 : 12,
                    decoration: BoxDecoration(
                      color:
                          _currentPage == index ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: _prevPage,
                      style: commonButtonStyle.copyWith(
                        backgroundColor:
                            MaterialStateProperty.all(Colors.white),
                        foregroundColor:
                            MaterialStateProperty.all(Color(0xFF1E88E5)),
                        side: MaterialStateProperty.all(
                            const BorderSide(color: Color(0xFF1E88E5))),
                      ),
                      child: Text('previous'.tr()),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_currentPage == _pages.length - 1) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('isFirstLaunch', false);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()),
                          );
                        } else {
                          _nextPage();
                        }
                      },
                      style: commonButtonStyle.copyWith(
                        backgroundColor:
                            MaterialStateProperty.all(Color(0xFF1E88E5)),
                        foregroundColor:
                            MaterialStateProperty.all(Colors.white),
                        side: MaterialStateProperty.all(
                            const BorderSide(color: Colors.white)),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'get_started'.tr()
                            : 'next'.tr(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
          Positioned(
            top: 45,
            right: 15,
            child: Column(
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.language, color: Colors.white, size: 30),
                  onPressed: _showLanguageDialog,
                ),
                // Text(
                //   _getCurrentLanguageLabel(context),
                //   style: const TextStyle(
                //     color: Colors.white,
                //     fontSize: 14,
                //     fontWeight: FontWeight.bold,
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
