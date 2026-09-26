import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:iconly/iconly.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:user_app/constants/app_colors.dart';
import 'package:user_app/constants/app_border_radius.dart';
import 'package:user_app/constants/app_sounds.dart';
import 'package:user_app/constants/app_storage_names.dart';
import 'package:user_app/languages/core/extention.dart';
import 'package:user_app/main.dart';
import 'package:user_app/screens/user/user_active_trip.dart';
import 'package:user_app/screens/user/user_menu.dart';
import 'package:user_app/services/user_server.dart';
import 'package:user_app/services/reverb_service.dart';
import 'package:user_app/services/osm_geocoding_service.dart';
import 'package:user_app/utils/utils_sound.dart';
import 'package:user_app/utils/utils_storage.dart';
import 'package:user_app/widgets/common/widget_common_map_icon.dart';
import 'package:user_app/widgets/common/widget_common_map_path_lines.dart';
import 'package:user_app/widgets/common/widget_compass_3d.dart';
import 'package:user_app/widgets/common/widget_common_navbar.dart';
import 'package:user_app/widgets/common/widget_toast.dart';
import 'package:user_app/widgets/user/widget_user_blocked.dart';
import 'package:user_app/widgets/user/widget_captains_count_card.dart';
import 'package:user_app/widgets/user/widget_user_empty_trips.dart';
import 'package:user_app/widgets/user/widget_user_item_marker.dart';
import 'package:user_app/widgets/user/widget_user_rating_dialog.dart';
import 'package:user_app/widgets/user/widget_user_trip_request_sheet.dart';
import 'package:user_app/widgets/user/widget_user_trip_request_card.dart';
import 'package:user_app/widgets/user/widget_user_cancel_trip_dialog.dart';
import 'package:user_app/widgets/user/widget_user_location_required.dart';
import 'package:user_app/widgets/user/widget_user_map_data_card.dart';

const List<Map<String, dynamic>> kUserTileLayers = [
  {
    'name': 'Standard',
    'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'icon': Icons.map_outlined,
  },
  {
    'name': 'Light',
    'url': 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
    'icon': Icons.wb_sunny_outlined,
  },
  {
    'name': 'Dark',
    'url': 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
    'icon': Icons.nightlight_round,
  },
  {
    'name': 'Topo',
    'url': 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    'icon': Icons.terrain,
  },
  {
    'name': 'Satellite',
    'url':
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'icon': Icons.satellite_alt,
  },
];
const String kUserAgentPackage = 'com.rahlaty.online';

class UserGpsState {
  final ValueNotifier<LatLng?> position = ValueNotifier(null);
  final ValueNotifier<double> heading = ValueNotifier(0.0);
  final ValueNotifier<double?> speed = ValueNotifier(null);
  final ValueNotifier<double?> altitude = ValueNotifier(null);

  void dispose() {
    position.dispose();
    heading.dispose();
    speed.dispose();
    altitude.dispose();
  }
}

class UserTripState {
  final ValueNotifier<Map<String, dynamic>?> activeTrip = ValueNotifier(null);
  final ValueNotifier<String> tripStatus = ValueNotifier('none');
  void dispose() {
    activeTrip.dispose();
    tripStatus.dispose();
  }
}

//----------------------------------------------------------------------------
class UserHome extends StatefulWidget {
  const UserHome({super.key});
  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _hasShownRatingDialog = false;
  StreamSubscription? _fcmEventSub;
  int _currentIndex = 0;
  final UserGpsState _gps = UserGpsState();
  final UserTripState _trip = UserTripState();
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ServiceStatus>? _serviceStatusStream;
  double _lastMoveLat = 0.0, _lastMoveLng = 0.0;
  static const double _moveThreshold = 0.0005;
  final MapController _mapController = MapController();
  final ValueNotifier<double> _mapRotationNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> _zoomNotifier = ValueNotifier(15.0);
  int _activeTileLayerIndex = 0;
  bool _mapReady = false;
  bool _isLocating = true;
  bool _showUiElements = true;
  bool _isCancelling = false;
  bool _isBlocked = false;

  late AnimationController _radarController;
  late Animation<double> _radarAnimation;
  late AnimationController _pulseController;
  final UserServer _userServer = UserServer();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OsmRoutingService _routingService = OsmRoutingService();
  Timer? _arrowBlinkTimer;
  final ValueNotifier<bool> _arrowsVisible = ValueNotifier(true);
  bool _arrowsEnabled = true;
  String? _currentSubscriptionChannel;
  bool _isSubscribed = false;
  List<LatLng> _legToPickupPoints = [];
  List<LatLng> _legPickupToDropPoints = [];
  bool _isRouteLoading = false;
  LatLng? _pickupLocation, _dropoffLocation;

  final Map<int, int> _captainsCounts = {10: 0, 20: 0, 30: 0};
  Timer? _captainsCountTimer;
  Timer? _currentTripRefreshTimer;

  final double _userSearchRadius = 0.5;

  String? _getUserIdSafe() {
    try {
      return UtilsStorage.readString(AppStorageNames.userId);
    } catch (e) {
      return UtilsStorage.readInt(AppStorageNames.userId)?.toString();
    }
  }

