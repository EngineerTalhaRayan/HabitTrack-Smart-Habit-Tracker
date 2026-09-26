import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:user_app/widgets/common/widget_back_appbar.dart';
import 'package:user_app/widgets/common/widget_divider.dart';
import 'package:user_app/widgets/common/widget_global_headline.dart';
import 'package:user_app/widgets/common/widget_image_top_header.dart';
import 'package:user_app/widgets/common/widget_toast.dart';
import 'package:user_app/widgets/user/widget_user_update_city.dart';
import 'package:user_app/widgets/user/widget_user_update_password.dart';
import 'package:user_app/widgets/user/widget_user_update_email.dart';
import 'package:user_app/widgets/user/widget_user_update_user_profile.dart';
import 'package:user_app/widgets/user/widget_user_update_name.dart';
import 'package:user_app/constants/app_border_radius.dart';
import 'package:user_app/constants/app_colors.dart';
import 'package:user_app/utils/utils_sound.dart';
import 'package:user_app/constants/app_sounds.dart';
import 'package:user_app/languages/core/extention.dart';
import 'package:user_app/services/user_server.dart';
import 'package:user_app/providers/language_provider.dart';
import 'package:user_app/utils/utils_navigator.dart';
import 'package:user_app/utils/utils_storage.dart';
import 'package:user_app/constants/app_storage_names.dart';
import 'package:user_app/utils/utils_image.dart';

class UserSettings extends StatefulWidget {
  const UserSettings({super.key});

  @override
  State<UserSettings> createState() => _UserSettingsState();
}

