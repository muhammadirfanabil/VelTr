import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

import '../../widgets/Common/confirmation_dialog.dart';
import '../../utils/snackbar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _hasChanges = false;
  String? _originalName;
  String? _originalEmail;
  String? _originalPhone;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupChangeListeners();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _setupChangeListeners() {
    _nameController.addListener(_checkForChanges);
    _emailController.addListener(_checkForChanges);
    _phoneController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    if (_originalName == null &&
        _originalEmail == null &&
        _originalPhone == null) {
      return;
    }
    final hasChanges =
        _nameController.text.trim() != (_originalName ?? '') ||
        _emailController.text.trim() != (_originalEmail ?? '') ||
        _phoneController.text.trim() != (_originalPhone ?? '');

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showError('No authenticated user found');
        return;
      }
      final doc =
          await FirebaseFirestore.instance
              .collection('users_information')
              .doc(user.uid)
              .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _setUserData(
          data['name'] ?? '',
          data['emailAddress'] ?? '',
          data['phoneNumber'] ?? data['phone_number'] ?? '',
        );
      } else {
        _setUserData(
          user.displayName ?? '',
          user.email ?? '',
          user.phoneNumber ?? '',
        );
      }
    } catch (e) {
      _showError('Error loading profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setUserData(String name, String email, String phone) {
    _originalName = name;
    _originalEmail = email;
    _originalPhone = phone;
    _nameController.text = name;
    _emailController.text = email;
    _phoneController.text = phone;
    setState(() {
      _hasChanges = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForChanges();
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found');
      final docRef = FirebaseFirestore.instance
          .collection('users_information')
          .doc(user.uid);
      final userData = {
        'name': _nameController.text.trim(),
        'emailAddress': _emailController.text.trim(),
        'phoneNumber':
            _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
        'phone_number':
            _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        await docRef.update(userData);
      } else {
        userData.addAll({
          'id': user.uid,
          'vehicleIds': <String>[],
          'created_at': FieldValue.serverTimestamp(),
        });
        await docRef.set(userData);
      }
      _setUserData(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _phoneController.text.trim(),
      );
      _showSuccess('Profile updated successfully!');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pushReplacementNamed('/profile');
      });
    } catch (e) {
      _showError('Failed to update profile: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    SnackbarUtils.showError(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    SnackbarUtils.showSuccess(context, message);
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldDiscard = await ConfirmationDialog.show(
      context: context,
      title: 'Discard changes?',
      content: 'You have unsaved changes. Are you sure you want to go back?',
      confirmText: 'Discard',
      cancelText: 'Cancel',
      confirmColor: AppColors.error,
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: _buildAppBar(theme),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isLoading ? _buildLoadingView(theme) : _buildForm(theme),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: AppColors.backgroundPrimary,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: AppColors.primaryBlue, size: 24),
        tooltip: "Cancel",
        onPressed: () async {
          if (!_hasChanges || await _onWillPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
      title: Text(
        'Edit Profile',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          fontSize: 21,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildLoadingView(ThemeData theme) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryBlue,
        strokeWidth: 2.2,
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 30),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // _buildProfilePictureSection(theme),
            const Divider(height: 1, color: AppColors.border, thickness: 0.5),
            _buildFormField(
              controller: _nameController,
              label: 'Name',
              icon: Icons.person_outline_rounded,
              isRequired: true,
              theme: theme,
            ),
            // _buildFormField(
            //   controller: _emailController,
            //   label: 'Email',
            //   icon: Icons.email_outlined,
            //   keyboardType: TextInputType.emailAddress,
            //   isRequired: true,
            //   theme: theme,
            // ),
            _buildFormField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              theme: theme,
            ),
            const SizedBox(height: 30),
            _buildSaveButton(theme),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  // Widget _buildProfilePictureSection(ThemeData theme) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(vertical: 32),
  //     alignment: Alignment.center,
  //     child: Column(
  //       children: [
  //         CircleAvatar(
  //           radius: 48,
  //           backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.13),
  //           child: Text(
  //             _nameController.text.isNotEmpty
  //                 ? _nameController.text[0].toUpperCase()
  //                 : '?',
  //             style: TextStyle(
  //               fontSize: 42,
  //               fontWeight: FontWeight.bold,
  //               color: AppColors.primaryBlue,
  //               letterSpacing: -2,
  //             ),
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         TextButton.icon(
  //           onPressed: () {
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               const SnackBar(content: Text('Photo upload coming soon!')),
  //             );
  //           },
  //           icon: Icon(
  //             Icons.camera_alt_rounded,
  //             color: AppColors.primaryBlue,
  //             size: 18,
  //           ),
  //           label: Text(
  //             'Change Profile Photo',
  //             style: TextStyle(
  //               color: AppColors.primaryBlue,
  //               fontWeight: FontWeight.w600,
  //               fontSize: 15.5,
  //             ),
  //           ),
  //           style: TextButton.styleFrom(
  //             foregroundColor: AppColors.primaryBlue,
  //             textStyle: theme.textTheme.labelLarge?.copyWith(
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 16.3,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 21),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          validator: (value) => _validateField(value, label, isRequired),
          autofillHints:
              label == 'Email'
                  ? [AutofillHints.email]
                  : label == 'Phone Number'
                  ? [AutofillHints.telephoneNumber]
                  : [AutofillHints.name],
        ),
      ),
    );
  }

  String? _validateField(String? value, String label, bool isRequired) {
    if (isRequired && (value == null || value.trim().isEmpty)) {
      return '$label is required';
    }
    if (label == 'Email' && value != null && value.isNotEmpty) {
      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailRegex.hasMatch(value.trim())) {
        return 'Please enter a valid email address';
      }
    }
    if (label == 'Phone Number' && value != null && value.isNotEmpty) {
      final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
      if (!phoneRegex.hasMatch(value.trim()) || value.trim().length < 10) {
        return 'Please enter a valid phone number';
      }
    }
    return null;
  }

  Widget _buildSaveButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: _isLoading ? null : _saveProfile,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
            disabledBackgroundColor: AppColors.border.withValues(alpha: 0.23),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Text('Save Changes'),
        ),
      ),
    );
  }
}
