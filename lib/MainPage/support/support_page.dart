import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skillswap/MainPage/support/support_chat_page.dart';
import 'package:skillswap/MainPage/chat/chat_utils.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  String? _selectedCategory;
  String? _selectedSubcategory;
  DateTime? _scheduledDateTime;
  bool _sending = false;
  bool _includeLogs = false;
  final List<XFile> _attachments = [];
  final Map<String, List<Map<String, String>>> _subcategoriesMap = {
    'account': [
      {'key': 'login', 'label': 'loc_login'},
      {'key': 'registration', 'label': 'loc_registration'},
      {'key': 'privacy', 'label': 'loc_privacy'},
      {'key': 'account', 'label': 'loc_account'},
      {'key': 'account_settings', 'label': 'loc_account_settings'},
    ],
    // other category-specific lists can be added here
  };


  final List<Map<String, String>> _categories = [
    {'key': 'account', 'label': 'category_account'},
    {'key': 'payment', 'label': 'category_payment'},
    {'key': 'bug', 'label': 'category_bug'},
    {'key': 'audio', 'label': 'category_audio'},
    {'key': 'feature', 'label': 'category_feature'},
    {'key': 'other', 'label': 'category_other'},
  ];

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    if (_subcategoriesMap.containsKey(_selectedCategory) && _selectedSubcategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('where_problem'.tr())),
      );
      return;
    }
    if (_selectedCategory == 'audio' && _scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('support_validate_time'.tr())),
      );
      return;
    }
    setState(() => _sending = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final user = FirebaseAuth.instance.currentUser;

    // Make sure we have an authenticated user before writing.  Previously a
    // null `uid` would end up in the document and the history query would then
    // run `.where('userId', isEqualTo: null)` which fires a Firestore error and
    // the tab showed "error_loading_history".
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('support_not_logged_in'.tr())),
        );
      }
      setState(() => _sending = false);
      return;
    }

    final ticket = {
      'userId': uid,
      'userEmail': user?.email,
      'category': _selectedCategory,
      'location': _selectedSubcategory,
      'message': _messageController.text.trim(),
      'contact': _contactController.text.trim(),
      'attachments': _attachments.map((f) => f.path).toList(),
      'includeLogs': _includeLogs,
      if (_scheduledDateTime != null) 'scheduledAt': Timestamp.fromDate(_scheduledDateTime!),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    };


    try {
      await FirebaseFirestore.instance.collection('support_tickets').add(ticket);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('support_sent'.tr())),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('support_error'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAttachment() async {
    if (_attachments.length >= 3) return;
    final picker = ImagePicker();
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo),
            title: Text('photo'.tr()),
            onTap: () => Navigator.pop(_, 'photo'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam),
            title: Text('video'.tr()),
            onTap: () => Navigator.pop(_, 'video'),
          ),
        ],
      ),
    );
    if (type == null) return;
    XFile? picked;
    if (type == 'photo') {
      picked = await picker.pickImage(source: ImageSource.gallery);
    } else if (type == 'video') {
      picked = await picker.pickVideo(source: ImageSource.gallery);
    }
    if (picked != null) {
      setState(() {
        _attachments.add(picked!);
      });
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _scheduledDateTime = dt;
      _timeController.text = DateFormat('yyyy-MM-dd HH:mm').format(dt);
    });
  }

  static const String _supportUserId = 'admin';

  Widget _buildHistoryTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // user not logged in yet
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('support_not_logged_in'.tr(), textAlign: TextAlign.center),
        ),
      );
    }

    // If your Firestore rules or index configuration reject the query above you
    // will end up in `snapshot.hasError` and the user will only see a generic
    // "error_loading_history" message.  That was the reason the history tab
    // looked empty previously – the query required a composite index that hadn’t
    // been created.  Rather than depend on an index we now fetch the raw tickets
    // and sort them client–side, which works without any special Firestore
    // configuration.  We also display the actual error text during debugging so
    // it’s easier to spot permission/index problems.

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_tickets')
          .where('userId', isEqualTo: uid)
          // order the results manually below instead of using Firestore's
          // `orderBy` (which requires a composite index when combined with a
          // `where`) to avoid permissions/index errors during development.
          .snapshots(),
      builder: (context, snapshot) {
        // show progress while the stream is still connecting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          // show error message from Firestore so developer can see what went
          // wrong (missing index, permission denied, etc.)
          final err = snapshot.error.toString();
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(err, textAlign: TextAlign.center),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('show_last_month'.tr(), textAlign: TextAlign.center),
            ),
          );
        }
        // sort locally by createdAt timestamp (descending)
        final docs = List.of(snapshot.data!.docs);
        docs.sort((a, b) {
          final aTs = a['createdAt'] as Timestamp?;
          final bTs = b['createdAt'] as Timestamp?;
          if (aTs == null || bTs == null) return 0;
          return bTs.compareTo(aTs);
        });
        // simple list of tickets – tapping one should open a support chat
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final subject = (data['subject'] as String?)?.trim();
            final category = (data['category'] as String?) ?? '';
            final created = (data['createdAt'] as Timestamp?)?.toDate();
            return ListTile(
              title: Text(subject?.isNotEmpty == true ? subject! : category),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty && subject?.isNotEmpty == true)
                    Text(category, style: const TextStyle(fontSize: 12)),
                  if (created != null)
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(created),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              trailing: Text(data['status'] ?? ''),
              onTap: () async {
                // generate a unique chat id for this ticket rather than reusing
                // the general user-admin chat.  including the ticket id ensures
                // separate threads per feedback entry.
                final ticketId = docs[index].id;
                final chatId = 'support_${uid}_$ticketId';
                // make sure the chat document exists before opening the page
                final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
                await chatDoc.set({
                  'members': [uid, _supportUserId],
                  'createdAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                // also ensure the support user record exists so ChatPage header
                // doesn't remain stuck on a spinner
                final adminDoc = FirebaseFirestore.instance.collection('users').doc(_supportUserId);
                await adminDoc.set({'firstName': 'Support'}, SetOptions(merge: true));

                // if the ticket contains a message, add it to this ticket's
                // chat.  because chats are now per-ticket we don't need to
                // worry about mixing with other messages, but still avoid
                // inserting the same text twice on repeated opens.
                final ticketText = (data['message'] as String?)?.trim();
                if (ticketText != null && ticketText.isNotEmpty) {
                  final msgColl = FirebaseFirestore.instance
                      .collection('chats')
                      .doc(chatId)
                      .collection('messages');
                  final existing = await msgColl
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .get();
                  bool shouldAdd = true;
                  if (existing.docs.isNotEmpty) {
                    final last = existing.docs.first.data();
                    if (last['senderId'] == uid &&
                        (last['text'] as String?)?.trim() == ticketText) {
                      shouldAdd = false;
                    }
                  }
                  if (shouldAdd) {
                    await msgColl.add({
                      'senderId': uid,
                      'text': ticketText,
                      'type': 'text',
                      'timestamp': FieldValue.serverTimestamp(),
                      'readBy': [uid],
                    });
                  }
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SupportChatPage(
                      chatId: chatId,
                      ticketId: ticketId,
                      subject: data['subject'] ?? '',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Widget _buildFeedbackTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.support_agent, size: 40, color: Colors.blue.shade700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('support_help_title'.tr(), textAlign: TextAlign.center, style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('support_help_subtitle'.tr(), textAlign: TextAlign.center, style: GoogleFonts.roboto(color: Colors.grey[600])),
                        const SizedBox(height: 16),
                        // category heading
                        Row(
                          children: [
                            const Text('• '),
                            Text('category'.tr(), style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                            const Text('*', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: _categories.map((cat) {
                            final key = cat['key']!;
                            final label = cat['label']!.tr();
                            final selected = _selectedCategory == key;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selected ? Colors.blue : Colors.grey[200],
                                  foregroundColor: selected ? Colors.white : Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedCategory = key;
                                    _selectedSubcategory = null;
                                  });
                                },
                                child: Text(label),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedCategory != null) ...[
                          Row(
                            children: [
                              const Text('• '),
                              Text('where_problem'.tr(), style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                              Text('*', style: TextStyle(color: _subcategoriesMap[_selectedCategory]?.isNotEmpty == true ? Colors.red : Colors.transparent)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_subcategoriesMap[_selectedCategory]?.isNotEmpty == true) ...[
                            ..._subcategoriesMap[_selectedCategory]!
                                .map((sub) => RadioListTile<String>(
                                      title: Text(sub['label']!.tr()),
                                      value: sub['key']!,
                                      groupValue: _selectedSubcategory,
                                      onChanged: (val) => setState(() => _selectedSubcategory = val),
                                    ))
                                .toList(),
                          ],
                          const SizedBox(height: 16),
                          if (_selectedCategory == 'audio') ...[
                            Row(
                              children: [
                                const Text('• '),
                                Text('choose_time'.tr(), style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                                const Text('*', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _timeController,
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: 'select_date_time'.tr(),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                              onTap: _pickDateTime,
                              validator: (v) {
                                if (_selectedCategory == 'audio' && (_scheduledDateTime == null)) {
                                  return 'support_validate_time'.tr();
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                        Row(
                          children: [
                            const Text('• '),
                            Text('description_label'.tr(), style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                            const Text('*', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: TextFormField(
                            controller: _messageController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            decoration: InputDecoration(
                              hintText: 'support_message_hint'.tr(),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'support_validate_message'.tr() : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('• '),
                            Expanded(child: Text('attach_photo_video'.tr(), style: GoogleFonts.roboto(fontWeight: FontWeight.w600))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ..._attachments.map((file) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: file.path.toLowerCase().endsWith('.mp4') || file.path.toLowerCase().endsWith('.mov')
                                  ? Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.videocam, color: Colors.black54),
                                    )
                                  : Image.file(
                                      File(file.path),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  )),
                              if (_attachments.length < 3)
                                GestureDetector(
                                  onTap: _pickAttachment,
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.camera_alt, color: Colors.grey),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('• '),
                            Text('contact_info'.tr(), style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _contactController,
                          decoration: InputDecoration(
                            hintText: 'enter_email'.tr(),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: _includeLogs,
                          onChanged: (v) => setState(() => _includeLogs = v ?? false),
                          title: Text('include_logs'.tr()),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _sending ? null : _submitTicket,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _sending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('send_feedback'.tr()),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: Text('feedback'.tr(), style: GoogleFonts.roboto(color: Colors.black, fontWeight: FontWeight.w600)),
          iconTheme: const IconThemeData(color: Colors.black87),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'support_read_faq'.tr(),
              onPressed: () {
                Navigator.pushNamed(context, '/instructions');
              },
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'feedback'.tr()),
              Tab(text: 'history'.tr()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFeedbackTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }
}
