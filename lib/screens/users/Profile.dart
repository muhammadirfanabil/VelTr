import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/profile/header.dart';
import '../../widgets/profile/quick_actions.dart';
import '../../widgets/profile/logout_section.dart';
import '../../widgets/common/error_card.dart';
import '../../widgets/common/confirmation_dialog.dart';
import '../../widgets/Common/loading_screen.dart';

import '../../models/action_items.dart';
import '../../utils/snackbar.dart';
import '../../constants/app_constants.dart';

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
  String _name = '';
  String _email = '';
  String _phoneNumber = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final userData = await _loadFromFirestore(user);

      if (mounted) {
        setState(() {
          _name = userData['name'] ?? user.displayName ?? 'No Name';
          _email = userData['email'] ?? user.email ?? 'No Email';
          _phoneNumber =
              userData['phoneNumber'] ?? user.phoneNumber ?? 'No Phone';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load profile data';
          _setFallbackUserData();
        });
        SnackbarUtils.showError(
          context,
          'Error loading profile: ${e.toString()}',
        );
      }
    }
  }

  Future<Map<String, String?>> _loadFromFirestore(User user) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('users_information')
            .doc(user.uid)
            .get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      return {
        'name': (data['name'] ?? '').toString().trim(),
        'email': (data['email'] ?? '').toString().trim(),
        'phoneNumber':
            (data['phone_number'] ?? data['phoneNumber'] ?? '')
                .toString()
                .trim(),
      };
    }

    return {};
  }

  void _setFallbackUserData() {
    final user = _auth.currentUser;
    if (user != null) {
      _name = user.displayName ?? 'No Name';
      _email = user.email ?? 'No Email';
      _phoneNumber = user.phoneNumber ?? 'No Phone';
    }
  }

  Future<void> _refreshProfile() async {
    await _loadUserData();
    if (mounted && _errorMessage == null) {
      SnackbarUtils.showSuccess(context, 'Profile refreshed successfully!');
    }
  }

  Future<void> _handleLogout() async {
    try {
      final shouldLogout = await ConfirmationDialog.show(
        context: context,
        title: 'Confirm Logout',
        content: 'Are you sure you want to sign out?',
        confirmText: 'Logout',
        cancelText: 'Cancel',
        confirmColor: Colors.red,
      );

      if (shouldLogout == true) {
        await _auth.signOut();
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppConstants.loginRoute, (route) => false);
        }
      }
    } catch (e) {
      SnackbarUtils.showError(context, 'Error during logout: ${e.toString()}');
    }
  }

  List<ActionItem> _getQuickActions() {
    return [
      const ActionItem(
        icon: Icons.map_outlined,
        title: 'Track Vehicle',
        subtitle: 'Monitor your vehicle location',
        route: AppConstants.trackVehicleRoute,
      ),
      const ActionItem(
        icon: Icons.directions_bike_outlined,
        title: 'My Vehicle',
        subtitle: 'Manage vehicle information',
        route: AppConstants.myVehicleRoute,
      ),
      const ActionItem(
        icon: Icons.radio_button_checked_outlined,
        title: 'Set Geofence',
        subtitle: 'Configure tracking range',
        route: AppConstants.setGeofence,
      ),
      const ActionItem(
        icon: Icons.history_outlined,
        title: 'Driving History',
        subtitle: 'View past journeys',
        route: AppConstants.driveHistoryRoute,
      ),
      const ActionItem(
        icon: Icons.security,
        title: 'Change Password',
        subtitle: 'Update your account password',
        route: AppConstants.changePasswordRoute,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Make scaffold transparent to show gradient
      appBar: _buildAppBar(theme, colorScheme),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: _buildBody(colorScheme),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: true, // Add this line
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed:
            () => Navigator.pushReplacementNamed(
              context,
              AppConstants.trackVehicleRoute,
            ),
      ),
      title: Text(
        'Profile',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshProfile,
          tooltip: 'Refresh Profile',
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed:
              () => Navigator.pushReplacementNamed(
                context,
                AppConstants.editProfileRoute,
              ),
          tooltip: 'Edit Profile',
        ),
      ],
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const LoadingScreen(message: 'Loading Profile...');
    }

    return RefreshIndicator(
      onRefresh: _refreshProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error Card (using extracted widget)
            if (_errorMessage != null) ...[
              ErrorCard(message: _errorMessage!, onRetry: _loadUserData),
              const SizedBox(height: 16),
            ],

            // Profile Header (using extracted widget)
            ProfileHeader(
              name: _name,
              email: _email,
              phoneNumber: _phoneNumber,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 24),

            // Quick Actions (using extracted widget)
            QuickActionsList(
              colorScheme: colorScheme,
              actions: _getQuickActions(),
            ),
            const SizedBox(height: 32),

            // Logout Section (using extracted widget)
            LogoutSection(onLogout: _handleLogout),
            const SizedBox(height: 24),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        AppConstants.appFooter,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
    );
  }
}
