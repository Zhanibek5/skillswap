import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skillswap/loginPage/login_page.dart';
import 'package:intl/intl.dart';

class BannedPage extends StatelessWidget {
  final String? reason;
  final DateTime? expiration;

  const BannedPage({super.key, this.reason, this.expiration});

  @override
  Widget build(BuildContext context) {
    String expirationText = expiration != null
        ? "Until ${DateFormat('dd MMM yyyy, HH:mm').format(expiration!)}"
        : "Permanent";

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 80, color: Colors.red),
              SizedBox(height: 20),
              const Text(
                'Account Suspended',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              const Text(
                'Your account has been restricted by an administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              if (reason != null && reason!.isNotEmpty)
                Text(
                  'Reason: $reason',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.red),
                ),
              SizedBox(height: 8),
              Text(
                'Duration: $expirationText',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
