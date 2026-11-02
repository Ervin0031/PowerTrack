import 'package:app_flutter/features/auth/presentation/screens/change_password_screen.dart';
import 'package:app_flutter/features/auth/presentation/screens/devices_screen.dart';
import 'package:app_flutter/features/auth/presentation/screens/email_verify_screen.dart';
import 'package:app_flutter/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:app_flutter/features/auth/presentation/screens/login_screen.dart';
import 'package:app_flutter/features/auth/presentation/screens/register_screen.dart';
import 'package:app_flutter/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:app_flutter/features/exercises/presentation/screens/exercise_detail_page.dart';
import 'package:app_flutter/features/exercises/presentation/screens/exercises_page.dart';
import 'package:app_flutter/features/coach/presentation/coach_chat_page.dart';
import 'package:app_flutter/features/home/presentation/screens/home_page.dart';
import 'package:app_flutter/features/training/presentation/screens/training_session_page.dart';
import 'package:app_flutter/features/training/presentation/screens/training_calendar_page.dart';
import 'package:app_flutter/features/training/presentation/screens/muscle_recovery_page.dart';
import 'package:app_flutter/features/training/presentation/screens/exercise_stats_page.dart';
import 'package:app_flutter/features/dynamic/presentation/screens/follow_list_page.dart';
import 'package:app_flutter/features/dynamic/presentation/screens/post_detail_page.dart';
import 'package:app_flutter/features/dynamic/presentation/screens/user_search_page.dart';
import 'package:app_flutter/features/dynamic/presentation/screens/workout_detail_page.dart';
import 'package:app_flutter/features/templates/presentation/screens/template_completions_page.dart';
import 'package:app_flutter/features/templates/presentation/screens/template_detail_page.dart';
import 'package:app_flutter/features/templates/presentation/screens/template_editor_page.dart';
import 'package:app_flutter/features/templates/presentation/screens/templates_page.dart';
import 'package:app_flutter/core/router/fade_forwards_page.dart';
import 'package:app_flutter/core/router/heroine_zoom_route.dart';
import 'package:app_flutter/core/router/safe_heroine_controller.dart';
import 'package:app_flutter/features/splash/presentation/screens/splash_page.dart';
import 'package:app_flutter/features/welcome/presentation/screens/welcome_page.dart';
import 'package:app_flutter/features/permissions/presentation/screens/permissions_guide_page.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/profile/presentation/screens/account_settings_page.dart';
import 'package:app_flutter/features/profile/presentation/screens/fitness_profile_page.dart';
import 'package:app_flutter/features/profile/presentation/screens/weight_history_page.dart';
import 'package:app_flutter/features/profile/presentation/screens/onboarding_page.dart';
import 'package:app_flutter/features/settings/presentation/screens/ai_settings_page.dart';
import 'package:app_flutter/features/settings/presentation/screens/cache_settings_page.dart';
import 'package:app_flutter/features/settings/presentation/screens/settings_page.dart';
import 'package:app_flutter/features/settings/presentation/screens/theme_settings_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../providers/dio_provider.dart';
import 'router_names.dart';

/// 路由常量表。
///
/// 集中定义路径可以减少页面跳转时的字符串拼写错误，也方便后续统一改路由层级。

