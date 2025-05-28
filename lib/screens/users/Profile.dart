import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
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
