import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skillswap/background/backgroundColor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String searchText = "";

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
      backgroundColor: Colors.transparent,
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
          isDarkMode
              ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.35, 0.7, 1.0],
                      colors: [
                        Color(0xFF0A1734),
                        Color(0xFF0E214A),
                        Color(0xFF122A66),
                        Color(0xFF0D1B3E),
                      ],
                    ),
                  ),
                )
              : Container(
                  color: Colors.white,
                ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? _darkCardColor
                          : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => searchText = value.toLowerCase()),
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Search by name, surname or email',
                        hintStyle: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.grey),
                        prefixIcon: Icon(Icons.search,
                            color: isDarkMode ? Colors.white70 : Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ),
                ),
                Expanded(
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
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        );
                      }

                      var users = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final fname =
                            (data['firstName'] ?? '').toString().toLowerCase();
                        final lname =
                            (data['lastName'] ?? '').toString().toLowerCase();
                        final email =
                            (data['email'] ?? '').toString().toLowerCase();
                        return fname.contains(searchText) ||
                            lname.contains(searchText) ||
                            email.contains(searchText);
                      }).toList();

                      if (users.isEmpty) {
                        return Center(
                          child: Text(
                            'no_users_found'.tr(),
                            style: TextStyle(
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final userData =
                              users[index].data() as Map<String, dynamic>;
                          final userId = users[index].id;

                          final firstName =
                              userData['firstName']?.toString().trim() ?? '';
                          final lastName =
                              userData['lastName']?.toString().trim() ?? '';
                          final fullName = [firstName, lastName]
                              .where((s) => s.isNotEmpty)
                              .join(' ');
                          final displayName =
                              fullName.isNotEmpty ? fullName : 'No Name';

                          final email = userData['email']?.toString() ?? '';
                          final role = userData['role']?.toString() ?? 'user';
                          final isBanned = userData['isBanned'] ?? false;
                          final photoUrl =
                              userData['photoUrl']?.toString() ?? '';

                          Color roleColor;
                          if (role.toLowerCase() == 'admin') {
                            roleColor = Colors.green.shade600;
                          } else if (role.toLowerCase() == 'moderator') {
                            roleColor = Colors.red.shade600;
                          } else {
                            roleColor = Colors.grey.shade600;
                          }

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            color:
                                isDarkMode ? Colors.transparent : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isDarkMode
                                    ? const Color(0xFF2B4C85)
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDarkMode
                                            ? const Color(0xFF2B4C85)
                                            : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 35,
                                      backgroundColor: isDarkMode
                                          ? Colors.grey[800]
                                          : Colors.grey[200],
                                      backgroundImage: photoUrl.isNotEmpty
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: photoUrl.isEmpty
                                          ? Icon(Icons.person,
                                              size: 35,
                                              color: isDarkMode
                                                  ? Colors.white70
                                                  : Colors.grey[400])
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: GoogleFonts.roboto(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w700,
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (email.isNotEmpty && email != 'null')
                                          Row(
                                            children: [
                                              Text(
                                                '@ ',
                                                style: GoogleFonts.roboto(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDarkMode
                                                      ? Colors.blue.shade300
                                                      : Colors.blue.shade700,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  email,
                                                  style: GoogleFonts.roboto(
                                                    fontSize: 14,
                                                    color: isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: roleColor,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                role.toUpperCase(),
                                                style: GoogleFonts.roboto(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: BoxConstraints(),
                                                  icon: const Icon(
                                                      Icons.more_time,
                                                      size: 18,
                                                      color: _accentColor),
                                                  tooltip:
                                                      'add_time_balance'.tr(),
                                                  onPressed: () =>
                                                      _showAddTimeDialog(
                                                          userId, displayName),
                                                ),
                                                const SizedBox(width: 5),
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: BoxConstraints(),
                                                  icon: const Icon(
                                                      Icons.manage_accounts,
                                                      size: 18,
                                                      color: _accentColor),
                                                  tooltip: 'change_role'.tr(),
                                                  onPressed: () =>
                                                      _showRoleDialog(
                                                          userId, role),
                                                ),
                                                const SizedBox(width: 5),
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: BoxConstraints(),
                                                  icon: Icon(
                                                    isBanned
                                                        ? Icons.lock
                                                        : Icons.lock_open,
                                                    size: 18,
                                                    color: isBanned
                                                        ? Colors.red
                                                        : Colors.green,
                                                  ),
                                                  tooltip: isBanned
                                                      ? 'unban_user'.tr()
                                                      : 'ban_user'.tr(),
                                                  onPressed: () => _toggleBan(
                                                      userId, isBanned),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
          ),
        ],
      ),
    );
  }
}
