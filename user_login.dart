import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:user_app/screens/user/user_forgot_password.dart';
import 'package:user_app/screens/user/user_register.dart';
import 'package:user_app/services/user_background_service.dart';
import 'package:user_app/widgets/common/widget_or_divider.dart';
import 'package:user_app/widgets/common/widget_divider.dart';
import 'package:user_app/widgets/common/widget_primary_button.dart';
import 'package:user_app/utils/utils_sound.dart';
import 'package:user_app/constants/app_images.dart';
import 'package:user_app/constants/app_sounds.dart';
import 'package:user_app/constants/app_storage_names.dart';
import 'package:user_app/languages/core/extention.dart';
import 'package:user_app/screens/user/user_home.dart';
import 'package:user_app/services/user_server.dart';
import 'package:user_app/utils/utils_internet.dart';
import 'package:user_app/utils/utils_navigator.dart';
import 'package:user_app/utils/utils_storage.dart';
import 'package:user_app/widgets/common/widget_primary_textfield.dart';
import 'package:user_app/widgets/common/widget_toast.dart';

class UserLogin extends StatefulWidget {
  const UserLogin({super.key});

  @override
  State<UserLogin> createState() => _UserLoginState();
}

class _UserLoginState extends State<UserLogin>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final UserServer _userServer = UserServer();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

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

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  //----------------------------------------------------------------------------
  Future<void> _handleLogin() async {
    if (await UtilsInternet.isConnect()) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        WidgetToast.showError(context, 'please_fill_all_fields'.tr(context));
        return;
      }

      final bool isEmailValid = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      ).hasMatch(email);
      if (!isEmailValid) {
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        WidgetToast.showError(context, 'invalid_email_format'.tr(context));
        return;
      }

      if (password.length < 6) {
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        WidgetToast.showError(context, 'password_too_short'.tr(context));
        return;
      }

      FocusScope.of(context).unfocus();
      setState(() => _isLoading = true);

      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint("Error fetching FCM token: $e");
      }

      final response = await _userServer.login(
        email: email,
        password: password,
        fcmToken: fcmToken,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response != null && response.statusCode == 200) {
        final bool status = response.data['status'] ?? false;
        if (status) {
          final userData = response.data['user'];
          final String token = response.data['token'];
          await UtilsStorage.saveString(AppStorageNames.userToken, token);
          print("userData:- ${userData.toString()}");
          if (userData != null) {
            await UtilsStorage.saveString(
              AppStorageNames.userId,
              (userData['id'] ?? 0).toString(),
            );
            UtilsStorage.saveString(
              AppStorageNames.userName,
              userData['name'] ?? '',
            );
            UtilsStorage.saveString(
              AppStorageNames.userEmail,
              userData['email'] ?? '',
            );
            UtilsStorage.saveString(
              AppStorageNames.userPhone,
              userData['phone'] ?? '',
            );
            UtilsStorage.saveString(
              AppStorageNames.userState,
              userData['state'] ?? '',
            );
            UtilsStorage.saveString(
              AppStorageNames.userAddress,
              userData['address'] ?? '',
            );
            UtilsStorage.saveString(
              AppStorageNames.userImage,
              userData['profile_image'] ?? '',
            );
          }

          UtilsSound.playSound(AppSounds.notification, _audioPlayer);
          WidgetToast.showSuccess(
            context,
            response.data['message']?.toString().tr(context) ??
                'success'.tr(context),
          );

          await initializeUserBackgroundService();

          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          UtilsNavigator.goWidgetNoBack(context, const UserHome());
        } else {
          UtilsSound.playSound(AppSounds.error, _audioPlayer);
          WidgetToast.showError(
            context,
            response.data['message']?.toString().tr(context) ??
                'error'.tr(context),
          );
        }
      } else {
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        String errorMsg =
            response!.data['message']?.toString() ?? 'error'.tr(context);
        if (errorMsg == 'invalid_credentials') {
          errorMsg = 'invalid_credentials'.tr(context);
        } else if (errorMsg == 'account_blocked') {
          errorMsg = 'account_blocked'.tr(context);
        } else {
          errorMsg = 'something_went_wrong'.tr(context);
        }
        WidgetToast.showError(context, errorMsg);
      }
    } else {
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
      WidgetToast.showWarning(context, 'no_internet_connection'.tr(context));
    }
  }

  //----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 120,
                            width: 120,
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.03),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(0.0),
                              child: Image(
                                image: const AssetImage(AppImages.logoNoBg),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'welcome_back'.tr(context),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      'login_desc'.tr(context),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    WidgetDivider(title: 'email'.tr(context)),
                    const SizedBox(height: 15),
                    WidgetPrimaryTextfield(
                      controller: _emailController,
                      hint: 'enter_email'.tr(context),
                      icon: IconlyLight.message,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 15),
                    WidgetDivider(title: 'password'.tr(context)),
                    const SizedBox(height: 15),
                    WidgetPrimaryTextfield(
                      controller: _passwordController,
                      hint: 'enter_password'.tr(context),
                      icon: IconlyLight.lock,
                      obscureText: !_isPasswordVisible,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                        icon: Icon(
                          _isPasswordVisible
                              ? IconlyLight.show
                              : IconlyLight.hide,
                          color: theme.iconTheme.color,
                          size: 22,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => UtilsNavigator.go(
                          context,
                          const UserForgotPassword(),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          foregroundColor: theme.hintColor,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'forgot_pass'.tr(context),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    WidgetPrimaryButton(
                      text: 'login'.tr(context),
                      isLoading: _isLoading,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 20),
                    const WidgetCommonOrDivider(),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'dont_have_account'.tr(context),
                          style: TextStyle(color: theme.hintColor),
                        ),
                        TextButton(
                          onPressed: () =>
                              UtilsNavigator.go(context, const UserRegister()),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'register'.tr(context),
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
