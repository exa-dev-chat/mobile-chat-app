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

  Future<String> sendRegistrationOtp({required String email}) async {
    final response = await apiClient.post(
      ApiEndpoints.sendRegistrationOtp,
      data: {'email': email},
    );
    final responseData = response.data;
    if (responseData is Map && responseData['message'] != null) {
      return responseData['message'] as String;
    }
    return 'Kode OTP verifikasi telah dikirim ke email Anda.';
  }

  Future<AuthResponseModel> register({
    required String email,
    required String name,
    required String password,
    String? code,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'name': name,
      'password': password,
    };
    if (code != null && code.isNotEmpty) {
      body['code'] = code;
    }

    final response = await apiClient.post(
      ApiEndpoints.register,
      data: body,
    );

    final responseData = response.data;
    final data = responseData is Map && responseData['data'] != null
        ? responseData['data']
        : responseData;

    return AuthResponseModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<String> sendVerificationOtp({String? email}) async {
    final body = <String, dynamic>{};
    if (email != null && email.isNotEmpty) {
      body['email'] = email;
    }
    final response = await apiClient.post(
      ApiEndpoints.sendVerificationOtp,
      data: body,
    );
    final responseData = response.data;
    if (responseData is Map && responseData['message'] != null) {
      return responseData['message'] as String;
    }
    return 'Kode verifikasi telah dikirim ke email Anda.';
  }

  Future<bool> verifyEmailOtp({required String code, String? email}) async {
    final body = <String, dynamic>{
      'code': code,
    };
    if (email != null && email.isNotEmpty) {
      body['email'] = email;
    }
    await apiClient.post(
      ApiEndpoints.verifyEmailOtp,
      data: body,
    );
    return true;
  }

  Future<Map<String, dynamic>> linkGoogle({required String code}) async {
    final response = await apiClient.post(
      ApiEndpoints.linkGoogle,
      data: {'code': code},
    );
    final responseData = response.data;
    return responseData is Map && responseData['data'] != null
        ? Map<String, dynamic>.from(responseData['data'] as Map)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> unlinkGoogle() async {
    final response = await apiClient.post(ApiEndpoints.unlinkGoogle);
    final responseData = response.data;
    return responseData is Map && responseData['data'] != null
        ? Map<String, dynamic>.from(responseData['data'] as Map)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> linkApple({
    required String identityToken,
    String? appleId,
    String? name,
  }) async {
    final body = <String, dynamic>{
      'identity_token': identityToken,
    };
    if (appleId != null && appleId.isNotEmpty) body['apple_id'] = appleId;
    if (name != null && name.isNotEmpty) body['name'] = name;

    final response = await apiClient.post(
      ApiEndpoints.linkApple,
      data: body,
    );
    final responseData = response.data;
    return responseData is Map && responseData['data'] != null
        ? Map<String, dynamic>.from(responseData['data'] as Map)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> unlinkApple() async {
    final response = await apiClient.post(ApiEndpoints.unlinkApple);
    final responseData = response.data;
    return responseData is Map && responseData['data'] != null
        ? Map<String, dynamic>.from(responseData['data'] as Map)
        : <String, dynamic>{};
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

  Future<AuthResponseModel> loginWithApple({
    required String identityToken,
    String? authorizationCode,
    String? name,
    String? appleId,
  }) async {
    final body = <String, dynamic>{
      'identity_token': identityToken,
    };
    if (authorizationCode != null && authorizationCode.isNotEmpty) {
      body['authorization_code'] = authorizationCode;
    }
    if (name != null && name.isNotEmpty) {
      body['name'] = name;
    }
    if (appleId != null && appleId.isNotEmpty) {
      body['apple_id'] = appleId;
    }

    final response = await apiClient.post(
      ApiEndpoints.appleAuth,
      data: body,
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

