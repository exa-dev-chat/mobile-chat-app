import 'package:get/get.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/register_view.dart';
import '../modules/auth/views/forgot_password_view.dart';
import '../modules/call/bindings/call_binding.dart';
import '../modules/call/views/call_view.dart';
import '../modules/chat/bindings/chat_binding.dart';
import '../modules/chat/views/chat_detail_view.dart';
import '../modules/chat/views/chat_list_view.dart';
import '../modules/chat_request/bindings/chat_request_binding.dart';
import '../modules/chat_request/views/chat_request_view.dart';
import '../modules/profile/bindings/profile_binding.dart';
import '../modules/profile/views/profile_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import 'app_routes.dart';
import 'middlewares/auth_middleware.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.splash;

  static final routes = <GetPage>[
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
      middlewares: [GuestMiddleware()],
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.register,
      page: () => const RegisterView(),
      binding: AuthBinding(),
      middlewares: [GuestMiddleware()],
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: Routes.forgotPassword,
      page: () => const ForgotPasswordView(),
      binding: AuthBinding(),
      middlewares: [GuestMiddleware()],
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: Routes.chats,
      page: () => const ChatListView(),
      binding: ChatBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.chatDetail,
      page: () => const ChatDetailView(),
      binding: ChatBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: Routes.call,
      page: () => const CallView(),
      binding: CallBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.downToUp,
    ),
    GetPage(
      name: Routes.chatRequests,
      page: () => const ChatRequestView(),
      binding: ChatRequestBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeftWithFade,
    ),
    GetPage(
      name: Routes.profile,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
      middlewares: [AuthMiddleware()],
      transition: Transition.rightToLeftWithFade,
    ),
  ];
}
