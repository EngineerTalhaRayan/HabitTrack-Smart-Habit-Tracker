import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly/iconly.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:user_app/screens/common/common_login.dart';
import 'package:user_app/widgets/common/widget_back_appbar.dart';
import 'package:user_app/widgets/common/widget_or_divider.dart';
import 'package:user_app/widgets/common/widget_divider.dart';
import 'package:user_app/widgets/common/widget_primary_button.dart';
import 'package:user_app/constants/app_border_radius.dart';
import 'package:user_app/constants/app_fonts.dart';
import 'package:user_app/utils/utils_sound.dart';
import 'package:user_app/constants/app_sounds.dart';
import 'package:user_app/languages/core/extention.dart';
import 'package:user_app/providers/language_provider.dart';
import 'package:user_app/services/user_server.dart';
import 'package:user_app/utils/utils_internet.dart';
import 'package:user_app/utils/utils_navigator.dart';
import 'package:user_app/widgets/user/widget_user_profile_picker.dart';
import 'package:user_app/widgets/common/widget_primary_textfield.dart';
import 'package:user_app/widgets/common/widget_toast.dart';

class UserRegister extends StatefulWidget {
  const UserRegister({super.key});

  @override
  State<UserRegister> createState() => _UserRegisterState();
}

class _UserRegisterState extends State<UserRegister>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final UserServer _userServer = UserServer();
  final AudioPlayer _audioPlayer = AudioPlayer();

  File? _profileImage;
  String? _selectedGovernorate;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final List<String> _iraqGovernorates = [
    'بغداد',
    'البصرة',
    'نينوى',
    'أربيل',
    'السليمانية',
    'كركوك',
    'النجف الأشرف',
    'كربلاء المقدسة',
    'بابل',
    'واسط',
    'ميسان',
    'ذي قار',
    'المثنى',
    'القادسية',
    'الأنبار',
    'ديالى',
    'صلاح الدين',
    'دهوك',
    'حلبجة',
  ];

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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  //----------------------------------------------------------------------------
  Future<void> _handleRegister() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String phone = _phoneController.text.trim();
    final String address = _addressController.text.trim();
    final String password = _passwordController.text.trim();

    if (_selectedGovernorate == null ||
        name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        address.isEmpty ||
        password.isEmpty) {
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
      WidgetToast.showError(context, 'please_fill_all_fields'.tr(context));
      return;
    }
    if (_profileImage == null) {
      UtilsSound.playSound(AppSounds.notification, _audioPlayer);
      WidgetToast.showError(context, 'please_upload_profile_image'.tr(context));
      return;
    }
    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
      WidgetToast.showError(context, 'invalid_email_format'.tr(context));
      return;
    }
    if (phone.length != 10 || !phone.startsWith('7')) {
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
      WidgetToast.showError(context, 'phone_format_error'.tr(context));
      return;
    }
    if (password.length < 6) {
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
      WidgetToast.showError(context, 'password_too_short'.tr(context));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    if (await UtilsInternet.isConnect()) {
      try {
        final response = await _userServer.register(
          name: name,
          email: email,
          phone: '+964$phone',
          state: _selectedGovernorate!,
          address: address,
          password: password,
          profileImage: _profileImage!,
        );

        setState(() => _isLoading = false);
        if (response != null && response.statusCode == 201) {
          UtilsSound.playSound(AppSounds.notification, _audioPlayer);
          WidgetToast.showSuccess(context, 'registration_success'.tr(context));
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const CommonLogin(initialType: LoginType.user),
            ),
            (_) => false,
          );
        } else if (response?.statusCode == 422) {
          UtilsSound.playSound(AppSounds.error, _audioPlayer);
          Map<String, dynamic> data = response!.data;
          if (data.containsKey('errors')) {
            Map<String, dynamic> errors = data['errors'];
            if (errors.containsKey('email')) {
              WidgetToast.showError(
                context,
                'email_already_exists'.tr(context),
              );
            } else if (data['message'] ==
                "The profile image field must be a file of type: jpeg, png, jpg.") {
              WidgetToast.showError(
                context,
                'registration_failed_image_not_supported'.tr(context),
              );
            } else if (data['message'] ==
                "The profile image failed to upload.") {
              WidgetToast.showError(context, 'image_error'.tr(context));
            } else if (errors.containsKey('phone')) {
              WidgetToast.showError(
                context,
                'registration_failed_phone'.tr(context),
              );
            } else {
              String firstError = errors.values.first[0];
              WidgetToast.showError(context, firstError);
            }
          } else {
            WidgetToast.showError(
              context,
              data['message'] ?? 'registration_failed'.tr(context),
            );
          }
        } else {
          UtilsSound.playSound(AppSounds.error, _audioPlayer);
          WidgetToast.showError(
            context,
            response?.data['message'] ?? 'registration_failed'.tr(context),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        WidgetToast.showError(context, 'upload_failed'.tr(context));
      }
    } else {
      setState(() => _isLoading = false);
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
      WidgetToast.showWarning(context, 'no_internet_connection'.tr(context));
    }
  }

  //----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLanguage = Provider.of<LanguageProvider>(
      context,
    ).currentLocale.languageCode;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: WidgetBackAppbar(
          title: "register".tr(context),
          currentLanguage: currentLanguage,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'create_account'.tr(context),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'join_us'.tr(context),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.primaryColor,
                            width: 1,
                          ),
                        ),
                        child: WidgetUserProfilePicker(
                          imageFile: _profileImage,
                          onImagePicked: (file) =>
                              setState(() => _profileImage = file),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    WidgetDivider(title: 'full_name'.tr(context)),
                    const SizedBox(height: 15),
                    WidgetPrimaryTextfield(
                      controller: _nameController,
                      hint: 'enter_full_name'.tr(context),
                      icon: IconlyLight.profile,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 15),

                    WidgetDivider(title: 'email'.tr(context)),
                    const SizedBox(height: 15),
                    WidgetPrimaryTextfield(
                      controller: _emailController,
                      hint: 'ahmed@rahlaty.com',
                      icon: IconlyLight.message,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 15),

                    WidgetDivider(title: 'phone_number'.tr(context)),
                    const SizedBox(height: 15),
                    _buildPhoneTextField(theme),

                    const SizedBox(height: 15),

                    WidgetDivider(title: 'governorate'.tr(context)),
                    const SizedBox(height: 15),
                    _buildDropdown(theme),

                    const SizedBox(height: 15),

                    WidgetDivider(title: 'detailed_address'.tr(context)),
                    const SizedBox(height: 15),
                    WidgetPrimaryTextfield(
                      controller: _addressController,
                      hint: 'detailed_address_hint'.tr(context),
                      icon: IconlyLight.location,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 15),

                    WidgetDivider(title: 'password'.tr(context)),
                    const SizedBox(height: 15),
                    WidgetPrimaryTextfield(
                      controller: _passwordController,
                      hint: '*********',
                      icon: IconlyLight.lock,
                      obscureText: !_isPasswordVisible,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleRegister(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                        icon: Icon(
                          _isPasswordVisible
                              ? IconlyLight.show
                              : IconlyLight.hide,
                          color: theme.hintColor,
                          size: 22,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    WidgetPrimaryButton(
                      text: 'register_button'.tr(context),
                      isLoading: _isLoading,
                      onPressed: _handleRegister,
                    ),

                    const SizedBox(height: 20),
                    const WidgetCommonOrDivider(),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'already_have_account'.tr(context),
                          style: TextStyle(color: theme.hintColor),
                        ),
                        TextButton(
                          onPressed: () => UtilsNavigator.go(
                            context,
                            const CommonLogin(initialType: LoginType.user),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'login'.tr(context),
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

  //----------------------------------------------------------------------------
  Widget _buildPhoneTextField(ThemeData theme) {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      cursorColor: theme.primaryColor,
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.colorScheme.surface,
        hintText: '7XX XXX XXXX',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 12),
            Icon(
              IconlyLight.call,
              color: theme.iconTheme.color ?? theme.primaryColor,
              size: 22,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '+964',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          borderSide: BorderSide(
            color: theme.dividerColor.withOpacity(0.4),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      value: _selectedGovernorate,
      menuMaxHeight: 300,
      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      icon: Icon(IconlyLight.arrow_down_2, color: theme.hintColor),
      style: theme.textTheme.bodyLarge?.copyWith(
        fontFamily: AppFonts.cairo,
        fontWeight: FontWeight.w600,
      ),
      dropdownColor: theme.colorScheme.surface,
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
        prefixIcon: Icon(
          IconlyLight.discovery,
          color: theme.iconTheme.color ?? theme.primaryColor,
          size: 22,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          borderSide: BorderSide(
            color: theme.dividerColor.withOpacity(0.4),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
      ),
      hint: Text(
        'select_governorate'.tr(context),
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
      ),
      items: _iraqGovernorates
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (val) => setState(() => _selectedGovernorate = val),
    );
  }
}
