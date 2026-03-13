import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportsManagementPage extends StatelessWidget {
  const ReportsManagementPage({Key? key}) : super(key: key);

  void _updateReportStatus(String reportId, String status) {
    FirebaseFirestore.instance.collection('reports').doc(reportId).update({'status': status});
  }

  void _banUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'isBanned': true});
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
                      Text('Date: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
