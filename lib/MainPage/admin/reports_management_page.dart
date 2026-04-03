import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:skillswap/MainPage/search/userCard.dart';
import 'package:skillswap/MainPage/chat/chatPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class ReportsManagementPage extends StatelessWidget {
  const ReportsManagementPage({super.key});

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
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Scaffold(
                  appBar: AppBar(
                      title: const Text('User Profile View'),
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
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Ban User'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                      labelText: 'Reason for ban',
                      border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                SizedBox(height: 16),
                DropdownButton<String>(
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
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reason is required')));
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
                      const SnackBar(
                          content: Text('User banned and report resolved.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Ban'),
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
      shape: RoundedRectangleBorder(
        side: BorderSide(color: statusColor, width: 1.5),
        borderRadius: BorderRadius.circular(8),
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
                        ? 'Category: ${category ?? "General"}'
                        : 'Type: $targetType',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
              Text('Subcategory: $location',
                  style: const TextStyle(
                      fontSize: 13, fontStyle: FontStyle.italic)),
              SizedBox(height: 8),
            ],
            if (!isFeedback)
              Text('Reported User ID:\n$reportedUserId',
                  style: const TextStyle(fontSize: 12)),
            SizedBox(height: 4),
            Text('From User ID: $reporterId',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 12),
            const Text('Reason / Message:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(reason, style: const TextStyle(fontSize: 14)),
            SizedBox(height: 8),
            if (attachments != null && attachments.isNotEmpty) ...[
              const Text('Attachments:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
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
                        color: Colors.grey.shade300,
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
              SizedBox(height: 8),
            ],
            Text('Date: $dateStr',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            Wrap(
              spacing: 8,
              children: [
                if (!isFeedback && targetType == 'chat' && targetId != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('View Chat'),
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
                    icon: const Icon(Icons.person, size: 16),
                    label: const Text('Reporter'),
                    onPressed: () => _viewProfile(context, reporterId),
                  ),
                if (!isFeedback &&
                    reportedUserId.isNotEmpty &&
                    reportedUserId != 'admin')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text('Reported User'),
                    onPressed: () => _viewProfile(context, reportedUserId),
                  ),
                if (isFeedback)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text('Reply to User'),
                    onPressed: () =>
                        _replyToFeedback(context, reporterId, reason),
                  ),
              ],
            ),
            const Divider(),
            if (status == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _updateReportStatus(reportId, 'rejected');
                    },
                    child: const Text('Reject/Close',
                        style: TextStyle(color: Colors.red)),
                  ),
                  if (!isFeedback)
                    ElevatedButton(
                      onPressed: () {
                        _showBanDialog(context, reportedUserId, reportId);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      child: const Text('Ban User'),
                    ),
                  if (isFeedback)
                    ElevatedButton(
                      onPressed: () {
                        _updateReportStatus(reportId, 'resolved');
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text('Mark Resolved'),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports & Feedback'),
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.black,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: 'User Reports'),
              Tab(text: 'System Feedback'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No reports found.'));
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
                  (doc.data() as Map<String, dynamic>)['category'] ?? 'Other';
              if (!groupedFeedbacks.containsKey(cat)) {
                groupedFeedbacks[cat] = [];
              }
              groupedFeedbacks[cat]!.add(doc);
            }

            return TabBarView(
              children: [
                userReports.isEmpty
                    ? const Center(child: Text('No user reports'))
                    : ListView.builder(
                        itemCount: userReports.length,
                        itemBuilder: (context, index) => _buildReportCard(
                            context, userReports[index], false),
                      ),
                feedbacks.isEmpty
                    ? const Center(child: Text('No system feedback'))
                    : ListView.builder(
                        itemCount: groupedFeedbacks.keys.length,
                        itemBuilder: (context, index) {
                          final category =
                              groupedFeedbacks.keys.elementAt(index);
                          final docs = groupedFeedbacks[category]!;
                          return ExpansionTile(
                            initiallyExpanded: true,
                            title: Text('Category: $category',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text('${docs.length} tickets'),
                            children: docs
                                .map((doc) =>
                                    _buildReportCard(context, doc, true))
                                .toList(),
                          );
                        },
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}
