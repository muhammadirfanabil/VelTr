import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

      // Try to load from Firestore first
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
          data['phone_number'] ?? '',
        );
      } else {
        // Fallback to Firebase Auth data
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

    _hasChanges = false;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final docRef = FirebaseFirestore.instance
          .collection('users_information')
          .doc(user.uid);

      final userData = {
        'name': _nameController.text.trim(),
        'emailAddress': _emailController.text.trim(),
        'phone_number':
            _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Check if document exists
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // Update existing document
        await docRef.update(userData);
      } else {
        // Create new document
        userData.addAll({
          'id': user.uid,
          'vehicleIds': <String>[],
          'created_at': FieldValue.serverTimestamp(),
        });
        await docRef.set(userData);
      }

      // Update original values to reflect saved state
      _setUserData(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _phoneController.text.trim(),
      );

      _showSuccess('Profile updated successfully!');

      // Navigate back after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      _showError('Failed to update profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
              'You have unsaved changes. Are you sure you want to go back?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Discard'),
              ),
            ],
          ),
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
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
        appBar: _buildAppBar(),
        body: _isLoading ? _buildLoadingView() : _buildForm(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);

    return AppBar(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () async {
          if (!_hasChanges || await _onWillPop()) {
            Navigator.of(context).pop();
          }
        },
      ),
      title: Text(
        'Edit Profile',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: (_isLoading || !_hasChanges) ? null : _saveProfile,
          child: Text(
            'Save',
            style: TextStyle(
              color:
                  (_isLoading || !_hasChanges)
                      ? Colors.grey
                      : theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildProfilePictureSection(),
            const Divider(height: 1),
            _buildFormField(
              controller: _nameController,
              label: 'Name',
              icon: Icons.person_outline,
              isRequired: true,
            ),
            _buildFormField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              isRequired: true,
            ),
            _buildFormField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 32),
            _buildSaveButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              _nameController.text.isNotEmpty
                  ? _nameController.text[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Photo upload coming soon!')),
              );
            },
            child: Text(
              'Change Profile Photo',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
            prefixIcon: Icon(icon, color: Colors.grey[600], size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
          ),
          validator: (value) => _validateField(value, label, isRequired),
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

  Widget _buildSaveButton() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: (_isLoading || !_hasChanges) ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child:
              _isLoading
                  ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                  : const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
        ),
      ),
    );
  }
}
