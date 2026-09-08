import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';
import 'logger_service.dart';

class UploadService {
  final ApiClient apiClient;

  UploadService({required this.apiClient});

  Future<String?> uploadFile({
    required String filePath,
    String? fileName,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggerService.e('File not found at path: $filePath', tag: 'UploadService');
        return null;
      }

      final name = fileName ?? filePath.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: name),
      });

      LoggerService.i('Uploading file: $name (${await file.length()} bytes)', tag: 'UploadService');

      final response = await apiClient.post(
        ApiEndpoints.upload,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          extra: {'no_retry': true}, // avoid retrying large file uploads automatically
        ),
      );

      final resData = response.data;
      if (resData is Map) {
        final data = resData['data'];
        if (data is Map && data['file_url'] != null) {
          return data['file_url'] as String;
        } else if (resData['file_url'] != null) {
          return resData['file_url'] as String;
        }
      }
      return null;
    } catch (e) {
      LoggerService.e('File upload failed: $e', tag: 'UploadService');
      return null;
    }
  }
}