class _UserSettingsState extends State<UserSettings>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final UserServer _server = UserServer();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _notificationsEnabled = true;
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _controller.forward();

    _fetchNotificationStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  //----------------------------------------------------------------------------
  Future<void> _fetchNotificationStatus() async {
    setState(() => _isLoadingProfile = true);
    try {
      final response = await _server.getProfile();
      if (mounted &&
          response != null &&
          response.statusCode == 200 &&
          response.data['status'] == true) {
        final user = response.data['user'];
        final enabled = user['notifications_enabled'] ?? true;
        setState(() {
          _notificationsEnabled = enabled;
        });
      } else {
        final saved = UtilsStorage.readBool(
          AppStorageNames.userNotificationsEnabled,
        );
        if (saved != null) {
          setState(() {
            _notificationsEnabled = saved;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching notification status: $e");
      final saved = UtilsStorage.readBool(
        AppStorageNames.userNotificationsEnabled,
      );
      if (saved != null) {
        setState(() {
          _notificationsEnabled = saved;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  //----------------------------------------------------------------------------
  Future<void> _updateProfileImage(File image) async {
    final response = await _server.updateProfilePic(image);
    if (mounted) {
      if (response != null && response.statusCode == 200) {
        UtilsImage.refreshUserImage();
        UtilsSound.playSound(AppSounds.notification, _audioPlayer);
        WidgetToast.showSuccess(
          context,
          'updated_success_profile_image'.tr(context),
        );
        UtilsNavigator.back(context);
      } else {
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        final errorMsg = response?.data?['message']?.toString();
        WidgetToast.showError(
          context,
          errorMsg != null
              ? errorMsg.tr(context)
              : 'error_updating'.tr(context),
        );
      }
    }
  }

  //----------------------------------------------------------------------------
  Future<void> _updateName(String newName) async {
    final response = await _server.updateUserField('name', newName);
    if (mounted) {
      if (response != null &&
          response.statusCode == 200 &&
          response.data['status'] == true) {
        UtilsStorage.saveString(AppStorageNames.userName, newName);
        UtilsSound.playSound(AppSounds.notification, _audioPlayer);
        WidgetToast.showSuccess(context, 'updated_success'.tr(context));
        UtilsNavigator.back(context);
      } else {
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        final errorMsg = response?.data?['message']?.toString();
        WidgetToast.showError(
          context,
          errorMsg != null
              ? errorMsg.tr(context)
              : 'error_updating'.tr(context),
        );
      }
    }
  }

  //----------------------------------------------------------------------------
  Future<void> _updateCity(String newCity) async {
    final response = await _server.updateCity(newCity);
    if (mounted) {
      if (response != null && response.statusCode == 200) {
        UtilsStorage.saveString(AppStorageNames.userState, newCity);
        UtilsSound.playSound(AppSounds.notification, _audioPlayer);
        WidgetToast.showSuccess(context, 'updated_success'.tr(context));
        UtilsNavigator.back(context);
      } else {
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        final errorMsg = response?.data?['message']?.toString();
        WidgetToast.showError(
          context,
          errorMsg != null
              ? errorMsg.tr(context)
              : 'error_updating'.tr(context),
        );
      }
    }
  }

  //----------------------------------------------------------------------------
  Future<void> _updateEmail(String newEmail) async {
    final response = await _server.updateEmail(newEmail);
    if (mounted) {
      if (response != null && response.statusCode == 200) {
        UtilsStorage.saveString(AppStorageNames.userEmail, newEmail);
        UtilsSound.playSound(AppSounds.notification, _audioPlayer);
        WidgetToast.showSuccess(context, 'updated_success'.tr(context));
        UtilsNavigator.back(context);
      } else {
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        final errorMsg = response?.data?['message']?.toString();
        WidgetToast.showError(
          context,
          errorMsg != null
              ? errorMsg.tr(context)
              : 'error_updating'.tr(context),
        );
      }
    }
  }

  //----------------------------------------------------------------------------
  Future<void> _updatePassword(String oldPass, String newPass) async {
    final response = await _server.updatePassword(oldPass, newPass);
    if (mounted) {
      if (response != null && response.statusCode == 200) {
        UtilsSound.playSound(AppSounds.notification, _audioPlayer);
        WidgetToast.showSuccess(context, 'updated_success'.tr(context));
        UtilsNavigator.back(context);
      } else {
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        final errorMsg = response?.data?['message']?.toString();
        WidgetToast.showError(
          context,
          errorMsg != null
              ? errorMsg.tr(context)
              : 'error_updating'.tr(context),
        );
      }
    }
  }

  //----------------------------------------------------------------------------
  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    UtilsStorage.saveBool(AppStorageNames.userNotificationsEnabled, value);
    final response = await _server.toggleNotifications(value);
    if (response == null || response.statusCode != 200) {
      if (mounted) {
        setState(() => _notificationsEnabled = !value);
        UtilsStorage.saveBool(AppStorageNames.userNotificationsEnabled, !value);
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        final errorMsg = response?.data?['message']?.toString();
        WidgetToast.showError(
          context,
          errorMsg != null
              ? errorMsg.tr(context)
              : 'error_updating'.tr(context),
        );
      }
    }
  }

  //----------------------------------------------------------------------------
  Widget _buildMenuItem({
    required IconData icon,
    required String titleKey,
    required VoidCallback onTap,
    required String currentLanguage,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.small),
          border: Border.all(
            color: AppColors.border.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                titleKey.tr(context),
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              currentLanguage == 'ar'
                  ? IconlyLight.arrow_left_2
                  : IconlyLight.arrow_right_2,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final currentLanguage = Provider.of<LanguageProvider>(
      context,
    ).currentLocale.languageCode;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: WidgetBackAppbar(
        title: "edit_account_data".tr(context),
        currentLanguage: currentLanguage,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WidgetImageTopHeader(icon: IconlyLight.setting),
                const SizedBox(height: 10),
                WidgetGlobalHeadline(text: 'settings'.tr(context)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'seetings_dec'.tr(context),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                WidgetDivider(title: 'account_settings'.tr(context)),
                const SizedBox(height: 15),
                _buildMenuItem(
                  icon: IconlyLight.image,
                  titleKey: 'update_profile_pic',
                  onTap: () {
                    WidgetUpdateImageProfile.show(
                      context,
                      onUpdate: _updateProfileImage,
                    );
                  },
                  currentLanguage: currentLanguage,
                ),
                _buildMenuItem(
                  icon: IconlyLight.profile,
                  titleKey: 'update_name',
                  onTap: () {
                    WidgetUserUpdateName.show(context, onUpdate: _updateName);
                  },
                  currentLanguage: currentLanguage,
                ),
                _buildMenuItem(
                  icon: IconlyLight.location,
                  titleKey: 'change_city',
                  onTap: () {
                    WidgetUserUpdateCity.show(context, onUpdate: _updateCity);
                  },
                  currentLanguage: currentLanguage,
                ),
                _buildMenuItem(
                  icon: IconlyLight.message,
                  titleKey: 'update_email',
                  onTap: () {
                    WidgetUserUpdateEmail.show(context, onUpdate: _updateEmail);
                  },
                  currentLanguage: currentLanguage,
                ),
                _buildMenuItem(
                  icon: IconlyLight.lock,
                  titleKey: 'update_password',
                  onTap: () {
                    WidgetUserUpdatePassword.show(
                      context,
                      onUpdate: _updatePassword,
                    );
                  },
                  currentLanguage: currentLanguage,
                ),
                const SizedBox(height: 10),
                WidgetDivider(title: 'notifications'.tr(context)),
                const SizedBox(height: 15),
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                    border: Border.all(
                      color: AppColors.border.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          IconlyLight.notification,
                          size: 22,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'push_notifications'.tr(context),
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _isLoadingProfile
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Switch(
                              value: _notificationsEnabled,
                              activeColor: AppColors.primary,
                              onChanged: _toggleNotifications,
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
