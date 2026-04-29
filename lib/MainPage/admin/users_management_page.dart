import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skillswap/background/backgroundColor.dart';
import 'package:easy_localization/easy_localization.dart';

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
                'change_role'.tr(),
                style:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
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
                  child: Text(
                    'cancel'.tr(),
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
                  child: Text(
                    'save'.tr(),
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

  void _showAddTimeDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) {
        int hoursToAdd = 1;
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDarkMode ? _darkCardColor : Colors.white,
              title: Text(
                'Add Time to $userName',
                style:
                    TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select hours to add (1 - 24):',
                    style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: _accentColor),
                        onPressed: hoursToAdd > 1
                            ? () => setState(() => hoursToAdd--)
                            : null,
                      ),
                      Text(
                        '$hoursToAdd h',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      IconButton(
                        icon:
                            Icon(Icons.add_circle_outline, color: _accentColor),
                        onPressed: hoursToAdd < 24
                            ? () => setState(() => hoursToAdd++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      // Atomically add time bounds
                      final userRef =
                          _firestore.collection('users').doc(userId);
                      await _firestore.runTransaction((transaction) async {
                        final snap = await transaction.get(userRef);
                        if (snap.exists) {
                          final data = snap.data()!;
                          int tBal =
                              data['timeBalance'] ?? data['balance'] ?? 0;

                          transaction.update(userRef, {
                            'timeBalance': tBal + (hoursToAdd * 60),
                            'balance': tBal + (hoursToAdd * 60),
                          });
                        }
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text("Successfully added $hoursToAdd hour(s)."),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Error: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Add Time',
                      style: TextStyle(color: _accentColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'user_management'.tr(),
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
                      'no_users_found'.tr(),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  );
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.only(
                      top: kToolbarHeight + 8, bottom: 20),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData =
                        users[index].data() as Map<String, dynamic>;
                    final userId = users[index].id;

                    final firstName = userData['firstName'] ?? 'No Name';
                    final lastName = userData['lastName'] ?? '';
                    final email = userData['email'] ?? 'No Email';
                    final role = userData['role'] ?? 'user';
                    final isBanned = userData['isBanned'] ?? false;
                    final photoUrl = userData['photoUrl'];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: isDarkMode
                          ? _darkCardColor
                          : Theme.of(context).cardColor,
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
                          backgroundColor: isDarkMode
                              ? const Color(0xFF122A66)
                              : Colors.grey.shade300,
                          backgroundImage:
                              photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? Icon(
                                  Icons.person,
                                  color:
                                      isDarkMode ? Colors.black : Colors.black,
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
                          '$email ${'role'.tr()} ${role.toUpperCase()}',
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
                              icon: const Icon(Icons.more_time,
                                  color: _accentColor),
                              tooltip: 'add_time_balance'.tr(),
                              onPressed: () => _showAddTimeDialog(
                                  userId, "$firstName $lastName"),
                            ),
                            IconButton(
                              icon: const Icon(Icons.manage_accounts,
                                  color: _accentColor),
                              tooltip: 'change_role'.tr(),
                              onPressed: () => _showRoleDialog(userId, role),
                            ),
                            IconButton(
                              icon: Icon(
                                isBanned ? Icons.lock : Icons.lock_open,
                                color: isBanned ? Colors.red : Colors.green,
                              ),
                              tooltip: isBanned
                                  ? 'unban_user'.tr()
                                  : 'ban_user'.tr(),
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
