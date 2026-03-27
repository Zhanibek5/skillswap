import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:skillswap/background/backgroundColor.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  late final TextEditingController _emailCtrl;
  final _teachCtrl = TextEditingController();
  final _learnCtrl = TextEditingController();
  late final String _email;

  File? _pickedImage;
  String? _photoUrl;
  bool _uploadingPhoto = false;

  String _sex = 'male';
  List<String> _languages = ['KZ'];

  Future<void> _uploadPhoto() async {
    if (_pickedImage == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;

    setState(() => _uploadingPhoto = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child(uid)
          .child('avatar.jpg');

      await ref.putFile(_pickedImage!);

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'photoUrl': url,
      }, SetOptions(merge: true));

      setState(() => _photoUrl = url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();

    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image == null) return;

    setState(() {
      _pickedImage = File(image.path);
    });

    await _uploadPhoto();
  }

  Future<void> _deletePhoto() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child(uid)
          .child('avatar.jpg');

      await ref.delete();
    } catch (_) {}

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'photoUrl': FieldValue.delete(),
    }, SetOptions(merge: true));

    setState(() {
      _photoUrl = null;
      _pickedImage = null;
    });
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final ageParsed = int.tryParse(_ageCtrl.text);

    bool completed = isProfileCompleted(
      name: _firstNameCtrl.text,
      age: ageParsed,
      skillsTeach: _teachCtrl.text,
      skillsLearn: _learnCtrl.text,
      language: _languages.isNotEmpty ? "ok" : "",
    );

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'firstName': _firstNameCtrl.text.trim(),
      'lastName': _lastNameCtrl.text.trim(),
      'age': ageParsed,
      'sex': _sex,
      'languages': _languages,
      'skillsTeach': _teachCtrl.text.trim(),
      'skillsLearn': _learnCtrl.text.trim(),
      'profileCompleted': completed, // 🔥 МАҢЫЗДЫ
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('profile_saved'.tr())),
    );
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    _emailCtrl = TextEditingController(
      text: user?.email ?? '',
    );
    _loadProfile();

    TokenService.updateUserToken();
    TokenService.listenToTokenRefresh();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!doc.exists) return;

    final data = doc.data()!;

    setState(() {
      _firstNameCtrl.text = data['firstName'] ?? '';
      _lastNameCtrl.text = data['lastName'] ?? '';
      _ageCtrl.text = data['age']?.toString() ?? '';
      // _emailCtrl.text = data['email'] ?? '';
      String normalizeSex(String value) {
        switch (value.toLowerCase()) {
          case 'male':
          case 'ер':
          case 'мужчина':
            return 'male';
          case 'female':
          case 'әйел':
          case 'женщина':
            return 'female';
          case 'other':
          case 'басқа':
          case 'другое':
            return 'other';
          default:
            return 'male';
        }
      }

      _sex = normalizeSex(data['sex'] ?? 'male');
      _languages = List<String>.from(data['languages'] ?? []);
      _teachCtrl.text = data['skillsTeach'] ?? '';
      _learnCtrl.text = data['skillsLearn'] ?? '';
      _photoUrl = data['photoUrl'];
    });
  }

  bool isProfileCompleted({
    required String name,
    required int? age,
    required String skillsTeach,
    required String skillsLearn,
    required String language,
  }) {
    return name.trim().isNotEmpty &&
        age != null &&
        skillsTeach.trim().isNotEmpty &&
        skillsLearn.trim().isNotEmpty &&
        language.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Backgroundcolor(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 32),
            child: Column(
              children: [
                // ===== AVATAR =====
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2E35) : Colors.grey.shade200,
                        backgroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!)
                            : (_photoUrl != null && _photoUrl!.isNotEmpty
                                ? NetworkImage(_photoUrl!)
                                : null),
                        child: (_pickedImage == null &&
                                (_photoUrl == null || _photoUrl!.isEmpty))
                            ? const Icon(
                                Icons.person,
                                size: 70,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1E88E5),
                          ),
                          child: GestureDetector(
                            onTap: _uploadingPhoto ? null : _pickPhoto,
                            onLongPress: _uploadingPhoto ? null : _deletePhoto,
                            child: IconButton(
                              icon: _uploadingPhoto
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 20),
                              onPressed: null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ===== MAIN CARD =====
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF1A1A1A) 
                        : Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('personal_information'.tr()),
                      _inputField(
                          label: 'first_name'.tr(),
                          icon: Icons.person_outline,
                          controller: _firstNameCtrl),
                      _inputField(
                          label: 'last_name'.tr(),
                          icon: Icons.person_outline,
                          controller: _lastNameCtrl),
                      _inputField(
                          label: 'age'.tr(),
                          icon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                          controller: _ageCtrl),
                      _inputField(
                          label: 'email'.tr(),
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailCtrl,
                          readOnly: true),
                      sexSelector(
                        label: 'sex'.tr(),
                        selectedValue: _sex,
                        onChanged: (v) => setState(() => _sex = v),
                      ),
                      languageSelector(
                        title: 'languages_comfortable'.tr(),
                        selectedLanguages: _languages,
                        onChanged: (value) {
                          setState(() => _languages = value);
                        },
                      ),
                      SizedBox(height: 24),
                      _sectionTitle('skills'.tr()),
                      _inputField(
                          label: 'skills_teach'.tr(),
                          icon: Icons.school_outlined,
                          hint: 'Flutter, English, Math...',
                          controller: _teachCtrl),
                      _inputField(
                          label: 'skills_learn'.tr(),
                          icon: Icons.lightbulb_outline,
                          hint: 'UI Design, Spanish...',
                          controller: _learnCtrl),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ===== SAVE BUTTON =====
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 6,
                    ),
                    child: Text(
                      'save_changes'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
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
        ],
      ),
    );
  }

  // ===== HELPERS =====

  static Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required IconData icon,
    TextEditingController? controller,
    String? hint,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
  //

  Widget sexSelector({
    required String label,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    const sexCodes = ['male', 'female', 'other'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: sexCodes.map((code) {
                final isSelected = selectedValue == code;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(code),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E88E5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        code.tr(), // тек UI үшін аудару
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sexItem(
    String value,
    String selectedValue,
    ValueChanged<String> onChanged,
  ) {
    final bool isSelected = value == selectedValue;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget languageSelector({
    required String title,
    required List<String> selectedLanguages,
    required ValueChanged<List<String>> onChanged,
  }) {
    const allLanguages = ['KZ', 'RU', 'EN'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: allLanguages.map((lang) {
              final bool isSelected = selectedLanguages.contains(lang);

              return GestureDetector(
                onTap: () {
                  final updated = List<String>.from(selectedLanguages);

                  if (isSelected) {
                    updated.remove(lang);
                  } else {
                    if (updated.length < 3) {
                      updated.add(lang);
                    }
                  }

                  onChanged(updated);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1E88E5)
                        : Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1E88E5)
                          : (Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check, size: 16, color: Colors.white),
                      ]
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            'select_languages_limit'.tr(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class TokenService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> updateUserToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static void listenToTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([newToken]),
      }, SetOptions(merge: true));
    });
  }

  Future<void> logout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();

    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    }

    await FirebaseAuth.instance.signOut();
  }
}
