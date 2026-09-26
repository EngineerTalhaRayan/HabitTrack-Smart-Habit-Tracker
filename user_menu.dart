import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:iconly/iconly.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:user_app/screens/common/common_login.dart';
import 'package:user_app/widgets/common/widget_toast.dart';
import 'package:user_app/widgets/user/widget_user_delete_account.dart';
import 'package:user_app/widgets/user/widget_user_logout.dart';
import 'package:user_app/constants/app_border_radius.dart';
import 'package:user_app/constants/app_colors.dart';
import 'package:user_app/constants/app_fonts.dart';
import 'package:user_app/utils/utils_sound.dart';
import 'package:user_app/constants/app_sounds.dart';
import 'package:user_app/constants/app_storage_names.dart';
import 'package:user_app/languages/core/extention.dart';
import 'package:user_app/providers/language_provider.dart';
import 'package:user_app/screens/user/total_spending.dart';
import 'package:user_app/services/user_server.dart';
import 'package:user_app/screens/user/user_history.dart';
import 'package:user_app/screens/user/user_nots.dart';
import 'package:user_app/screens/user/user_privicy.dart';
import 'package:user_app/screens/user/user_settings.dart';
import 'package:user_app/screens/user/user_suppott.dart';
import 'package:user_app/screens/user/user_terms.dart';
import 'package:user_app/screens/user/user_notifications.dart';
import 'package:user_app/utils/utils_internet.dart';
import 'package:user_app/utils/utils_navigator.dart';
import 'package:user_app/utils/utils_storage.dart';
import 'package:provider/provider.dart';
import 'package:user_app/widgets/common/widget_divider.dart';
import 'package:user_app/utils/utils_image.dart';

class UserMenu extends StatefulWidget {
  const UserMenu({super.key});

  @override
  State<UserMenu> createState() => _UserMenuState();
}

