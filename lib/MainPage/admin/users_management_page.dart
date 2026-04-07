import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skillswap/background/backgroundColor.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  _UsersManagementPageState createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Color _darkCardColor = Color(0xFF0F1F3B);
  static const Color _darkCardBorderColor = Color(0xFF2B4C85);
  static const Color _accentColor = Color(0xFF1E88E5);

  void _showRoleDialog(String userId, String currentRole) {
    showDialog(
      context: context,
      builder: (context) {
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        String selectedRole = currentRole;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDarkMode ? _darkCardColor : Colors.white,
              title: Text(
                'Change Role',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: ['user', 'moderator', 'admin'].map((role) {
                  return RadioListTile<String>(
                    activeColor: _accentColor,
                    title: Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: _accentColor),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await _firestore
                        .collection('users')
                        .doc(userId)
                        .update({'role': selectedRole});
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(color: _accentColor),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleBan(String userId, bool isCurrentlyBanned) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'isBanned': !isCurrentlyBanned});
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'User Management',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        centerTitle: true,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (isDarkMode)
            Backgroundcolor()
          else
            Container(color: Theme.of(context).scaffoldBackgroundColor),
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No users found.',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.only(top: kToolbarHeight + 8, bottom: 20),
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
                      color: isDarkMode ? _darkCardColor : Theme.of(context).cardColor,
                      shadowColor: isDarkMode
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.black.withOpacity(0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: isDarkMode
                            ? BorderSide(
                                color: _darkCardBorderColor.withOpacity(0.45),
                              )
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isDarkMode ? const Color(0xFF122A66) : Colors.grey.shade300,
                          backgroundImage:
                              photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? Icon(
                                  Icons.person,
                                  color: isDarkMode ? Colors.black : Colors.black,
                                )
                              : null,
                        ),
                        title: Text(
                          '$firstName $lastName',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '$email\nRole: ${role.toUpperCase()}',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.manage_accounts, color: _accentColor),
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
          ),
        ],
      ),
    );
  }
}
