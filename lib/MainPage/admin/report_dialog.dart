import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportDialog {
  static void show(
      BuildContext context, String reportedUserId, String targetType,
      {String? targetId}) {
    showDialog(
      context: context,
      builder: (context) {
        return _ReportDialogContent(
          reportedUserId: reportedUserId,
          targetType: targetType,
          targetId: targetId,
        );
      },
    );
  }
}

class _ReportDialogContent extends StatefulWidget {
  final String reportedUserId;
  final String targetType;
  final String? targetId;

  const _ReportDialogContent({
    required this.reportedUserId,
    required this.targetType,
    this.targetId,
  });

  @override
  State<_ReportDialogContent> createState() => _ReportDialogContentState();
}

class _ReportDialogContentState extends State<_ReportDialogContent> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  void _submitReport() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for reporting.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) throw Exception("User not logged in");

      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': currentUserId,
        'reportedUserId': widget.reportedUserId,
        'targetType': widget.targetType,
        'targetId': widget.targetId,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Report submitted successfully. We will review it shortly.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'Please describe why you are reporting this user. False reports may result in a ban.'),
          SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Reason for report (spam, offensive language, etc.)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