  //----------------------------------------------------------------------------
  void _listenToFcmEvents() {
    _fcmEventSub = GlobalEventBus.instance.stream.listen((data) {
      if (!mounted) return;
      final status = data['status'];
      final tripIdStr = data['trip_id'] ?? data['id'];
      final tripId = int.tryParse(tripIdStr.toString());

      print("EVENT_BUS: Received data $data");

      if (status == 'completed' && tripId != null) {
        if (_hasShownRatingDialog) return;
        _hasShownRatingDialog = true;
        final current = Map<String, dynamic>.from(_trip.activeTrip.value ?? {});
        current['id'] = tripId;
        current['status'] = 'completed';
        _trip.activeTrip.value = current;
        _trip.tripStatus.value = 'completed';
        if (_currentIndex != 1) {
          setState(() => _currentIndex = 1);
        }
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            WidgetUserRatingDialog.show(
              context,
              tripId: tripId,
              onRated: () {},
            );
          }
        });
      } else if (status == 'cancelled') {
        _onTripEnded();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _listenToBackgroundService();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _enforceLocationServices();
    _fetchCurrentTrip();
    _startArrowBlink();
    _subscribeToWebSocket();
    _listenToServiceStatus();
    _startPeriodicTripRefresh();
    _checkBlockStatus();
    _listenToFcmEvents();
  }

