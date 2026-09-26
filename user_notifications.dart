import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:user_app/widgets/captain/widget_delete_notification_dialog.dart';
import 'package:user_app/widgets/common/widget_back_appbar.dart';
import 'package:user_app/constants/app_border_radius.dart';
import 'package:user_app/constants/app_colors.dart';
import 'package:user_app/languages/core/extention.dart';
import 'package:user_app/providers/language_provider.dart';
import 'package:user_app/services/user_server.dart';
import 'package:user_app/widgets/common/widget_empty_data.dart';
import 'package:user_app/widgets/common/widget_no_internet.dart';
import 'package:user_app/utils/utils_sound.dart';
import 'package:user_app/constants/app_sounds.dart';
import 'package:user_app/utils/utils_internet.dart';
import 'package:user_app/widgets/common/widget_toast.dart';
import 'package:user_app/widgets/user/widget_delete_all_notifications_dialog.dart';

class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String targetType;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.targetType,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      targetType: json['target_type'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

//----------------------------------------------------------------------------
class UserNotifications extends StatefulWidget {
  const UserNotifications({super.key});

  @override
  State<UserNotifications> createState() => _UserNotificationsState();
}

class _UserNotificationsState extends State<UserNotifications>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final UserServer _userServer = UserServer();

  bool _isLoading = true;
  bool _hasInternet = true;
  List<NotificationModel> _notifications = [];

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  Future<void> _fetchData() async {
    if (mounted && !_isLoading) setState(() => _isLoading = true);
    final isConnected = await UtilsInternet.isConnect();
    if (!isConnected) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasInternet = false;
        });
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        WidgetToast.showError(context, 'no_internet_connection'.tr(context));
      }
      return;
    }
    try {
      final response = await _userServer.getNotifications();
      if (mounted) {
        setState(() {
          _hasInternet = true;
          if (response != null &&
              response.statusCode == 200 &&
              response.data['status'] == true) {
            final List data = response.data['notifications'] ?? [];
            _notifications = data
                .map((e) => NotificationModel.fromJson(e))
                .toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasInternet = true;
        });
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
        WidgetToast.showError(context, 'error_fetching_data'.tr(context));
      }
    }
  }

  //----------------------------------------------------------------------------
  Future<void> _deleteNotification(int id) async {
    WidgetDeleteNotificationDialog.show(
      context,
      onDeleteConfirmed: () async {
        final response = await _userServer.deleteNotification(id);
        if (mounted &&
            response != null &&
            response.statusCode == 200 &&
            response.data['status'] == true) {
          setState(() {
            _notifications.removeWhere((n) => n.id == id);
          });
          WidgetToast.showSuccess(context, 'notification_deleted'.tr(context));
          UtilsSound.playSound(AppSounds.notification, _audioPlayer);
        } else {
          WidgetToast.showError(context, 'error'.tr(context));
          UtilsSound.playSound(AppSounds.error, _audioPlayer);
        }
      },
    );
  }

  //----------------------------------------------------------------------------
  Future<void> _deleteAllNotifications() async {
    WidgetDeleteAllNotifications.show(
      context,
      onDeleteConfirmed: () async {
        bool allSuccess = true;
        final List<NotificationModel> snapshot = List<NotificationModel>.from(
          _notifications,
        );

        for (final n in snapshot) {
          final response = await _userServer.deleteNotification(n.id);
          if (!(response != null &&
              response.statusCode == 200 &&
              response.data['status'] == true)) {
            allSuccess = false;
            break;
          }
        }

        if (!mounted) return;

        if (allSuccess) {
          setState(() {
            _notifications.clear();
          });
          WidgetToast.showSuccess(
            context,
            'all_notifications_deleted'.tr(context),
          );
          UtilsSound.playSound(AppSounds.notification, _audioPlayer);
          Navigator.of(context).pop();
        } else {
          WidgetToast.showError(context, 'error'.tr(context));
          UtilsSound.playSound(AppSounds.error, _audioPlayer);
          await _fetchData();
          if (mounted) Navigator.of(context).pop();
        }
      },
    );
  }

  //----------------------------------------------------------------------------
  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguage = Provider.of<LanguageProvider>(
      context,
    ).currentLocale.languageCode;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: WidgetBackAppbar(
        title: 'notifications'.tr(context),
        currentLanguage: currentLanguage,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _fetchData,
            color: AppColors.primary,
            backgroundColor: Colors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12.0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isLoading
                          ? const NotificationsShimmer()
                          : (!_hasInternet && _notifications.isEmpty)
                          ? SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: const Center(child: WidgetNoInternet()),
                            )
                          : _notifications.isEmpty
                          ? SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: const Center(child: WidgetEmptyData()),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ..._notifications.map(
                                  (n) => _buildNotificationItem(n),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildNotificationItem(NotificationModel notification) {
    final bool isBroadcast = notification.targetType == 'all_users';
    return GestureDetector(
      onLongPress: () => _deleteAllNotifications(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isBroadcast ? IconlyLight.message : IconlyLight.notification,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                IconlyLight.delete,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: () => _deleteNotification(notification.id),
              tooltip: 'delete_notification'.tr(context),
            ),
          ],
        ),
      ),
    );
  }
}

//----------------------------------------------------------------------------
class NotificationsShimmer extends StatelessWidget {
  const NotificationsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...List.generate(5, (_) => _buildShimmerItem())],
      ),
    );
  }

  Widget _buildShimmerItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 140, color: Colors.white),
                const SizedBox(height: 8),
                Container(height: 12, color: Colors.white),
                const SizedBox(height: 4),
                Container(height: 12, width: 180, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
