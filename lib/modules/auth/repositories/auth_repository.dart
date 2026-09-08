import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.login,
      data: {
        'email': email,
        'password': password,
      },
    );

    final responseData = response.data;
    final data = responseData is Map && responseData['data'] != null
        ? responseData['data']
        : responseData;

    return AuthResponseModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AuthResponseModel> register({
    required String email,
    required String name,
    required String password,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.register,
      data: {
        'email': email,
        'name': name,
        'password': password,
      },
    );

    final responseData = response.data;
    final data = responseData is Map && responseData['data'] != null
        ? responseData['data']
        : responseData;

    return AuthResponseModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<AuthResponseModel> loginWithGoogle({required String code}) async {
    final response = await apiClient.post(
      ApiEndpoints.googleAuth,
      data: {
        'code': code,
      },
    );

    final responseData = response.data;
    final data = responseData is Map && responseData['data'] != null
        ? responseData['data']
        : responseData;

    return AuthResponseModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<UserModel> getMe() async {
    final response = await apiClient.get(ApiEndpoints.me);
    final responseData = response.data;
    final data = responseData is Map && responseData['data'] != null
        ? responseData['data']
        : responseData;

    return UserModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> logout({String? refreshToken}) async {
    await apiClient.post(
      ApiEndpoints.logout,
      data: {
        'refresh_token': ?refreshToken,
      },
    );
  }

  Future<String> forgotPassword({required String email}) async {
    final response = await apiClient.post(
      ApiEndpoints.forgotPassword,
      data: {'email': email},
    );
    final responseData = response.data;
    if (responseData is Map && responseData['message'] != null) {
      return responseData['message'] as String;
    }
    return 'Instruksi reset kata sandi telah dikirim ke email Anda.';
  }

  Future<bool> verifyResetToken({String? token, String? email, String? code}) async {
    final body = <String, dynamic>{};
    if (token != null) body['token'] = token;
    if (email != null) body['email'] = email;
    if (code != null) body['code'] = code;

    await apiClient.post(
      ApiEndpoints.verifyResetToken,
      data: body,
    );
    return true;
  }

  Future<bool> resetPassword({
    required String newPassword,
    String? token,
    String? email,
    String? code,
  }) async {
    final body = <String, dynamic>{
      'new_password': newPassword,
    };
    if (token != null) body['token'] = token;
    if (email != null) body['email'] = email;
    if (code != null) body['code'] = code;

    await apiClient.post(
      ApiEndpoints.resetPassword,
      data: body,
    );
    return true;
  }
}

