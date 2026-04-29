import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:skillswap/MainPage/search/userCard.dart';
import 'package:skillswap/MainPage/chat/chatPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skillswap/background/backgroundColor.dart';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';

class ReportsManagementPage extends StatelessWidget {
  const ReportsManagementPage({super.key});
  static const Color _darkCardColor = Color(0xFF0F1F3B);
  static const Color _darkCardBorderColor = Color(0xFF2B4C85);
  static const Color _accentColor = Color(0xFF1E88E5);

  void _updateReportStatus(String reportId, String status) {
    FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .update({'status': status});
  }

  void _viewProfile(BuildContext context, String userId) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) return;

    if (context.mounted) {
      showDialog(
          context: context,
          builder: (context) {
            final bool isDarkMode =
                Theme.of(context).brightness == Brightness.dark;
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Scaffold(
                  appBar: AppBar(
                      title: Text(
                        'user_profile_view'.tr(),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      foregroundColor: isDarkMode ? Colors.white : Colors.black,
                      backgroundColor: isDarkMode ? _darkCardColor : null,
                      leading: const CloseButton()),
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: UserCard(
                          userId: userId, mode: 'learn', userData: doc.data()!),
                    ),
                  ),
                ),
              ),
            );
          });
    }
  }

  void _showBanDialog(
      BuildContext context, String reportedUserId, String reportId) {
    String selectedDuration = '1 hour';
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDarkMode ? _darkCardColor : Colors.white,
            title: Text(
              'ban_user'.tr(),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'ban_reason'.tr(),
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? _darkCardBorderColor.withOpacity(0.55)
                            : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: _accentColor, width: 1.4),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  dropdownColor: isDarkMode ? _darkCardColor : Colors.white,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  value: selectedDuration,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '1 hour', child: Text('1 hour')),
                    DropdownMenuItem(
                        value: '24 hours', child: Text('24 hours')),
                    DropdownMenuItem(value: '7 days', child: Text('7 days')),
                    DropdownMenuItem(
                        value: 'permanent', child: Text('Permanent')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      selectedDuration = val!;
                    });
                  },
                )
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'cancel'.tr(),
                    style: TextStyle(color: _accentColor),
                  )),
              ElevatedButton(
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('reason_required'.tr())));
                    return;
                  }

                  DateTime? expiration;
                  final now = DateTime.now();
                  if (selectedDuration == '1 hour') {
                    expiration = now.add(const Duration(hours: 1));
                  } else if (selectedDuration == '24 hours')
                    expiration = now.add(const Duration(hours: 24));
                  else if (selectedDuration == '7 days')
                    expiration = now.add(const Duration(days: 7));

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(reportedUserId)
                      .update({
                    'isBanned': true,
                    'banReason': reasonController.text.trim(),
                    'banExpiration': expiration != null
                        ? Timestamp.fromDate(expiration)
                        : FieldValue.delete(),
                  });

                  _updateReportStatus(reportId, 'resolved');
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('user_banned'.tr())),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('ban'.tr()),
              )
            ],
          );
        });
      },
    );
  }

  void _replyToFeedback(
      BuildContext context, String reporterId, String initialMessage) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .where('isSupport', isEqualTo: true)
        .get();

    String chatId = '';
    for (var doc in chatQuery.docs) {
      List participants = doc['participants'] ?? [];
      if (participants.contains(reporterId)) {
        chatId = doc.id;
        break;
      }
    }

    if (chatId.isEmpty) {
      final newChat = await FirebaseFirestore.instance.collection('chats').add({
        'participants': [currentUserId, reporterId],
        'isSupport': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': initialMessage,
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
      chatId = newChat.id;

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId':
            reporterId, // Pretend the user sent it so it appears on the left
        'text': initialMessage,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [reporterId],
      });
    }

    if (context.mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatPage(
                    chatId: chatId,
                    otherUserId: reporterId,
                    selectedSkills: const [],
                    mode: 'support_admin',
                  )));
    }
  }

  Widget _buildReportCard(
      BuildContext context, DocumentSnapshot reportDoc, bool isFeedback) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color primaryText = isDarkMode ? Colors.white : Colors.black87;
    final Color secondaryText =
        isDarkMode ? Colors.white70 : Colors.grey.shade700;
    final data = reportDoc.data() as Map<String, dynamic>;
    final reportId = reportDoc.id;

    final reporterId = data['reporterId'] ?? '';
    final reportedUserId = data['reportedUserId'] ?? '';
    final reason = data['reason'] ?? 'No reason provided';
    final status = data['status'] ?? 'pending';
    final targetType = data['targetType'] ?? 'unknown';
    final targetId = data['targetId'];
    final category = data['category'];
    final location = data['location'];
    final List<dynamic>? attachments = data['attachments'] as List<dynamic>?;

    DateTime? date;
    if (data['createdAt'] != null) {
      date = (data['createdAt'] as Timestamp).toDate();
    }
    final dateStr = date != null
        ? DateFormat('dd MMM yyyy, HH:mm').format(date)
        : 'Unknown date';

    Color statusColor = Colors.orange;
    if (status == 'resolved') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDarkMode ? _darkCardColor : Theme.of(context).cardColor,
      shadowColor: isDarkMode
          ? Colors.blue.withOpacity(0.2)
          : Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: statusColor, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    isFeedback
                        ? '${'category'.tr()} ${category ?? 'general'.tr()}'
                        : '${'type'.tr()} $targetType',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    )),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (isFeedback && location != null) ...[
              Text('${'subcategory'.tr()} $location',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: secondaryText,
                  )),
              const SizedBox(height: 8),
            ],
            if (!isFeedback)
              Text('${'reported_user_id'.tr()}\n$reportedUserId',
                  style: TextStyle(fontSize: 12, color: secondaryText)),
            const SizedBox(height: 4),
            Text('${'from_user_id'.tr()} $reporterId',
                style: TextStyle(fontSize: 12, color: secondaryText)),
            const SizedBox(height: 12),
            Text(
              'message_reason'.tr(),
              style: TextStyle(fontWeight: FontWeight.bold, color: primaryText),
            ),
            Text(reason, style: TextStyle(fontSize: 14, color: primaryText)),
            const SizedBox(height: 8),
            if (attachments != null && attachments.isNotEmpty) ...[
              Text('attachments'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  )),
              const SizedBox(height: 4),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  itemBuilder: (context, idx) {
                    final path = attachments[idx].toString();
                    if (path.toLowerCase().endsWith('.mp4') ||
                        path.toLowerCase().endsWith('.mov')) {
                      return Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        color: isDarkMode
                            ? _darkCardBorderColor
                            : Colors.grey.shade300,
                        child: const Icon(Icons.videocam),
                      );
                    }
                    return Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      child: Image.file(File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.error)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text('${'date'.tr()} $dateStr',
                style: TextStyle(fontSize: 12, color: secondaryText)),
            Divider(color: isDarkMode ? Colors.white30 : Colors.black26),
            Wrap(
              spacing: 8,
              children: [
                if (!isFeedback && targetType == 'chat' && targetId != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accentColor,
                      side: BorderSide(
                        color: isDarkMode
                            ? _darkCardBorderColor.withOpacity(0.8)
                            : Colors.black45,
                      ),
                    ),
                    icon: const Icon(Icons.chat, size: 16),
                    label: Text('view_chat'.tr()),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChatPage(
                                    chatId: targetId,
                                    otherUserId: reportedUserId,
                                    selectedSkills: const [],
                                    mode: 'admin_view',
                                  )));
                    },
                  ),
                if (reporterId.isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accentColor,
                      side: BorderSide(
                        color: isDarkMode
                            ? _darkCardBorderColor.withOpacity(0.8)
                            : Colors.black45,
                      ),
                    ),
                    icon: const Icon(Icons.person, size: 16),
                    label: Text('reporter'.tr()),
                    onPressed: () => _viewProfile(context, reporterId),
                  ),
                if (!isFeedback &&
                    reportedUserId.isNotEmpty &&
                    reportedUserId != 'admin')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accentColor,
                      side: BorderSide(
                        color: isDarkMode
                            ? _darkCardBorderColor.withOpacity(0.8)
                            : Colors.black45,
                      ),
                    ),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: Text('reported_user'.tr()),
                    onPressed: () => _viewProfile(context, reportedUserId),
                  ),
                if (isFeedback)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accentColor,
                      side: BorderSide(
                        color: isDarkMode
                            ? _darkCardBorderColor.withOpacity(0.8)
                            : Colors.black45,
                      ),
                    ),
                    icon: const Icon(Icons.reply, size: 16),
                    label: Text('reply_user'.tr()),
                    onPressed: () =>
                        _replyToFeedback(context, reporterId, reason),
                  ),
              ],
            ),
            Divider(color: isDarkMode ? Colors.white30 : Colors.black26),
            if (status == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _updateReportStatus(reportId, 'rejected');
                    },
                    child: Text('reject_close'.tr(),
                        style: TextStyle(color: Colors.red)),
                  ),
                  if (!isFeedback)
                    ElevatedButton(
                      onPressed: () {
                        _showBanDialog(context, reportedUserId, reportId);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      child: Text('ban_user'.tr()),
                    ),
                  if (isFeedback)
                    ElevatedButton(
                      onPressed: () {
                        _updateReportStatus(reportId, 'resolved');
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: Text('mark_resolved'.tr()),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double topPadding = MediaQuery.of(context).padding.top +
        kToolbarHeight +
        kTextTabBarHeight +
        8;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            'reports_feedback'.tr(),
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          centerTitle: true,
          foregroundColor: isDarkMode ? Colors.white : Colors.black,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            labelColor: isDarkMode ? Colors.white : Colors.black,
            unselectedLabelColor: isDarkMode ? Colors.white60 : Colors.black54,
            indicatorColor: _accentColor,
            tabs: [
              Tab(text: 'user_report'.tr()),
              Tab(text: 'system_feedback'.tr()),
            ],
          ),
        ),
        body: Stack(
          children: [
            if (isDarkMode)
              Backgroundcolor()
            else
              Container(color: Theme.of(context).scaffoldBackgroundColor),
            Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'no_reports'.tr(),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    );
                  }

                  final reports = snapshot.data!.docs;
                  final userReports = reports
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['targetType'] !=
                          'feedback')
                      .toList();
                  final feedbacks = reports
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['targetType'] ==
                          'feedback')
                      .toList();

                  Map<String, List<DocumentSnapshot>> groupedFeedbacks = {};
                  for (var doc in feedbacks) {
                    final cat =
                        (doc.data() as Map<String, dynamic>)['category'] ??
                            'Other';
                    if (!groupedFeedbacks.containsKey(cat)) {
                      groupedFeedbacks[cat] = [];
                    }
                    groupedFeedbacks[cat]!.add(doc);
                  }

                  return TabBarView(
                    children: [
                      userReports.isEmpty
                          ? Center(
                              child: Text(
                                'no_user_reports'.tr(),
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 20),
                              itemCount: userReports.length,
                              itemBuilder: (context, index) => _buildReportCard(
                                  context, userReports[index], false),
                            ),
                      feedbacks.isEmpty
                          ? Center(
                              child: Text(
                                'no_system_feedback'.tr(),
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 20),
                              itemCount: groupedFeedbacks.keys.length,
                              itemBuilder: (context, index) {
                                final category =
                                    groupedFeedbacks.keys.elementAt(index);
                                final docs = groupedFeedbacks[category]!;
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? _darkCardColor
                                        : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: isDarkMode
                                        ? Border.all(
                                            color: _darkCardBorderColor
                                                .withOpacity(0.45),
                                          )
                                        : null,
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      initiallyExpanded: true,
                                      iconColor: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                      collapsedIconColor: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                      title: Text(
                                        '${'category'.tr()} $category',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${docs.length} ${'tickets'.tr()}',
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                      children: docs
                                          .map((doc) => _buildReportCard(
                                              context, doc, true))
                                          .toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
