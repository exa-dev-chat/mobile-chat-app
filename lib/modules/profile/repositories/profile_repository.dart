import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../auth/models/user_model.dart';

class ProfileRepository {
  final ApiClient apiClient;

  ProfileRepository({required this.apiClient});

  Future<UserModel> getProfile() async {
    final response = await apiClient.get(ApiEndpoints.me);
    final resData = response.data;
    if (resData is Map && resData['data'] is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(resData['data'] as Map));
    }
    throw Exception('Data profil tidak ditemukan');
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? avatarFilePath,
  }) async {
    final formData = FormData();
    formData.fields.add(MapEntry('name', name.trim()));

    if (avatarFilePath != null && avatarFilePath.isNotEmpty) {
      final fileName = avatarFilePath.split(RegExp(r'[/\\]')).last;
      formData.files.add(MapEntry(
        'avatar',
        await MultipartFile.fromFile(
          avatarFilePath,
          filename: fileName,
        ),
      ));
    }

    final response = await apiClient.patch(
      ApiEndpoints.updateProfile,
      data: formData,
    );

    final resData = response.data;
    if (resData is Map && resData['data'] is Map) {
      return Map<String, dynamic>.from(resData['data'] as Map);
    }
    return {};
  }
}
