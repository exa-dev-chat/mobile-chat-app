class ApiEndpoints {
  ApiEndpoints._();

  // Authentication
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String refresh = '/api/auth/refresh';
  static const String me = '/api/auth/me';
  static const String logout = '/api/auth/logout';
  static const String googleAuth = '/api/auth/google';
  static const String appleAuth = '/api/auth/apple';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String verifyResetToken = '/api/auth/verify-reset-token';
  static const String resetPassword = '/api/auth/reset-password';
  static const String sendRegistrationOtp = '/api/auth/send-registration-otp';
  static const String sendVerificationOtp = '/api/auth/send-verification-otp';
  static const String verifyEmailOtp = '/api/auth/verify-email-otp';
  static const String linkGoogle = '/api/auth/link-google';
  static const String unlinkGoogle = '/api/auth/unlink-google';
  static const String linkApple = '/api/auth/link-apple';
  static const String unlinkApple = '/api/auth/unlink-apple';

  // Chats
  static const String chats = '/api/chats';
  static String chatDetail(int chatId) => '/api/chats/$chatId';
  static String chatMembers(int chatId) => '/api/chats/$chatId/members';
  static const String chatMembersLastMessage = '/api/chat-members/last-message';

  // Messages
  static const String messages = '/api/messages';
  static String chatMessages(int chatId) => '/api/messages?chat_id=$chatId';
  static String readReceipt(int messageId) => '/api/messages/$messageId/read';

  // Users & Search
  static const String users = '/api/users';
  static const String searchUsers = '/api/users/search';
  static const String updateProfile = '/api/users/me';

  // Chat Requests
  static const String chatRequests = '/api/chat-requests';
  static const String chatRequestsGroup = '/api/chat-requests/group';
  static const String chatRequestsReceived = '/api/chat-requests/received';
  static const String chatRequestsSent = '/api/chat-requests/sent';
  static const String chatRequestsCount = '/api/chat-requests/count';
  static String acceptChatRequest(int id) => '/api/chat-requests/$id/accept';
  static String rejectChatRequest(int id) => '/api/chat-requests/$id/reject';
  static String cancelChatRequest(int id) => '/api/chat-requests/$id/cancel';

  // Upload
  static const String upload = '/api/upload';
}