  //----------------------------------------------------------------------------
  void _startArrowBlink() {
    _arrowBlinkTimer?.cancel();
    if (!_arrowsEnabled) {
      _arrowsVisible.value = false;
      return;
    }
    _arrowsVisible.value = true;
    _arrowBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_arrowsEnabled) {
        _arrowsVisible.value = !_arrowsVisible.value;
      } else {
        _arrowsVisible.value = false;
      }
    });
  }

  //----------------------------------------------------------------------------
  void _toggleArrows() {
    setState(() {
      _arrowsEnabled = !_arrowsEnabled;
      if (_arrowsEnabled) {
        _startArrowBlink();
      } else {
        _arrowBlinkTimer?.cancel();
        _arrowsVisible.value = false;
      }
    });
  }

  //----------------------------------------------------------------------------
  Future<void> _checkBlockStatus() async {
    try {
      final res = await _userServer.getProfile();
      if (res != null && res.statusCode == 200) {
        final user = res.data['user'];
        final blocked = user['is_blocked'] ?? false;
        if (mounted) {
          setState(() => _isBlocked = blocked);
          if (blocked && _trip.activeTrip.value != null) {
            _onTripEnded();
          }
        }
      }
    } catch (e) {}
  }

  //----------------------------------------------------------------------------
  void _setupAnimations() {
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _radarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _radarController, curve: Curves.linear));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  void _subscribeToWebSocket() {
    if (_isSubscribed) return;
    final token = UtilsStorage.readString(AppStorageNames.userToken);
    final userId = _getUserIdSafe();
    if (token == null || userId == null) return;
    final channel = 'user.$userId';
    ReverbService().subscribe(
      channel,
      'TripStatusUpdated',
      (data) async {
        print("WS_FOREGROUND: TripStatusUpdated received: ${data['status']}");
        if (!mounted) return;
        final incomingId = data['id'];
        final activeId = _trip.activeTrip.value?['id'];
        if (activeId == null || incomingId == activeId) {
          final newStatus = data['status'] ?? 'accepted';
          final current = Map<String, dynamic>.from(
            _trip.activeTrip.value ?? {},
          );
          current['id'] = incomingId;
          current['status'] = newStatus;
          if (data['captain'] != null) {
            current['captain'] = Map<String, dynamic>.from(data['captain']);
          }
          if (data['final_price'] != null)
            current['final_price'] = data['final_price'];
          _trip.activeTrip.value = current;
          _trip.tripStatus.value = newStatus;

          if (newStatus == 'accepted') {
            await _fetchAndOpenActiveTrip();
            if (mounted && _currentIndex != 1) {
              setState(() => _currentIndex = 1);
            }
          } else if (newStatus == 'completed') {
            final tripId = current['id'];
            if (mounted && _currentIndex != 1) {
              setState(() => _currentIndex = 1);
            }
            // _onTripEnded();

            if (mounted && tripId != null) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  WidgetUserRatingDialog.show(
                    context,
                    tripId: tripId,
                    onRated: () {},
                  );
                }
              });
            }
          } else if (newStatus == 'cancelled') {
            _onTripEnded();
          }
        }
      },
      token: token,
      isPrivate: true,
    );

    ReverbService().subscribe(
      channel,
      'CaptainLocationUpdated',
      (data) {
        final captainId = _trip.activeTrip.value?['captain']?['id'];
        if (captainId != null && data['captain_id'] == captainId && mounted) {
          final currentTrip = _trip.activeTrip.value;
          if (currentTrip != null) {
            currentTrip['captain'] ??= {};
            currentTrip['captain']['lat'] = (data['lat'] as num).toDouble();
            currentTrip['captain']['lng'] = (data['lng'] as num).toDouble();
            currentTrip['captain']['heading'] = (data['heading'] ?? 0)
                .toDouble();
            _trip.activeTrip.value = Map<String, dynamic>.from(currentTrip);
          }
        }
      },
      token: token,
      isPrivate: true,
    );
    _currentSubscriptionChannel = channel;
    _isSubscribed = true;
  }

  void _listenToBackgroundService() {
    final service = FlutterBackgroundService();
    service.on('tripStatusUpdate').listen((event) {
      if (!mounted || event == null) return;
      print("BG_USERHOME: Received tripStatusUpdate: $event");
      final status = event['status'];
      final tripId = event['id'];
      if (tripId == null) return;
      final current = Map<String, dynamic>.from(_trip.activeTrip.value ?? {});
      current['id'] = tripId;
      current['status'] = status;
      if (event['captain'] != null) {
        current['captain'] = Map<String, dynamic>.from(event['captain']);
      }
      if (event['final_price'] != null) {
        current['final_price'] = event['final_price'];
      }
      _trip.activeTrip.value = current;
      _trip.tripStatus.value = status;

      if (status == 'completed') {
        if (mounted && _currentIndex != 1) {
          setState(() => _currentIndex = 1);
        }
      } else if (status == 'cancelled') {
        _onTripEnded();
      }
    });
  }

  //----------------------------------------------------------------------------
  void _listenToServiceStatus() {
    _serviceStatusStream?.cancel();
    _serviceStatusStream = Geolocator.getServiceStatusStream().listen((status) {
      if (!mounted) return;
      if (status == ServiceStatus.disabled) {
        WidgetUserLocationRequired.showLocationIssueDialog(
          context: context,
          title: 'location_services_disabled'.tr(context),
          message: 'please_enable_location_settings'.tr(context),
          openSettings: true,
        );
      } else if (status == ServiceStatus.enabled) {
        _refreshLocationAndTracking();
      }
    });
  }

  //----------------------------------------------------------------------------
  Future<void> _enforceLocationServices() async {
    await _setupLocationAndTracking();
    if (_gps.position.value == null && mounted) {
      setState(() => _isLocating = false);
    }
  }

  //----------------------------------------------------------------------------
  Future<void> _fetchAndOpenActiveTrip() async {
    try {
      final response = await UserServer().getCurrentTrip();
      if (response != null &&
          response.statusCode == 200 &&
          response.data['status'] == true &&
          response.data['trip'] != null &&
          mounted) {
        _trip.activeTrip.value = Map<String, dynamic>.from(
          response.data['trip'],
        );
        _trip.tripStatus.value = response.data['trip']['status'] ?? 'accepted';
      }
    } catch (e) {
      debugPrint('fetchAndOpenActiveTrip error: $e');
    }
  }

  //----------------------------------------------------------------------------
  Future<bool> _setupLocationAndTracking() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _isLocating = false);
      WidgetUserLocationRequired.showLocationIssueDialog(
        context: context,
        title: 'location_services_disabled'.tr(context),
        message: 'please_enable_location_settings'.tr(context),
        openSettings: true,
      );
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      if (mounted) setState(() => _isLocating = false);
      WidgetUserLocationRequired.showLocationIssueDialog(
        context: context,
        title: 'location_permission_denied'.tr(context),
        message: 'location_permission_denied_message'.tr(context),
        openAppSettings: true,
      );
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _isLocating = false);
      WidgetUserLocationRequired.showLocationIssueDialog(
        context: context,
        title: 'location_permission_denied_forever'.tr(context),
        message: 'location_permission_denied_forever_message'.tr(context),
        openAppSettings: true,
      );
      return false;
    }
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        _gps.position.value = LatLng(lastKnown.latitude, lastKnown.longitude);
        _gps.heading.value = lastKnown.heading;
        if (_mapReady && mounted && _currentIndex == 0) {
          _mapController.move(_gps.position.value!, _zoomNotifier.value);
        }
      }
    } catch (_) {}
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return false;
      final pos = LatLng(position.latitude, position.longitude);
      _gps.position.value = pos;
      _gps.heading.value = position.heading;
      if (_mapReady && mounted && _currentIndex == 0) {
        _mapController.move(pos, _zoomNotifier.value);
      }
      _startLiveTracking();
      _startPeriodicCaptainsCount();
      if (mounted) setState(() => _isLocating = false);
      return true;
    } catch (e) {
      if (mounted) setState(() => _isLocating = false);
      WidgetUserLocationRequired.showLocationIssueDialog(
        context: context,
        title: 'unable_to_get_location'.tr(context),
        message: 'unable_to_get_location_message'.tr(context),
      );
      return false;
    }
  }

  //----------------------------------------------------------------------------
  Future<bool> _refreshLocationAndTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      WidgetUserLocationRequired.showLocationIssueDialog(
        context: context,
        title: 'location_services_disabled'.tr(context),
        message: 'please_enable_location_settings'.tr(context),
        openSettings: true,
      );
      if (_positionStream == null || _positionStream?.isPaused == true) {
        _startLiveTracking();
      }
      return true;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      WidgetUserLocationRequired.showLocationIssueDialog(
        context: context,
        title: 'location_permission_denied'.tr(context),
        message: 'location_permission_denied_message'.tr(context),
        openAppSettings: true,
      );
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      WidgetUserLocationRequired.showLocationIssueDialog(
        context: context,
        title: 'location_permission_denied_forever'.tr(context),
        message: 'location_permission_denied_forever_message'.tr(context),
        openAppSettings: true,
      );
      return false;
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      position = await Geolocator.getLastKnownPosition();
    }

    if (position == null) {
      WidgetUserLocationRequired.showLocationIssueDialog(
        context: context,
        title: 'unable_to_get_location'.tr(context),
        message: 'unable_to_get_location_message'.tr(context),
      );
      return false;
    }

    final latLng = LatLng(position.latitude, position.longitude);
    _gps.position.value = latLng;
    _gps.heading.value = position.heading;
    _gps.speed.value = position.speed;
    _gps.altitude.value = position.altitude;

    if (_mapReady && mounted && _currentIndex == 0) {
      _mapController.move(latLng, _zoomNotifier.value);
    }

    if (_positionStream == null || _positionStream?.isPaused == true) {
      _startLiveTracking();
    }
    _startPeriodicCaptainsCount();
    return true;
  }

  //----------------------------------------------------------------------------
  void _startLiveTracking() {
    _positionStream?.cancel();
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
          ),
        ).listen((pos) {
          if (!mounted) return;
          final latLng = LatLng(pos.latitude, pos.longitude);
          _gps.position.value = latLng;
          _gps.heading.value = pos.heading;
          _gps.speed.value = pos.speed;
          _gps.altitude.value = pos.altitude;
          final dLat = (latLng.latitude - _lastMoveLat).abs();
          final dLng = (latLng.longitude - _lastMoveLng).abs();
          if (dLat > _moveThreshold || dLng > _moveThreshold) {
            _lastMoveLat = latLng.latitude;
            _lastMoveLng = latLng.longitude;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_mapReady && mounted && _currentIndex == 0) {
                try {
                  _mapController.move(latLng, _mapController.camera.zoom);
                } catch (_) {}
              }
            });
          }
          if (_trip.activeTrip.value != null &&
              (_legToPickupPoints.isEmpty && _legPickupToDropPoints.isEmpty) &&
              !_isRouteLoading) {
            _fetchRoute();
          }
        });
  }

  //----------------------------------------------------------------------------
  Future<void> _startPeriodicCaptainsCount() async {
    _captainsCountTimer?.cancel();
    await _fetchCaptainsCounts();
    _captainsCountTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchCaptainsCounts(),
    );
  }

  //----------------------------------------------------------------------------
  Future<void> _fetchCaptainsCounts() async {
    final position = _gps.position.value;
    if (position == null) return;
    for (final radius in [10, 20, 30]) {
      try {
        final response = await _userServer.getNearbyCaptains(
          position.latitude,
          position.longitude,
          radius: radius.toDouble(),
        );
        if (mounted &&
            response != null &&
            response.statusCode == 200 &&
            response.data['status'] == true) {
          final captains = response.data['captains'] as List?;
          final count = captains?.length ?? 0;
          setState(() => _captainsCounts[radius] = count);
        }
      } catch (e) {
        debugPrint('Error fetching captains for radius $radius: $e');
      }
    }
  }

  //----------------------------------------------------------------------------
  void _startPeriodicTripRefresh() {
    _currentTripRefreshTimer?.cancel();
    _currentTripRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
      timer,
    ) async {
      if (_trip.activeTrip.value != null) {
        await _fetchCurrentTrip();
      }
    });
  }

  //----------------------------------------------------------------------------
  Future<void> _fetchCurrentTrip() async {
    try {
      final response = await _userServer.getCurrentTrip();

      if (response != null && response.statusCode == 200 && mounted) {
        final data = response.data;
        if (data != null && data['status'] == true && data['trip'] != null) {
          final trip = Map<String, dynamic>.from(data['trip']);
          final oldTrip = _trip.activeTrip.value;
          final oldStatus = _trip.tripStatus.value;
          final newStatus = trip['status'] ?? 'accepted';

          if (oldTrip != null &&
              oldStatus == 'requested' &&
              newStatus != 'requested') {
            if (mounted) {
              WidgetToast.showInfo(
                context,
                'trip_to_active_screen'.tr(context),
              );
            }
          }

          setState(() {
            _trip.activeTrip.value = trip;
            _trip.tripStatus.value = newStatus;
          });

          if (_mapReady && _gps.position.value != null) _fetchRoute();
        } else {
          if (_trip.activeTrip.value != null) {
            if (_trip.tripStatus.value == 'requested') {
              if (mounted) {
                WidgetToast.showInfo(
                  context,
                  'trip_expired_no_captain'.tr(context),
                );
              }
            }

            setState(() {
              _trip.activeTrip.value = null;
              _trip.tripStatus.value = 'none';
              _currentIndex = 0;
              _legToPickupPoints = [];
              _legPickupToDropPoints = [];
              _pickupLocation = null;
              _dropoffLocation = null;
            });
          }
        }
      } else if (_trip.activeTrip.value != null && mounted) {
        setState(() {
          _trip.activeTrip.value = null;
          _trip.tripStatus.value = 'none';
          _currentIndex = 0;
          _legToPickupPoints = [];
          _legPickupToDropPoints = [];
          _pickupLocation = null;
          _dropoffLocation = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching current trip: $e');
    }
  }

  Future<void> _fetchRoute() async {
    if (_trip.activeTrip.value == null ||
        _gps.position.value == null ||
        _isRouteLoading) {
      return;
    }
    final tripData = _trip.activeTrip.value!;
    final pickupLat = tripData['pickup_latitude'] ?? tripData['pickup_lat'];
    final pickupLng = tripData['pickup_longitude'] ?? tripData['pickup_lng'];
    final dropLat = tripData['dropoff_latitude'] ?? tripData['dropoff_lat'];
    final dropLng = tripData['dropoff_longitude'] ?? tripData['dropoff_lng'];
    if (pickupLat == null ||
        pickupLng == null ||
        dropLat == null ||
        dropLng == null) {
      return;
    }
    final pickup = LatLng(
      double.tryParse(pickupLat.toString()) ?? 0.0,
      double.tryParse(pickupLng.toString()) ?? 0.0,
    );
    final dropoff = LatLng(
      double.tryParse(dropLat.toString()) ?? 0.0,
      double.tryParse(dropLng.toString()) ?? 0.0,
    );
    if (pickup.latitude == 0.0 && pickup.longitude == 0.0) return;
    if (dropoff.latitude == 0.0 && dropoff.longitude == 0.0) return;
    setState(() {
      _pickupLocation = pickup;
      _dropoffLocation = dropoff;
      _isRouteLoading = true;
    });
    try {
      final r1 = await _routingService.getRouteWithDistance(
        _gps.position.value!,
        pickup,
      );
      final r2 = await _routingService.getRouteWithDistance(pickup, dropoff);
      setState(() {
        _legToPickupPoints = List.from(r1['points'] ?? []);
        _legPickupToDropPoints = List.from(r2['points'] ?? []);
      });
    } catch (e) {
      debugPrint('Route fetch error: $e');
    } finally {
      if (mounted) setState(() => _isRouteLoading = false);
    }
  }

  void _onTripEnded() {
    if (!mounted) return;
    setState(() {
      _trip.activeTrip.value = null;
      _trip.tripStatus.value = 'none';
      _currentIndex = 0;
      _legToPickupPoints = [];
      _legPickupToDropPoints = [];
      _pickupLocation = null;
      _dropoffLocation = null;
    });
    _fetchCurrentTrip();
    if (!_isSubscribed) {
      _subscribeToWebSocket();
    }
  }

  //----------------------------------------------------------------------------
  Future<void> _showTripRequestScreen() async {
    if (_isBlocked) {
      if (mounted) {
        WidgetToast.showError(context, 'account_blocked'.tr(context));
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
      }
      return;
    }
    if (await _userServer.hasActiveTrip()) {
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
      if (mounted) {
        WidgetToast.showError(context, 'you_have_active_trip'.tr(context));
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WidgetUserTripRequestSheet(
          userPosition: _gps.position.value,
          onTripRequested: (tripData) {
            if (tripData != null) {
              _trip.activeTrip.value = Map<String, dynamic>.from(tripData);
              _trip.tripStatus.value = tripData['status'] ?? 'requested';
            }
            _fetchCurrentTrip();
            if (mounted) setState(() => _currentIndex = 0);
          },
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  Future<void> _cancelTripRequest() async {
    final trip = _trip.activeTrip.value;
    if (trip == null) return;
    await _fetchCurrentTrip();
    final currentTrip = _trip.activeTrip.value;

    if (currentTrip == null) {
      WidgetToast.showInfo(context, 'trip_already_cancelled'.tr(context));
      UtilsSound.playSound(AppSounds.error, _audioPlayer);

      return;
    }
    if (currentTrip['status'] == 'cancelled' ||
        currentTrip['status'] == 'completed') {
      WidgetToast.showInfo(context, 'trip_already_cancelled'.tr(context));
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
      return;
    }

    final confirm = await WidgetUserCancelTripDialog.show(context);
    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      final response = await _userServer.cancelTrip(currentTrip['id']);

      if (response != null) {
        if (response.statusCode == 200) {
          _onTripEnded();
          WidgetToast.showSuccess(
            context,
            'trip_cancelled_success'.tr(context),
          );
          UtilsSound.playSound(AppSounds.notification, _audioPlayer);
        } else if (response.statusCode == 400 &&
            response.data is Map &&
            response.data['message'] == 'trip_already_completed') {
          UtilsSound.playSound(AppSounds.error, _audioPlayer);
          _onTripEnded();
          WidgetToast.showInfo(context, 'trip_already_cancelled'.tr(context));
          UtilsSound.playSound(AppSounds.error, _audioPlayer);
        } else {
          WidgetToast.showError(context, 'failed_cancel_trip'.tr(context));
          UtilsSound.playSound(AppSounds.error, _audioPlayer);
        }
      } else {
        WidgetToast.showError(context, 'server_error'.tr(context));
        UtilsSound.playSound(AppSounds.error, _audioPlayer);
      }
    } catch (e) {
      WidgetToast.showError(context, 'server_error'.tr(context));
      UtilsSound.playSound(AppSounds.error, _audioPlayer);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  //----------------------------------------------------------------------------
  PolylineLayer _buildRadiusDimensionPolyline(LatLng center, double radiusKm) {
    final radiusMeters = radiusKm * 1000;
    final offset = _metersToLatLngOffset(radiusMeters, 0);
    final edgePoint = LatLng(
      center.latitude + offset.latitude,
      center.longitude + offset.longitude,
    );
    return PolylineLayer(
      polylines: [
        Polyline(
          points: [center, edgePoint],
          strokeWidth: 2,
          color: Colors.orange,
          pattern: StrokePattern.dashed(segments: [10, 8]),
        ),
      ],
    );
  }

  //----------------------------------------------------------------------------
  MarkerLayer _buildRadiusDimensionMarker(LatLng center, double radiusKm) {
    final radiusMeters = radiusKm * 1000;
    final offset = _metersToLatLngOffset(radiusMeters, 0);
    final midPoint = LatLng(
      center.latitude + offset.latitude / 2,
      center.longitude + offset.longitude / 2,
    );
    return MarkerLayer(
      markers: [
        Marker(
          point: midPoint,
          width: 60,
          height: 30,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$radiusKm ${'km'.tr(context)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  //----------------------------------------------------------------------------
  LatLng _metersToLatLngOffset(double metersEast, double metersNorth) {
    const double earthRadius = 6371000;
    final lat = _gps.position.value!.latitude;
    final latOffset = (metersNorth / earthRadius) * (180 / pi);
    final lngOffset =
        (metersEast / (earthRadius * cos(lat * pi / 180))) * (180 / pi);
    return LatLng(latOffset, lngOffset);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _reconnectWebSocketIfNeeded();
      _fetchCurrentTrip();
    }
  }

  //----------------------------------------------------------------------------
  void _reconnectWebSocketIfNeeded() {
    if (!_isSubscribed) {
      print("WS_RECONNECT: Re-subscribing to WebSocket...");
      _subscribeToWebSocket();
    }
    if (_currentSubscriptionChannel != null) {
      print("WS_RECONNECT: Cleaning up old subscription and re-subscribing...");
      ReverbService().unsubscribe(_currentSubscriptionChannel!);
      _currentSubscriptionChannel = null;
      _isSubscribed = false;
      _subscribeToWebSocket();
    }
  }

  //----------------------------------------------------------------------------
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStream?.cancel();
    _serviceStatusStream?.cancel();
    _arrowBlinkTimer?.cancel();
    _captainsCountTimer?.cancel();
    _currentTripRefreshTimer?.cancel();
    _arrowsVisible.dispose();
    _radarController.dispose();
    _pulseController.dispose();
    _gps.dispose();
    _trip.dispose();
    _mapRotationNotifier.dispose();
    _zoomNotifier.dispose();
    _fcmEventSub?.cancel();
    if (_currentSubscriptionChannel != null) {
      ReverbService().unsubscribe(_currentSubscriptionChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBlocked) {
      return Scaffold(backgroundColor: Colors.white, body: WidgetUserBlocked());
    }
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildMapTab(),
              _buildActiveTripsTab(),
              const SizedBox.shrink(),
              UserMenu(),
            ],
          ),
          if (_isLocating)
            Container(
              color: Colors.white.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          if (_currentIndex == 0 &&
              _trip.activeTrip.value != null &&
              _trip.tripStatus.value == 'requested')
            Positioned(
              left: 20,
              right: 20,
              bottom: 135,
              child: WidgetUserRequestedTripCard(
                trip: _trip.activeTrip.value!,
                isCancelling: _isCancelling,
                onCancel: _cancelTripRequest,
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: _buildFloatingNavbar(),
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildFloatingNavbar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              WidgetCommonNavbar(
                index: 0,
                icon: IconlyLight.home,
                label: 'home'.tr(context),
                isSelected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              WidgetCommonNavbar(
                index: 1,
                icon: Icons.car_crash_outlined,
                label: 'active_trips'.tr(context),
                isSelected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              WidgetCommonNavbar(
                index: 2,
                icon: IconlyLight.discovery,
                label: 'request_ride'.tr(context),
                isSelected: _currentIndex == 2,
                onTap: _showTripRequestScreen,
              ),
              WidgetCommonNavbar(
                index: 3,
                icon: IconlyLight.setting,
                label: 'settings'.tr(context),
                isSelected: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildMapTab() {
    return TickerMode(
      enabled: _currentIndex == 0,
      child: Stack(
        children: [
          RepaintBoundary(child: _buildMapLayer()),
          if (_showUiElements) _buildLeftMapControls(),
          _buildRightMapControls(),
          if (_showUiElements) _buildHorizontalScaleBar(),
          if (_showUiElements)
            Positioned(
              left: 40,
              top: 1 + MediaQuery.of(context).padding.top,
              child: ValueListenableBuilder<double>(
                valueListenable: _mapRotationNotifier,
                builder: (_, rotation, __) => WidgetCompass3d(
                  size: 70,
                  rotationDeg: rotation,
                  northLabel: 'north'.tr(context),
                  southLabel: 'south'.tr(context),
                  eastLabel: 'east'.tr(context),
                  westLabel: 'west'.tr(context),
                  onTap: () => _mapController.rotate(0),
                ),
              ),
            ),
          if (_showUiElements && _currentIndex == 0)
            Positioned(
              right: 5,
              top: MediaQuery.of(context).padding.top + 4,
              child: WidgetCaptainsCountCard(counts: _captainsCounts),
            ),
          if (_showUiElements)
            Positioned(
              right: 5,
              top: MediaQuery.of(context).padding.top + 44,
              child: _buildGpsDataCard(),
            ),
        ],
      ),
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildHorizontalScaleBar() {
    final bottomPadding =
        40.0 +
        MediaQuery.of(context).padding.bottom +
        kBottomNavigationBarHeight;
    return Positioned(
      bottom: bottomPadding,
      left: 0,
      right: 0,
      child: Center(
        child: ValueListenableBuilder<double>(
          valueListenable: _zoomNotifier,
          builder: (_, zoom, __) {
            final lat = _gps.position.value?.latitude ?? 0.0;
            final metersPerPixel =
                156543.03392 * cos(lat * pi / 180) / pow(2, zoom);
            const List<int> niceDistances = [
              50,
              100,
              200,
              500,
              1000,
              2000,
              5000,
              10000,
            ];
            int selectedMeters = 100;
            double bestPixels = 0;
            for (final d in niceDistances) {
              final px = d / metersPerPixel;
              if (px >= 30 && px <= 100) {
                selectedMeters = d;
                bestPixels = px;
                break;
              }
            }
            if (bestPixels == 0) {
              for (final d in niceDistances) {
                final px = d / metersPerPixel;
                if (px > 100) continue;
                selectedMeters = d;
                bestPixels = px;
                break;
              }
            }
            final screenWidth = MediaQuery.of(context).size.width;
            final barWidth = max(screenWidth * 0.7, 80.0);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: barWidth,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppBorderRadius.medium,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedMeters >= 1000
                        ? '${(selectedMeters / 1000).toStringAsFixed(1)} ${'km'.tr(context)}'
                        : '$selectedMeters ${'m'.tr(context)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildMapLayer() {
    final activeTile = kUserTileLayers[_activeTileLayerIndex];
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _gps.position.value ?? const LatLng(33.3152, 44.3661),
        initialZoom: 15.0,
        minZoom: 12.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags:
              InteractiveFlag.drag |
              InteractiveFlag.rotate |
              InteractiveFlag.pinchZoom |
              InteractiveFlag.doubleTapZoom,
        ),
        onMapReady: () {
          _mapReady = true;
          if (_gps.position.value != null) {
            _mapController.move(_gps.position.value!, 15.0);
          }
          if (_trip.activeTrip.value != null && _gps.position.value != null) {
            _fetchRoute();
          }
        },
        onPositionChanged: (camera, _) {
          _mapRotationNotifier.value = camera.rotation;
          _zoomNotifier.value = camera.zoom;
        },
      ),
      children: [
        TileLayer(
          key: ValueKey(_activeTileLayerIndex),
          urlTemplate: activeTile['url'] as String,
          userAgentPackageName: kUserAgentPackage,
          maxZoom: 19,
          minZoom: 3,
          errorImage: const AssetImage('assets/images/map_error_tile.png'),
        ),
        ValueListenableBuilder<LatLng?>(
          valueListenable: _gps.position,
          builder: (_, position, __) {
            if (position == null) return const SizedBox.shrink();
            return CircleLayer(
              circles: [
                CircleMarker(
                  point: position,
                  radius: _userSearchRadius * 1000,
                  color: AppColors.primary.withOpacity(0.08),
                  borderColor: AppColors.primary.withOpacity(0.5),
                  borderStrokeWidth: 2.5,
                  useRadiusInMeter: true,
                ),
              ],
            );
          },
        ),
        if (_gps.position.value != null) ...[
          _buildRadiusDimensionPolyline(
            _gps.position.value!,
            _userSearchRadius,
          ),
          _buildRadiusDimensionMarker(_gps.position.value!, _userSearchRadius),
        ],
        if (_legToPickupPoints.isNotEmpty)
          WidgetCommonMapPathLines(
            points: _legToPickupPoints,
            color: Colors.orange.shade700,
            dashed: true,
            strokeWidth: 4,
            glowWidth: 10,
          ),
        if (_legPickupToDropPoints.isNotEmpty)
          WidgetCommonMapPathLines(
            points: _legPickupToDropPoints,
            color: AppColors.primary,
            dashed: false,
            strokeWidth: 8,
            glowWidth: 16,
          ),
        CircleLayer(
          circles: [
            if (_pickupLocation != null)
              CircleMarker(
                point: _pickupLocation!,
                radius: 18 + (_pulseController.value * 8),
                color: Colors.redAccent.withOpacity(0.12),
                borderColor: Colors.redAccent.withOpacity(0.6),
                borderStrokeWidth: 2,
              ),
            if (_dropoffLocation != null)
              CircleMarker(
                point: _dropoffLocation!,
                radius: 18 + (_pulseController.value * 8),
                color: AppColors.primary.withOpacity(0.12),
                borderColor: AppColors.primary.withOpacity(0.6),
                borderStrokeWidth: 2,
              ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (_pickupLocation != null)
              Marker(
                point: _pickupLocation!,
                width: 56,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            if (_dropoffLocation != null)
              Marker(
                point: _dropoffLocation!,
                width: 56,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
          ],
        ),
        ValueListenableBuilder<LatLng?>(
          valueListenable: _gps.position,
          builder: (_, pos, __) {
            if (pos == null) return const SizedBox.shrink();
            return MarkerLayer(
              markers: [
                Marker(
                  point: pos,
                  width: 200,
                  height: 200,
                  child: WidgetUserItemMarker(
                    heading: _gps.heading.value,
                    radarAnimation: _radarAnimation,
                  ),
                ),
              ],
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _arrowsVisible,
          builder: (_, visible, __) {
            if (!visible) return const MarkerLayer(markers: []);
            return MarkerLayer(
              markers: [
                ..._buildDirectionArrows(
                  _legToPickupPoints,
                  Colors.orange.shade800,
                ),
                ..._buildDirectionArrows(
                  _legPickupToDropPoints,
                  AppColors.primary,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Marker> _buildDirectionArrows(List<LatLng> points, Color color) {
    if (points.length < 2) return [];

    final interpolated = _interpolatePointsIfNeeded(points);

    final arrowMarkers = <Marker>[];
    final meter = const Distance();
    double accumulatedDistance = 0;
    const double spacingMeters = 200;

    for (int i = 1; i < interpolated.length; i++) {
      final p1 = interpolated[i - 1];
      final p2 = interpolated[i];
      accumulatedDistance += meter.as(LengthUnit.Meter, p1, p2);
      if (accumulatedDistance >= spacingMeters ||
          i == interpolated.length - 1) {
        accumulatedDistance = 0;
        final bearing = meter.bearing(p1, p2);
        arrowMarkers.add(
          Marker(
            point: p2,
            width: 28,
            height: 28,
            child: Transform.rotate(
              angle: bearing * (pi / 180) - (pi / 2),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        );
      }
    }
    return arrowMarkers;
  }

  //----------------------------------------------------------------------------
  List<LatLng> _interpolatePointsIfNeeded(List<LatLng> points) {
    if (points.length < 3) return points;

    final meter = const Distance();
    double totalDist = 0;
    for (int i = 1; i < points.length; i++) {
      totalDist += meter.as(LengthUnit.Meter, points[i - 1], points[i]);
    }

    if (totalDist > 200 && points.length < totalDist / 50) {
      const stepMeters = 15.0;
      final newPoints = <LatLng>[];
      for (int i = 1; i < points.length; i++) {
        final p1 = points[i - 1];
        final p2 = points[i];
        final segDist = meter.as(LengthUnit.Meter, p1, p2);
        final steps = (segDist / stepMeters).ceil();
        for (int j = 0; j < steps; j++) {
          final fraction = j / steps;
          final lat = p1.latitude + (p2.latitude - p1.latitude) * fraction;
          final lng = p1.longitude + (p2.longitude - p1.longitude) * fraction;
          newPoints.add(LatLng(lat, lng));
        }
      }
      if (newPoints.isNotEmpty && newPoints.last != points.last) {
        newPoints.add(points.last);
      }
      return newPoints;
    }
    return points;
  }

  Widget _buildLeftMapControls() {
    return Positioned(
      left: 14,
      top: 140,
      child: Column(children: _buildLayerSwitcherButtons()),
    );
  }

  List<Widget> _buildLayerSwitcherButtons() {
    return List.generate(kUserTileLayers.length, (index) {
      final layer = kUserTileLayers[index];
      final isActive = index == _activeTileLayerIndex;
      return GestureDetector(
        onTap: () => setState(() => _activeTileLayerIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary.withOpacity(0.9) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : AppColors.border.withOpacity(0.6),
              width: 2,
            ),
          ),
          child: Icon(
            layer['icon'] as IconData,
            size: 20,
            color: isActive ? Colors.white : Colors.black87,
          ),
        ),
      );
    });
  }

  //----------------------------------------------------------------------------
  Widget _buildRightMapControls() {
    return Positioned(
      right: 14,
      top: 140,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Visibility(
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              visible: _showUiElements,
              child: WidgetCommonMapIcon(
                icon: Icons.navigation_rounded,
                color: AppColors.primary,
                onTap: () {
                  _mapController.rotate(0);
                  final pos = _gps.position.value;
                  if (pos != null) {
                    _mapController.move(pos, _zoomNotifier.value);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            WidgetCommonMapIcon(
              icon: _showUiElements ? Icons.visibility_off : Icons.visibility,
              color: AppColors.primary,
              onTap: () => setState(() => _showUiElements = !_showUiElements),
            ),
            const SizedBox(height: 8),
            Visibility(
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              visible: _showUiElements,
              child: WidgetCommonMapIcon(
                icon: Icons.my_location_rounded,
                color: AppColors.primary,
                onTap: () {
                  final pos = _gps.position.value;
                  if (pos != null) _mapController.move(pos, 15.0);
                },
              ),
            ),
            const SizedBox(height: 8),
            Visibility(
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              visible: _showUiElements,
              child: WidgetCommonMapIcon(
                icon: _arrowsEnabled
                    ? Icons.arrow_right_alt
                    : Icons.arrow_right_alt_outlined,
                color: _arrowsEnabled ? AppColors.primary : Colors.grey,
                onTap: _toggleArrows,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildGpsDataCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_gps.heading, _gps.speed, _gps.altitude]),
      builder: (_, __) => WidgetUserMapDataCard(
        speed: _gps.speed.value,
        altitude: _gps.altitude.value,
        heading: _gps.heading.value,
      ),
    );
  }

  //----------------------------------------------------------------------------
  Widget _buildActiveTripsTab() {
    if (_trip.activeTrip.value != null) {
      return UserActiveTrip(
        gpsState: _gps,
        tripState: _trip,
        onTripEnded: _onTripEnded,
      );
    } else {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: WidgetUserEmptyTrips(),
      );
    }
  }
}
