import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/ai_chat_page.dart';
import '../features/ai/ai_quick_add_page.dart';
import '../features/ai/weekly_report_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/diet/diet_page.dart';
import '../features/diet/diet_preferences_page.dart';
import '../features/expenses/expense_form_page.dart';
import '../features/expenses/expenses_page.dart';
import '../features/health/health_page.dart';
import '../features/health/health_record_form_page.dart';
import '../features/home/home_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/pets/pet_detail_page.dart';
import '../features/pets/pet_form_page.dart';
import '../features/settings/about_page.dart';
import '../features/settings/ai_settings_page.dart';
import '../features/settings/backup_page.dart';
import '../features/settings/cloud_page.dart';
import '../features/settings/settings_page.dart';
import '../features/timeline/moment_detail_page.dart';
import '../features/timeline/moment_form_page.dart';
import '../features/timeline/timeline_page.dart';
import 'app_shell.dart';
import 'providers.dart';

/// 路由集中配置。
final routerProvider = Provider<GoRouter>((ref) {
  final repo = ref.read(settingsRepoProvider);
  // onboarded 只会从 false 变 true，为 true 后缓存住，
  // 避免每次导航都查一次数据库。
  var onboarded = false;
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) async {
      if (!onboarded) {
        onboarded = await repo.getBool('onboarded') ?? false;
      }
      final isOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded && !isOnboarding) return '/onboarding';
      if (onboarded && isOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingHost(),
      ),
      GoRoute(
        path: '/pet/new',
        builder: (context, state) => const PetFormPage(),
      ),
      GoRoute(
        path: '/pet/:id',
        builder: (context, state) =>
            PetDetailPage(state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/pet/:id/edit',
        builder: (context, state) =>
            PetFormPage(existingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/health/record/new',
        builder: (context, state) => HealthRecordFormPage(
          initialType: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: '/health/record/:id/edit',
        builder: (context, state) => HealthRecordFormPage(
          existingId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarPage(),
      ),
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpensesPage(),
      ),
      GoRoute(
        path: '/moment/new',
        builder: (context, state) => const MomentFormPage(),
      ),
      GoRoute(
        path: '/moment/:id/detail',
        builder: (context, state) =>
            MomentDetailPage(momentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/moment/:id/edit',
        builder: (context, state) =>
            MomentFormPage(existingId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/diet/preferences',
        builder: (context, state) => const DietPreferencesPage(),
      ),
      GoRoute(
        path: '/expense/new',
        builder: (context, state) => const ExpenseFormPage(),
      ),
      GoRoute(
        path: '/expense/:id/edit',
        builder: (context, state) =>
            ExpenseFormPage(existingId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/ai/chat',
        builder: (context, state) => const AiChatPage(),
      ),
      GoRoute(
        path: '/ai/quick-add',
        builder: (context, state) => const AiQuickAddPage(),
      ),
      GoRoute(
        path: '/ai/weekly',
        builder: (context, state) => const WeeklyReportPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/settings/ai',
        builder: (context, state) => const AiSettingsPage(),
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (context, state) => const BackupPage(),
      ),
      GoRoute(
        path: '/settings/cloud',
        builder: (context, state) => const CloudPage(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => const AboutPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomePage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/health',
              builder: (context, state) => const HealthPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/diet',
              builder: (context, state) => const DietPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/timeline',
              builder: (context, state) => const TimelinePage(),
            ),
          ]),
        ],
      ),
    ],
  );
});
