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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 1,
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.grey,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShaderMask(
                                      shaderCallback:
                                          (bounds) => const LinearGradient(
                                            colors: [
                                              Color(0xFF11468F),
                                              Color(0xFFDA1212),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(
                                            Rect.fromLTWH(
                                              0,
                                              0,
                                              bounds.width,
                                              bounds.height,
                                            ),
                                          ),
                                      child: const Text(
                                        'Username',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color:
                                              Colors
                                                  .white, // wajib: ShaderMask pakai warna putih sebagai base
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text('user@email.com'),
                                    const Text('083140249807'),
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
                                        colors: [
                                          Color(0xFF11468F),
                                          Color(0xFFDA1212),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ).createShader(
                                        Rect.fromLTWH(
                                          0,
                                          0,
                                          bounds.width,
                                          bounds.height,
                                        ),
                                      ),
                                  child: const Icon(
                                    Icons.edit,
                                    color:
                                        Colors
                                            .white, // warna dasar harus putih buat efek gradasi
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Vehicle Information',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade200,
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Take a Photo of Your Vehicle.'),
                                  Text('Just in case you didn’t remember it.'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Yamaha V-ixion 2011'),
                                  Text('DA 1030 TTV'),
                                ],
                              ),
                              Text('Motorcycle'),
                            ],
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
