import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:skillswap/MainPage/search/userCard.dart';
import 'package:skillswap/MainPage/chat/chatPage.dart';
import 'dart:io';

class ReportsManagementPage extends StatelessWidget {
  const ReportsManagementPage({Key? key}) : super(key: key);

  void _updateReportStatus(String reportId, String status) {
    FirebaseFirestore.instance.collection('reports').doc(reportId).update({'status': status});
  }

  void _banUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'isBanned': true});
  }

  void _viewProfile(BuildContext context, String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
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
                 appBar: AppBar(title: const Text('User Profile View'), leading: const CloseButton()),
                 body: SingleChildScrollView(
                   child: Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: UserCard(userId: userId, mode: 'learn', userData: doc.data()!),
                   ),
                 ),
               ),
            ),
          );
        }
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final reportDoc = reports[index];
              final data = reportDoc.data() as Map<String, dynamic>;
              final reportId = reportDoc.id;

              final reporterId = data['reporterId'] ?? '';
              final reportedUserId = data['reportedUserId'] ?? '';
              final reason = data['reason'] ?? 'No reason provided';
              final status = data['status'] ?? 'pending';
              final targetType = data['targetType'] ?? 'unknown';
              final targetId = data['targetId'];
              final List<dynamic>? attachments = data['attachments'] as List<dynamic>?;

              DateTime? date;
              if (data['createdAt'] != null) {
                date = (data['createdAt'] as Timestamp).toDate();
              }
              final dateStr = date != null ? DateFormat('dd MMM yyyy, HH:mm').format(date) : 'Unknown date';

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
                          Text('Type: $targetType', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Reported User ID:\n$reportedUserId', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('By User ID: $reporterId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 12),
                      const Text('Reason:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(reason, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),

                      if (attachments != null && attachments.isNotEmpty) ...[
                        const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: attachments.length,
                            itemBuilder: (context, idx) {
                              final path = attachments[idx].toString();
                              if (path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov')) {
                                return Container(
                                  width: 80, height: 80, margin: const EdgeInsets.only(right: 8),
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.videocam),
                                );
                              }
                              return Container(
                                width: 80, height: 80, margin: const EdgeInsets.only(right: 8),
                                child: Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.error)),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      Text('Date: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Divider(),

                      /// NEW ACTIONS: View Chat / View Profiles
                      Wrap(
                        spacing: 8,
                        children: [
                          if (targetType == 'chat' && targetId != null)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.chat, size: 16),
                              label: const Text('View Chat'),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    chatId: targetId,
                                    otherUserId: reportedUserId,
                                    selectedSkills: const [],
                                    mode: 'admin_view', // Avoid normal user logic
                                  )
                                ));
                              },
                            ),
                            
                          if (reporterId.isNotEmpty)
                             OutlinedButton.icon(
                              icon: const Icon(Icons.person, size: 16),
                              label: const Text('Reporter'),
                              onPressed: () => _viewProfile(context, reporterId),
                            ),
                          if (reportedUserId.isNotEmpty && reportedUserId != 'admin')
                             OutlinedButton.icon(
                              icon: const Icon(Icons.person_outline, size: 16),
                              label: const Text('Reported User'),
                              onPressed: () => _viewProfile(context, reportedUserId),
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
                              child: const Text('Reject Report', style: TextStyle(color: Colors.red)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _banUser(reportedUserId);
                                _updateReportStatus(reportId, 'resolved');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('User banned and report resolved.')),
                                );
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('Ban User & Resolve'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
