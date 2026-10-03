import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/chat_room_model.dart';
import '../models/message_model.dart';

class ChatRepository {
  final ApiClient apiClient;

  ChatRepository({required this.apiClient});

  Future<List<ChatRoomModel>> getChats({
    int limit = 20,
    String? nextCursor,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'next_cursor': ?nextCursor,
      'search': ?(search != null && search.isNotEmpty ? search : null),
    };

    final response = await apiClient.get(
      ApiEndpoints.chats,
      queryParameters: queryParams,
    );

    final resData = response.data;
    dynamic items;

    if (resData is Map) {
      final dataObj = resData['data'];
      if (dataObj is Map && dataObj['items'] is List) {
        items = dataObj['items'];
      } else if (dataObj is List) {
        items = dataObj;
      }
    } else if (resData is List) {
      items = resData;
    }

    if (items is List) {
      return items
          .map((e) => ChatRoomModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return [];
  }

  Future<List<MessageModel>> getMessages(
    int chatId, {
    int limit = 30,
    String? nextCursor,
  }) async {
    final queryParams = <String, dynamic>{
      'chat_id': chatId,
      'limit': limit,
      'next_cursor': ?nextCursor,
    };

    final response = await apiClient.get(
      ApiEndpoints.messages,
      queryParameters: queryParams,
    );

    final resData = response.data;
    dynamic items;

    if (resData is Map) {
      final dataObj = resData['data'];
      if (dataObj is Map && dataObj['items'] is List) {
        items = dataObj['items'];
      } else if (dataObj is List) {
        items = dataObj;
      }
    } else if (resData is List) {
      items = resData;
    }

    if (items is List) {
      return items
          .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return [];
  }

  Future<MessageModel> sendMessage({
    required int chatId,
    required String content,
    String messageType = 'text',
    int currentUserId = 0,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.messages,
      data: {
        'chat_id': chatId,
        'content': content,
        'type': messageType,
        'message_type': messageType,
      },
    );

    final resData = response.data;
    final data = resData is Map && resData['data'] != null ? resData['data'] : resData;

    final rawId = data is Map ? (data['id']?.toString() ?? '') : '';
    return MessageModel(
      id: rawId,
      chatId: chatId,
      senderId: currentUserId,
      content: content,
      messageType: messageType,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      isRead: false,
    );
  }

  Future<void> markAsRead(int chatId) async {
    await apiClient.patch(
      ApiEndpoints.chatMembersLastMessage,
      data: {'chat_id': chatId},
    );
  }
  Future<bool> deleteChat(int chatId) async {
    try {
      final response = await apiClient.delete('${ApiEndpoints.chats}/$chatId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId, int chatId) async {
    try {
      final response = await apiClient.delete('${ApiEndpoints.messages}/$messageId/chats/$chatId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
