import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({Key? key}) : super(key: key);

  @override
  _UsersManagementPageState createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showRoleDialog(String userId, String currentRole) {
    showDialog(
      context: context,
      builder: (context) {
        String selectedRole = currentRole;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Role'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: ['user', 'moderator', 'admin'].map((role) {
                  return RadioListTile<String>(
                    title: Text(role.toUpperCase()),
                    value: role,
                    groupValue: selectedRole,
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value!;
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    await _firestore.collection('users').doc(userId).update({'role': selectedRole});
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleBan(String userId, bool isCurrentlyBanned) async {
    await _firestore.collection('users').doc(userId).update({'isBanned': !isCurrentlyBanned});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              
              final firstName = userData['firstName'] ?? 'No Name';
              final lastName = userData['lastName'] ?? '';
              final email = userData['email'] ?? 'No Email';
              final role = userData['role'] ?? 'user';
              final isBanned = userData['isBanned'] ?? false;
              final photoUrl = userData['photoUrl'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text('$firstName $lastName'),
                  subtitle: Text('$email\nRole: ${role.toUpperCase()}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.manage_accounts, color: Colors.blue),
                        tooltip: 'Change Role',
                        onPressed: () => _showRoleDialog(userId, role),
                      ),
                      IconButton(
                        icon: Icon(
                          isBanned ? Icons.lock : Icons.lock_open,
                          color: isBanned ? Colors.red : Colors.green,
                        ),
                        tooltip: isBanned ? 'Unban User' : 'Ban User',
                        onPressed: () => _toggleBan(userId, isBanned),
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
