import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/chat_request_model.dart';

class ChatRequestRepository {
  final ApiClient apiClient;

  ChatRequestRepository({required this.apiClient});

  Future<List<ChatRequestIncoming>> getIncomingRequests({
    int limit = 20,
    int? nextCursor,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'next_cursor': ?nextCursor,
    };

    final response = await apiClient.get(
      ApiEndpoints.chatRequestsReceived,
      queryParameters: queryParams,
    );

    final resData = response.data;
    if (resData is Map && resData['data'] != null) {
      final dataObj = resData['data'];
      dynamic items;
      if (dataObj is Map && dataObj['items'] is List) {
        items = dataObj['items'];
      } else if (dataObj is List) {
        items = dataObj;
      }

      if (items is List) {
        return items
            .map((e) => ChatRequestIncoming.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
    return [];
  }

  Future<List<ChatRequestOutgoing>> getOutgoingRequests({
    int limit = 20,
    int? nextCursor,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'next_cursor': ?nextCursor,
    };

    final response = await apiClient.get(
      ApiEndpoints.chatRequestsSent,
      queryParameters: queryParams,
    );

    final resData = response.data;
    if (resData is Map && resData['data'] != null) {
      final dataObj = resData['data'];
      dynamic items;
      if (dataObj is Map && dataObj['items'] is List) {
        items = dataObj['items'];
      } else if (dataObj is List) {
        items = dataObj;
      }

      if (items is List) {
        return items
            .map((e) => ChatRequestOutgoing.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
    return [];
  }

  Future<ChatRequestCount> getRequestCount() async {
    final response = await apiClient.get(ApiEndpoints.chatRequestsCount);
    final resData = response.data;
    if (resData is Map && resData['data'] is Map) {
      return ChatRequestCount.fromJson(Map<String, dynamic>.from(resData['data'] as Map));
    }
    return ChatRequestCount();
  }

  Future<bool> sendChatRequest({
    required String email,
    String? message,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.chatRequests,
      data: {
        'receiver_email': email.trim(),
        'message': message?.trim() ?? '',
      },
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> acceptRequest(int id) async {
    final response = await apiClient.patch(ApiEndpoints.acceptChatRequest(id));
    return response.statusCode == 200;
  }

  Future<bool> rejectRequest(int id) async {
    final response = await apiClient.patch(ApiEndpoints.rejectChatRequest(id));
    return response.statusCode == 200;
  }

  Future<bool> cancelRequest(int id) async {
    final response = await apiClient.patch(ApiEndpoints.cancelChatRequest(id));
    return response.statusCode == 200;
  }
}