/// 应用路由 Provider。
///
/// Riverpod 语义：
/// - `keepAlive: true`：GoRouter 是应用级对象，应与 App 生命周期保持一致。
///
/// 分流规则：
/// 1. Splash 页面允许先展示启动过渡。
/// 2. 未看过 Welcome 时强制进入 Welcome。
/// 3. 已看过 Welcome 但未登录时进入 Login。
/// 4. 已登录且未完成权限引导时进入 Permissions。
/// 5. 已登录且未完成健身档案时进入 Onboarding。
/// 6. 已登录且档案完整时进入 Home，并避免停留在 Login。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    observers: [SafeHeroineController()],
    initialLocation: AppRoutes.splash,

    redirect: (BuildContext context, GoRouterState state) {
      final location = state.matchedLocation;
      // 使用 matchedLocation 而不是原始 uri，可避免 query 参数影响基础路由判断。
      final onSplash = location == AppRoutes.splash;
      final onWelcome = location == AppRoutes.welcome;
      final onLogin = location == AppRoutes.login;
      final onRegister = location == AppRoutes.emailRegister;
      final onEmailVerify = location == AppRoutes.emailVerify;
      final onForgotPassword = location == AppRoutes.forgotPassword;
      final onResetPassword = location == AppRoutes.resetPassword;
      final onChangePassword = location == AppRoutes.changePassword;
      final onDevices = location == AppRoutes.devices;
      final onOnboarding = location == AppRoutes.onboarding;
      final onPermissions = location == AppRoutes.permissions;
      final hasSeenWelcome = ref.read(appLaunchStorageProvider).hasSeenWelcome;
      final hasSeenPermissions = ref
          .read(appLaunchStorageProvider)
          .hasSeenPermissionsGuide;
      final isLoggedIn = ref.read(tokenStorageProvider).hasToken;
      final profileComplete = ref
          .read(fitnessProfileStorageProvider)
          .isComplete;

      String afterAuthHome() {
        if (!hasSeenPermissions) return AppRoutes.permissions;
        return profileComplete ? AppRoutes.home : AppRoutes.onboarding;
      }

      // Splash 自己负责延迟和首屏跳转，router 不在这里抢先改向。
      if (onSplash) return null;

      if (!hasSeenWelcome) {
        return onWelcome ? null : AppRoutes.welcome;
      }

      if (onWelcome) {
        if (!isLoggedIn) return AppRoutes.login;
        return afterAuthHome();
      }

      // 注册页对未登录用户放行：注册流程与登录状态无关。
      if (onRegister) return null;

      // 邮箱验证 / 找回密码 / 重置密码：均为「未登录态」下的自服务流程，
      // 允许直接进入（避免邮件链接跳转时被登录守卫挡住）。
      if (onEmailVerify || onForgotPassword || onResetPassword) return null;

      if (!isLoggedIn) {
        return onLogin ? null : AppRoutes.login;
      }

      // 以下为「已登录」专属：未登录时已在上方被重定向到登录页，
      // 这里对登录页本身放行，其余受保护路由保持现状。
      if (onLogin) {
        return afterAuthHome();
      }

      // 已登录才能访问的页面（修改密码 / 我的设备）。
      if (onChangePassword || onDevices) return null;

      // 权限引导优先于健身档案问卷。
      if (!hasSeenPermissions) {
        return onPermissions ? null : AppRoutes.permissions;
      }

      // 档案未完成：除引导页外一律送去问卷。本地标记由登录/拉取档案写入。
      if (!profileComplete && !onOnboarding) return AppRoutes.onboarding;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (_, _) => const NoTransitionPage(child: SplashPage()),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (_, _) => const NoTransitionPage(child: WelcomePage()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, _) => const NoTransitionPage(child: LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.emailRegister,
        pageBuilder: (context, state) =>
            FadeForwardsPage(child: RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.emailVerify,
        pageBuilder: (context, state) => FadeForwardsPage(
          child: EmailVerifyScreen(
            email: state.extra is Map
                ? (state.extra as Map)['email'] as String?
                : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) =>
            FadeForwardsPage(child: ForgotPasswordScreen()),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        pageBuilder: (context, state) => FadeForwardsPage(
          child: ResetPasswordScreen(
            email: state.extra is Map
                ? (state.extra as Map)['email'] as String?
                : null,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        pageBuilder: (context, state) =>
            FadeForwardsPage(child: ChangePasswordScreen()),
      ),
      GoRoute(
        path: AppRoutes.devices,
        pageBuilder: (context, state) =>
            FadeForwardsPage(child: DevicesScreen()),
      ),
      GoRoute(
        path: AppRoutes.permissions,
        pageBuilder: (_, _) =>
            const NoTransitionPage(child: PermissionsGuidePage()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (_, _) => const NoTransitionPage(child: OnboardingPage()),
      ),
      GoRoute(
        path: AppRoutes.fitnessProfile,
        pageBuilder: (context, state) =>
            const FadeForwardsPage(child: FitnessProfilePage()),
      ),
      GoRoute(
        path: AppRoutes.accountSettings,
        pageBuilder: (context, state) =>
            const FadeForwardsPage(child: AccountSettingsPage()),
      ),
      GoRoute(
        path: AppRoutes.weightHistory,
        pageBuilder: (context, state) =>
            const FadeForwardsPage(child: WeightHistoryPage()),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (_, _) => const NoTransitionPage(child: HomePage()),
      ),
      GoRoute(
        path: AppRoutes.coach,
        // 左缘滑动打开聊天记录，不参与返回手势。
        pageBuilder: (_, _) =>
            const FadeForwardsPage(popGesture: false, child: CoachChatPage()),
      ),
      GoRoute(
        path: AppRoutes.exercises,
        pageBuilder: (context, state) =>
            FadeForwardsPage(child: ExercisesPage()),
      ),
      GoRoute(
        path: AppRoutes.exerciseDetail,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return FadeForwardsPage(child: ExerciseDetailPage(id: id ?? 0));
        },
      ),
      GoRoute(
        path: AppRoutes.trainingSession,
        pageBuilder: (_, _) => HeroineZoomPage(
          tag: 'training_session_top',
          builder: (context) => TrainingSessionPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.trainingCalendar,
        pageBuilder: (context, state) => FadeForwardsPage(
          key: state.pageKey,
          child: const TrainingCalendarPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.muscleRecovery,
        pageBuilder: (_, _) =>
            const FadeForwardsPage(child: MuscleRecoveryPage()),
      ),
      GoRoute(
        path: AppRoutes.exerciseStats,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final extra = state.extra;
          final args = extra is ExerciseStatsArgs ? extra : null;
          return FadeForwardsPage(
            child: ExerciseStatsPage(
              exerciseId: id,
              name: args?.name ?? '动作数据',
              weightUnit: args?.weightUnit ?? 'kg',
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.workoutDetail,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return FadeForwardsPage(child: WorkoutDetailPage(sessionId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.postDetail,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return FadeForwardsPage(child: PostDetailPage(postId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.userSearch,
        pageBuilder: (context, state) =>
            const FadeForwardsPage(child: UserSearchPage()),
      ),
      GoRoute(
        path: AppRoutes.follows,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return FadeForwardsPage(
            child: FollowListPage(
              userId: id,
              username: state.extra is String ? state.extra as String : null,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.templates,
        pageBuilder: (context, state) =>
            const FadeForwardsPage(child: TemplatesPage()),
      ),
      GoRoute(
        path: AppRoutes.templateCreate,
        pageBuilder: (context, state) =>
            const FadeForwardsPage(child: TemplateEditorScope()),
      ),
      GoRoute(
        path: AppRoutes.templateDetail,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return FadeForwardsPage(child: TemplateDetailPage(templateId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.templateEdit,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return FadeForwardsPage(child: TemplateEditorScope(templateId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.templateCompletions,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return FadeForwardsPage(
            child: TemplateCompletionsPage(templateId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (_, _) => const FadeForwardsPage(child: SettingsPage()),
      ),
      GoRoute(
        path: AppRoutes.themeSettings,
        pageBuilder: (_, _) =>
            const FadeForwardsPage(child: ThemeSettingsPage()),
      ),
      GoRoute(
        path: AppRoutes.cacheSettings,
        pageBuilder: (_, _) =>
            const FadeForwardsPage(child: CacheSettingsPage()),
      ),
      GoRoute(
        path: AppRoutes.aiSettings,
        pageBuilder: (_, _) => const FadeForwardsPage(child: AiSettingsPage()),
      ),
    ],
  );
});
