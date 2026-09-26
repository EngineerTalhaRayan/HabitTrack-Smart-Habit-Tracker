import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:user_app/constants/app_storage_names.dart';
import 'package:user_app/utils/utils_storage.dart';

class UserServer {
  static const String baseUrl = "https://www.rahlaty.cloud/api";

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (status) => status != null && status < 500,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  //----------------------------------------------------------------------------
  String? _getLiveToken() => UtilsStorage.readString(AppStorageNames.userToken);
  //----------------------------------------------------------------------------
  Future<Response?> getCurrentTrip() async {
    try {
      return await _dio.get('/user/trip/current', options: _getAuthOptions());
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Map<String, dynamic>?> getCaptainLocation() async {
    try {
      final response = await _dio.get(
        '/user/trip/captain-location',
        options: _getAuthOptions(),
      );
      return response.data;
    } on DioException catch (e) {
      return e.response?.data;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> rateTrip(int tripId, int rating) async {
    try {
      return await _dio.post(
        '/user/trip/$tripId/rate',
        data: {'rating': rating},
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Map<String, dynamic>?> getTripDetails(int tripId) async {
    try {
      final response = await _dio.get(
        '/user/trip/$tripId/details',
        options: _getAuthOptions(),
      );
      if (response.statusCode == 200 && response.data['status'] == true) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      print('Get trip details error: $e');
      return e.response?.data;
    } catch (e) {
      print('Unexpected error: $e');
      return null;
    }
  }

  //----------------------------------------------------------------------------
  Options _getAuthOptions() {
    final token = _getLiveToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  //----------------------------------------------------------------------------
  Future<Response?> updateCity(String city) async {
    try {
      return await _dio.post(
        '/user/update-city',
        data: {'city': city},
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> updateEmail(String email) async {
    try {
      return await _dio.post(
        '/user/update-email',
        data: {'email': email},
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> toggleNotifications(bool isEnabled) async {
    try {
      return await _dio.post(
        '/user/notifications/toggle',
        data: {'is_enabled': isEnabled},
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> deleteNotification(int notificationId) async {
    try {
      return await _dio.delete(
        '/user/notifications/$notificationId',
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    } catch (e) {
      return null;
    }
  }

  //----------------------------------------------------------------------------
  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map) {
          return data['display_name'] ?? '$lat, $lng';
        }
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
    }
    return '$lat, $lng';
  }

  //----------------------------------------------------------------------------
  Future<Response?> updateLocation(
    double lat,
    double lng,
    bool isOnline,
  ) async {
    try {
      return await _dio.post(
        '/user/location/update',
        data: {'lat': lat, 'lng': lng, 'is_online': isOnline},
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<bool> hasActiveTrip() async {
    try {
      final response = await _dio.get(
        '/user/trip/current',
        options: _getAuthOptions(),
      );
      return response.statusCode == 200 && response.data['status'] == true;
    } catch (e) {
      return false;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> acceptOffer(int tripId) async {
    try {
      return await _dio.post(
        '/user/trips/$tripId/accept-offer',
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    } catch (e) {
      return null;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> rejectOffer(int tripId) async {
    try {
      return await _dio.post(
        '/user/trips/$tripId/reject-offer',
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    } catch (e) {
      return null;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> updateUserField(String field, String value) async {
    try {
      return await _dio.post(
        '/user/update-field',
        data: {'field': field, 'value': value},
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    } catch (e) {
      return null;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> getProfile() async {
    try {
      return await _dio.get('/user/profile', options: _getAuthOptions());
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> getNearbyCaptains(
    double lat,
    double lng, {
    double radius = 5,
  }) async {
    try {
      return await _dio.post(
        '/user/captains/nearby',
        data: {'lat': lat, 'lng': lng, 'radius': radius},
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> cancelTrip(int tripId) async {
    try {
      return await _dio.post(
        '/user/trip/$tripId/cancel',
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> getUserSpendingStats() async {
    try {
      return await _dio.get('/user/spending/stats', options: _getAuthOptions());
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> getTripsHistory({int page = 1, String search = ''}) async {
    try {
      String url = '/user/trips/history?page=$page';
      if (search.isNotEmpty) {
        url += '&search=$search';
      }
      return await _dio.get(url, options: _getAuthOptions());
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> getNotifications() async {
    try {
      return await _dio.get('/user/notifications', options: _getAuthOptions());
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> requestTrip(Map<String, dynamic> data) async {
    try {
      return await _dio.post(
        '/user/trip/request',
        data: data,
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> updatePassword(String old, String next) async {
    try {
      return await _dio.post(
        '/user/update-password',
        data: {
          'old_password': old,
          'password': next,
          'password_confirmation': next,
        },
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> updateProfilePic(File image) async {
    try {
      String name = image.path.split('/').last;
      FormData data = FormData.fromMap({
        "profile_image": await MultipartFile.fromFile(
          image.path,
          filename: name,
        ),
      });
      return await _dio.post(
        '/user/update-profile-pic',
        data: data,
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> sendSupportTicket(String title, String message) async {
    try {
      final response = await _dio.post(
        '/user/support',
        data: {'title': title, 'message': message},
        options: _getAuthOptions(),
      );
      return response;
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> saveUserNote(String note) async {
    try {
      final response = await _dio.post(
        '/user/notes',
        data: {'note': note},
        options: _getAuthOptions(),
      );
      return response;
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> logout() async {
    try {
      return await _dio.post('/user/logout', options: _getAuthOptions());
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> deleteAccount() async {
    try {
      return await _dio.post(
        '/user/delete-account',
        options: _getAuthOptions(),
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> register({
    required String name,
    required String email,
    required String phone,
    required String state,
    required String address,
    required String password,
    required File profileImage,
    String? fcmToken,
  }) async {
    try {
      String fileName = profileImage.path.split('/').last;
      FormData formData = FormData.fromMap({
        "name": name,
        "email": email,
        "phone": phone,
        "state": state,
        "address": address,
        "password": password,
        "fcm_token": fcmToken ?? '',
        "profile_image": await MultipartFile.fromFile(
          profileImage.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post('/public/user/register', data: formData);
      return response;
    } on DioException catch (e) {
      return e.response;
    } catch (e) {
      return null;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> login({
    required String email,
    required String password,
    String? fcmToken,
  }) async {
    try {
      final response = await _dio.post(
        '/public/user/login',
        data: {
          'email': email,
          'password': password,
          'fcm_token': fcmToken ?? '',
        },
      );
      return response;
    } on DioException catch (e) {
      return e.response;
    } catch (e) {
      return null;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> sendForgotOtp(String email) async {
    try {
      return await _dio.post(
        '/public/forgot/password/send/otp',
        data: {'email': email, 'type': 'user'},
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> verifyForgotOtp(String email, String otp) async {
    try {
      return await _dio.post(
        '/public/forgot/password/verify/otp',
        data: {'email': email, 'otp': otp, 'type': 'user'},
      );
    } on DioException catch (e) {
      return e.response;
    }
  }

  //----------------------------------------------------------------------------
  Future<Uint8List?> fetchCaptainImage(int captainId) async {
    try {
      final token = UtilsStorage.readString(AppStorageNames.userToken);
      final response = await _dio.get(
        '/user/captain/$captainId/image',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.bytes,
        ),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      print('fetchCaptainImage error: $e');
      return null;
    }
  }

  //----------------------------------------------------------------------------
  Future<Response?> resetPassword(
    String email,
    String otp,
    String password,
  ) async {
    try {
      return await _dio.post(
        '/public/forgot/password/reset',
        data: {
          'email': email,
          'otp': otp,
          'password': password,
          'password_confirmation': password,
          'type': 'user',
        },
      );
    } on DioException catch (e) {
      return e.response;
    }
  }
}
