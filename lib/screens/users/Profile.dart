import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/User/userInformation.dart';
import '../../services/User/UserService.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  bool _isLoading = true;
  userInformation? _userInfo;
  String _name = 'Profile';
  String _email = 'Profile';
  String _phoneNumber = '-';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _userService.loadUserData();

      if (mounted) {
        setState(() {
          _userInfo = userData['userInfo'];
          _name = userData['name'];
          _email = userData['email'];
          _phoneNumber = userData['phoneNumber'];
          _isLoading = userData['isLoading'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await _userService.refreshUserProfile();

      if (mounted) {
        setState(() {
          _userInfo = userData['userInfo'];
          _name = userData['name'];
          _email = userData['email'];
          _phoneNumber = userData['phoneNumber'];
          _isLoading = userData['isLoading'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile refreshed successfully!')),
        );
      }
    } catch (e) {
      print('Error refreshing profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error refreshing profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
        title: Text(
          'Profile',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed:
                () => Navigator.pushReplacementNamed(context, '/edit-profile'),
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadUserData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileHeader(colorScheme),
                      const SizedBox(height: 24),
                      _buildQuickActions(colorScheme),
                      const SizedBox(height: 32),
                      _buildLogoutSection(),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: colorScheme.primary,
              child: Text(
                _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.email_outlined, _email),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.phone_outlined, _phoneNumber),
          ],
        ),
        // title: const Text('Profile'),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     onPressed: _refreshProfile,
        //     tooltip: 'Refresh Profile',
        //   ),
        // ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(ColorScheme colorScheme) {
    final actions = [
      _ActionItem(
        icon: Icons.map_outlined,
        title: 'Track Vehicle',
        subtitle: 'Monitor your vehicle location',
        route: '/home',
      ),
      _ActionItem(
        icon: Icons.directions_bike_outlined,
        title: 'My Vehicle',
        subtitle: 'Manage vehicle information',
        route: '/vehicle',
      ),
      _ActionItem(
        icon: Icons.radio_button_checked_outlined,
        title: 'Set Range',
        subtitle: 'Configure tracking range',
        route: '/set-range',
      ),
      _ActionItem(
        icon: Icons.history_outlined,
        title: 'Driving History',
        subtitle: 'View past journeys',
        route: '/drive-history',
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...actions.map((action) => _buildActionTile(action, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildActionTile(_ActionItem action, ColorScheme colorScheme) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(action.icon, color: colorScheme.primary, size: 20),
      ),
      title: Text(
        action.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(action.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, action.route),
    );
  }

  Widget _buildLogoutSection() {
    return Card(
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.logout, color: Colors.red, size: 20),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
        ),
        subtitle: const Text('Sign out of your account'),
        // onTap: _handleLogout,
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        '© Poliban 2025',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}
