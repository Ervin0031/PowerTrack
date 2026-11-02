abstract final class AppRoutes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const login = '/login';
  static const home = '/home';
  static const coach = '/coach';

  // auth
  static const emailRegister = '/email_register';
  static const emailVerify = '/email_verify';
  static const forgotPassword = '/forgot_password';
  static const resetPassword = '/reset_password';
  static const changePassword = '/change_password';
  static const devices = '/devices';

  // exercises
  static const exercises = '/exercises';
  static const exerciseDetail = '/exercises/:id';

  // training
  static const trainingSession = '/training/session';
  static const trainingExercises = '/training/exercises';

  // settings
  static const settings = '/settings';
  static const themeSettings = '/settings/theme';
  static const cacheSettings = '/settings/cache';
  static const aiSettings = '/settings/ai';

  // fitness profile
  static const onboarding = '/onboarding';
  static const permissions = '/permissions';
  static const fitnessProfile = '/profile/fitness';
  static const accountSettings = '/profile/account';
  static const weightHistory = '/profile/weight';

  // training calendar
  static const trainingCalendar = '/training/calendar';
  static const muscleRecovery = '/training/recovery';

  // exercise stats
  static const exerciseStats = '/training/exercises/:id/stats';

  // dynamic / workout feed
  static const workoutDetail = '/dynamic/sessions/:id';
  static const postDetail = '/dynamic/posts/:id';
  static const userSearch = '/dynamic/search';
  static const follows = '/dynamic/users/:id/follows';

  // templates
  static const templates = '/templates';
  static const templateCreate = '/templates/create';
  static const templateDetail = '/templates/:id';
  static const templateEdit = '/templates/:id/edit';
  static const templateCompletions = '/templates/:id/completions';

  static String exerciseStatsOf(int id) => '/training/exercises/$id/stats';
  static String postDetailOf(int id) => '/dynamic/posts/$id';
  static String followsOf(int userId) => '/dynamic/users/$userId/follows';
  static String workoutDetailOf(int id) => '/dynamic/sessions/$id';
  static String templateDetailOf(int id) => '/templates/$id';
  static String templateEditOf(int id) => '/templates/$id/edit';
  static String templateCompletionsOf(int id) => '/templates/$id/completions';
}
