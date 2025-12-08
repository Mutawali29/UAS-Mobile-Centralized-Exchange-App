import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../widgets/profile_menu_item.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/location_card.dart';
import '../utils/app_colors.dart';
import '../services/auth_service.dart';

import 'discover_screen.dart';
import 'activity_screen.dart';
import 'exchange_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentIndex = 4;
  final AuthService _authService = AuthService();

  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final currentUser = _authService.currentUser;

      if (currentUser == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Get user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _errorMessage = 'User data not found';
          _isLoading = false;
        });
        return;
      }

      final userData = userDoc.data()!;

      setState(() {
        _userProfile = UserProfile(
          id: currentUser.uid,
          name: userData['name'] ?? currentUser.displayName ?? 'User',
          email: userData['email'] ?? currentUser.email ?? '',
          phoneNumber: userData['phoneNumber'] ?? '',
          walletAddress: userData['walletAddress'] ?? 'Not generated',
          joinedDate: (userData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isVerified: userData['isVerified'] ?? false,
          currency: userData['currency'] ?? 'USD',
          language: userData['language'] ?? 'English',
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _isLoading = false;
      });
      print('Error loading user profile: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar('Error logging out: $e');
    }
  }

  Future<void> _updateUserPreferences({String? currency, String? language}) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      Map<String, dynamic> updates = {};
      if (currency != null) updates['currency'] = currency;
      if (language != null) updates['language'] = language;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(updates);

      // Reload profile
      await _loadUserProfile();
      _showSnackBar('Preferences updated successfully');
    } catch (e) {
      _showSnackBar('Error updating preferences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      _showSettingsBottomSheet();
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : _errorMessage != null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadUserProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
                  : SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Card
                    _buildProfileCard(),

                    const SizedBox(height: 24),

                    // Account Section
                    _buildSectionTitle('Account'),
                    _buildAccountMenuItems(),

                    const SizedBox(height: 24),

                    // Security Section
                    _buildSectionTitle('Security'),
                    _buildSecurityMenuItems(),

                    const SizedBox(height: 24),

                    // Support Section
                    _buildSectionTitle('Support'),
                    _buildSupportMenuItems(),

                    const SizedBox(height: 24),

                    // Danger Zone
                    _buildDangerMenuItems(),

                    const SizedBox(height: 20),

                    // App Version
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.pop(context);
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ActivityScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ExchangeScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const DiscoverScreen(),
              ),
            );
          } else if (index == 4) {
            // Already on Profile
          }
        },
      ),
    );
  }

  Widget _buildProfileCard() {
    if (_userProfile == null) return const SizedBox.shrink();

    // Get initials from name
    String getInitials(String name) {
      List<String> names = name.trim().split(' ');
      if (names.length >= 2) {
        return '${names[0][0]}${names[1][0]}'.toUpperCase();
      }
      return name.isNotEmpty ? name[0].toUpperCase() : 'U';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    getInitials(_userProfile!.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (_userProfile!.isVerified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cardBackground,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Name and Verification
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _userProfile!.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_userProfile!.isVerified) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Verified',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _userProfile!.email,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          // Wallet Address
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _userProfile!.walletAddress,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: _userProfile!.walletAddress),
                    );
                    _showSnackBar('Address copied to clipboard');
                  },
                  child: const Icon(
                    Icons.copy,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // GPS Location Card - MENGGUNAKAN WIDGET TERPISAH
          const LocationCard(),

          // Edit Profile Button
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _showEditProfileDialog();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountMenuItems() {
    final menuItems = [
      ProfileMenuItem(
        title: 'Personal Information',
        subtitle: 'Update your personal details',
        icon: Icons.person_outline,
        onTap: () {
          _showSnackBar('Personal Information tapped');
        },
      ),
      ProfileMenuItem(
        title: 'Payment Methods',
        subtitle: 'Manage your payment options',
        icon: Icons.payment,
        onTap: () {
          _showSnackBar('Payment Methods tapped');
        },
      ),
      ProfileMenuItem(
        title: 'Preferences',
        subtitle: 'Currency, Language, Notifications',
        icon: Icons.tune,
        onTap: () {
          _showPreferencesDialog();
        },
      ),
    ];

    return Column(
      children: menuItems
          .map((item) => ProfileMenuItemWidget(item: item))
          .toList(),
    );
  }

  Widget _buildSecurityMenuItems() {
    final menuItems = [
      ProfileMenuItem(
        title: 'Change Password',
        subtitle: 'Update your password',
        icon: Icons.lock_outline,
        onTap: () {
          _showSnackBar('Change Password tapped');
        },
      ),
      ProfileMenuItem(
        title: 'Two-Factor Authentication',
        subtitle: 'Enable 2FA for extra security',
        icon: Icons.security,
        onTap: () {
          _showSnackBar('2FA tapped');
        },
      ),
      ProfileMenuItem(
        title: 'Privacy',
        subtitle: 'Manage your privacy settings',
        icon: Icons.privacy_tip_outlined,
        onTap: () {
          _showSnackBar('Privacy tapped');
        },
      ),
    ];

    return Column(
      children: menuItems
          .map((item) => ProfileMenuItemWidget(item: item))
          .toList(),
    );
  }

  Widget _buildSupportMenuItems() {
    final menuItems = [
      ProfileMenuItem(
        title: 'Help Center',
        subtitle: 'Get help and support',
        icon: Icons.help_outline,
        onTap: () {
          _showSnackBar('Help Center tapped');
        },
      ),
      ProfileMenuItem(
        title: 'Terms & Conditions',
        subtitle: 'Read our terms',
        icon: Icons.description_outlined,
        onTap: () {
          _showSnackBar('Terms tapped');
        },
      ),
      ProfileMenuItem(
        title: 'About',
        subtitle: 'Learn more about our app',
        icon: Icons.info_outline,
        onTap: () {
          _showAboutDialog();
        },
      ),
    ];

    return Column(
      children: menuItems
          .map((item) => ProfileMenuItemWidget(item: item))
          .toList(),
    );
  }

  Widget _buildDangerMenuItems() {
    return ProfileMenuItemWidget(
      item: ProfileMenuItem(
        title: 'Log Out',
        subtitle: 'Sign out of your account',
        icon: Icons.logout,
        isDanger: true,
        onTap: () {
          _showLogoutDialog();
        },
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userProfile?.name);
    final phoneController = TextEditingController(text: _userProfile?.phoneNumber);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final currentUser = _authService.currentUser;
                if (currentUser != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .update({
                    'name': nameController.text,
                    'phoneNumber': phoneController.text,
                  });

                  await _authService.updateProfile(displayName: nameController.text);
                  await _loadUserProfile();

                  if (mounted) {
                    Navigator.pop(context);
                    _showSnackBar('Profile updated successfully');
                  }
                }
              } catch (e) {
                _showSnackBar('Error updating profile: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPreferencesDialog() {
    if (_userProfile == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Preferences',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPreferenceRow('Currency', _userProfile!.currency),
            const Divider(color: AppColors.textSecondary, height: 24),
            _buildPreferenceRow('Language', _userProfile!.language),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _buildSettingsItem(
                    'Notifications',
                    Icons.notifications_outlined,
                        () {
                      Navigator.pop(context);
                      _showSnackBar('Notifications settings');
                    },
                  ),
                  _buildSettingsItem(
                    'Dark Mode',
                    Icons.dark_mode_outlined,
                        () {
                      Navigator.pop(context);
                      _showSnackBar('Dark mode toggle');
                    },
                  ),
                  _buildSettingsItem(
                    'App Language',
                    Icons.language,
                        () {
                      Navigator.pop(context);
                      _showSnackBar('Language settings');
                    },
                  ),
                  _buildSettingsItem(
                    'Clear Cache',
                    Icons.cleaning_services_outlined,
                        () {
                      Navigator.pop(context);
                      _showSnackBar('Cache cleared');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'About',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crypto Wallet App',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'A secure and user-friendly cryptocurrency wallet application for managing your digital assets.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Log Out',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}