class _UserMenuState extends State<UserMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final UserServer _userServer = UserServer();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLoading = false;
  //----------------------------------------------------------------------------
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
  }

  //----------------------------------------------------------------------------
  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  //----------------------------------------------------------------------------
  Future<void> _handleLogout() async {
    WidgetUserLogout.show(context, onLogoutConfirmed: _performLogout);
  }

  //----------------------------------------------------------------------------
  Future<void> _performLogout() async {
    if (await UtilsInternet.isConnect()) {
      setState(() => _isLoading = true);
      await _userServer.logout();
      UtilsStorage.clearAll();
      final service = FlutterBackgroundService();
      service.invoke('stopUserService');
      if (!mounted) return;

      UtilsSound.playSound(AppSounds.notification, _audioPlayer);
      WidgetToast.showSuccess(context, 'logged_out_successfully'.tr(context));
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        UtilsNavigator.goWidgetNoBack(
          context,
          const CommonLogin(initialType: LoginType.user),
        );
      }
    } else {
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
      if (!mounted) return;
      WidgetToast.showError(context, 'no_internet_connection'.tr(context));
    }
  }

  //----------------------------------------------------------------------------
  Future<void> _handleDeleteAccount() async {
    WidgetUserDeleteAccount.show(
      context,
      onDeleteConfirmed: _performDeleteAccount,
    );
  }

  //----------------------------------------------------------------------------
  Future<void> _performDeleteAccount() async {
    if (await UtilsInternet.isConnect()) {
      try {
        setState(() => _isLoading = true);
        final response = await _userServer.deleteAccount();

        if (!mounted) return;

        if (response != null && response.data['status'] == true) {
          UtilsStorage.clearAll();
          final service = FlutterBackgroundService();
          service.invoke('stopUserService');
          UtilsSound.playSound(AppSounds.notification, _audioPlayer);
          WidgetToast.showSuccess(
            context,
            'account_deleted_success'.tr(context),
          );
          await Future.delayed(const Duration(seconds: 1));

          if (mounted) {
            UtilsNavigator.goWidgetNoBack(
              context,
              const CommonLogin(initialType: LoginType.user),
            );
          }
        } else {
          setState(() => _isLoading = false);
          UtilsSound.playSound(AppSounds.error, _audioPlayer);
          WidgetToast.showError(context, 'error'.tr(context));
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        WidgetToast.showError(context, 'network_error_occurred'.tr(context));
      }
    } else {
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
      if (!mounted) return;
      WidgetToast.showError(context, 'no_internet_connection'.tr(context));
    }
  }

  //----------------------------------------------------------------------------
  List<InlineSpan> _buildTextSpans(String text) {
    final List<InlineSpan> spans = [];
    final RegExp englishRegex = RegExp(r'[a-zA-Z]+');

    text.splitMapJoin(
      englishRegex,
      onMatch: (Match match) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: const TextStyle(
              fontSize: 22,
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
              fontFamily: AppFonts.openSans,
              letterSpacing: -0.5,
            ),
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(
          TextSpan(
            text: nonMatch,
            style: const TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 22,
              fontFamily: AppFonts.cairo,
              letterSpacing: -0.5,
            ),
          ),
        );
        return '';
      },
    );
    return spans;
  }
  //----------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final currentLanguage = Provider.of<LanguageProvider>(
      context,
    ).currentLocale.languageCode;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 50),
                    _buildProfileHeader(),
                    const SizedBox(height: 15),

                    WidgetDivider(title: 'language'.tr(context)),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLanguageButton(
                            title: 'English',
                            languageCode: 'en',
                            currentLanguage: currentLanguage,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildLanguageButton(
                            title: 'العربية',
                            languageCode: 'ar',
                            currentLanguage: currentLanguage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    WidgetDivider(title: 'activity'.tr(context)),
                    const SizedBox(height: 15),
                    _buildMenuItem(
                      IconlyLight.chart,
                      'total_spending',
                      () => UtilsNavigator.go(context, const TotalSpending()),
                      currentLanguage: currentLanguage,
                    ),
                    _buildMenuItem(
                      IconlyLight.time_circle,
                      'history',
                      () => UtilsNavigator.go(context, const UserHistory()),
                      currentLanguage: currentLanguage,
                    ),
                    const SizedBox(height: 5),

                    WidgetDivider(
                      title: 'communication_and_support'.tr(context),
                    ),
                    const SizedBox(height: 15),
                    _buildMenuItem(
                      IconlyLight.notification,
                      'notifications',
                      () =>
                          UtilsNavigator.go(context, const UserNotifications()),
                      currentLanguage: currentLanguage,
                    ),
                    _buildMenuItem(
                      IconlyLight.message,
                      'contact_support',
                      () => UtilsNavigator.go(context, const UserSupport()),
                      currentLanguage: currentLanguage,
                    ),
                    _buildMenuItem(
                      IconlyLight.paper,
                      'feedback',
                      () => UtilsNavigator.go(context, const UserNots()),
                      currentLanguage: currentLanguage,
                    ),
                    _buildMenuItem(
                      IconlyLight.lock,
                      'privacy_policy',
                      () => UtilsNavigator.go(context, const UserPrivacy()),
                      currentLanguage: currentLanguage,
                    ),
                    _buildMenuItem(
                      IconlyLight.document,
                      'terms_of_service',
                      () => UtilsNavigator.go(context, const UserTerms()),
                      currentLanguage: currentLanguage,
                    ),
                    const SizedBox(height: 5),

                    WidgetDivider(title: 'account_settings'.tr(context)),
                    const SizedBox(height: 15),
                    _buildMenuItem(
                      IconlyLight.setting,
                      'settings',
                      () => UtilsNavigator.go(context, const UserSettings()),
                      currentLanguage: currentLanguage,
                    ),
                    _buildMenuItem(
                      IconlyLight.logout,
                      'logout',
                      _handleLogout,
                      isDestructive: true,
                      currentLanguage: currentLanguage,
                    ),
                    _buildMenuItem(
                      IconlyLight.delete,
                      'delete_account',
                      _handleDeleteAccount,
                      isDestructive: true,
                      currentLanguage: currentLanguage,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildProfileHeader() {
    final userName =
        UtilsStorage.readString(AppStorageNames.userName) ?? 'User Profile';
    final userEmail =
        UtilsStorage.readString(AppStorageNames.userEmail) ?? 'User Account';

    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: UtilsImage.getUserProfileImageUrl(),
                    httpHeaders: {
                      'Authorization':
                          'Bearer ${UtilsStorage.readString(AppStorageNames.userToken)}',
                    },
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      IconlyLight.profile,
                      size: 34,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(children: _buildTextSpans(userName)),
        ),
        Text(
          userEmail.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            overflow: TextOverflow.ellipsis,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildLanguageButton({
    required String title,
    required String languageCode,
    required String currentLanguage,
  }) {
    final isSelected = currentLanguage == languageCode;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          Provider.of<LanguageProvider>(
            context,
            listen: false,
          ).changeLanguage(languageCode);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.border.withOpacity(0.4),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textMain,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildMenuItem(
    IconData icon,
    String titleKey,
    VoidCallback onTap, {
    bool isDestructive = false,
    required String currentLanguage,
  }) {
    Color mainColor = isDestructive ? Colors.red : AppColors.primary;
    Color textColor = isDestructive ? Colors.red : AppColors.textMain;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
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
                color: mainColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: mainColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                titleKey.tr(context),
                style: TextStyle(
                  color: textColor,
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
}
