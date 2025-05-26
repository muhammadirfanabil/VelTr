import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth/authService.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String _userName = 'Loading...';
  String _userEmail = '';
  String _userPhone = '';
  String _userId = '';
  DateTime? _userCreatedAt;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _userName = 'Not logged in';
        });
        return;
      }

      _userId = currentUser.uid;
      _userEmail = currentUser.email ?? '';

      // Get user information from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('user_information')
          .doc(_userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        setState(() {
          _userName = userData['name'] ?? 'No Name';
          _userPhone = userData['phone_number'] ?? '-';
          _userCreatedAt = userData['created_at'] != null
              ? (userData['created_at'] as Timestamp).toDate()
              : null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = 'User data not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _userName = 'Error loading data';
        _isLoading = false;
      });
      print('Error loading user data: $e');
    }
  }

  String _formatJoinDate() {
    if (_userCreatedAt == null) return 'Unknown join date';
    
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return 'Joined ${_userCreatedAt!.day} ${months[_userCreatedAt!.month - 1]} ${_userCreatedAt!.year}';
  }
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        toolbarHeight: 120,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Username',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    'user@email.com',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Text(
                    '083140249807',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                // handle edit
              },
              icon: ShaderMask(
                shaderCallback:
                    (bounds) => const LinearGradient(
                      colors: [Color(0xFF11468F), Color(0xFFDA1212)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                child: const Icon(Icons.edit, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Profile Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'ID: user_1',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 32),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/vehicle');
                              },
                              icon: const Icon(Icons.directions_bike),
                              label: const Text('Vehicle Information'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF11468F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Joined 7 Aug 2025',
                              style: TextStyle(color: Colors.black45),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/home');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            minimumSize: const Size.fromHeight(
                              48,
                            ), // tinggi 48px, full width
                            alignment: Alignment.center,
                          ),
                          child: const Text('Track Your Vehicle'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/set-range');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            minimumSize: const Size.fromHeight(48),
                            alignment: Alignment.center,
                          ),
                          child: const Text('Set Range'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/history');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black),
                            minimumSize: const Size.fromHeight(
                              48,
                            ), // tinggi 48px, full width
                            alignment: Alignment.center,
                          ),
                          child: const Text('Driving History'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            // handle log out
                          },
                          child: const Text(
                            'Log Out',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0, top: 12.0),
              child: Text(
                '© Poliban 2025',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
