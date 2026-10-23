import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/word_bank.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/gs_colors.dart';
import 'core/utils/ethiopic_calendar.dart';
import 'data/progress.dart';
import 'data/settings.dart';
import 'services/reminders.dart';
import 'screens/board/board_screen.dart';
import 'screens/daily/daily_screens.dart';
import 'screens/home/home_screen.dart';
import 'screens/learn/learn_screens.dart';
import 'screens/learn/lessons.dart';
import 'screens/misc/misc_screens.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/packs/packs_screens.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/stats/stats_screens.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(WidgetRef ref) => GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/splash',
      redirect: (context, state) {
        final loc = state.matchedLocation;
        if (loc == '/splash') return null;
        final onboarded = ref.read(settingsProvider).onboarded;
        if (!onboarded && loc != '/welcome') return '/welcome';
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/welcome', builder: (_, __) => const OnboardingScreen()),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _MainShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const HomeScreen(),
                routes: [
                  GoRoute(path: 'packs', builder: (_, __) => const PacksScreen()),
                  GoRoute(
                    path: 'packs/:theme',
                    builder: (_, s) => PackDetailScreen(
                      theme: WordTheme.values.byName(s.pathParameters['theme']!),
                    ),
                  ),
                  GoRoute(
                      path: 'collection',
                      builder: (_, __) => const CollectionScreen(),
                      routes: [
                        GoRoute(
                          path: ':wordId',
                          builder: (_, s) =>
                              WordDetailScreen(wordId: s.pathParameters['wordId']!),
                        ),
                      ]),
                  GoRoute(path: 'learn', builder: (_, __) => const LearnScreen()),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/daily',
                builder: (_, __) => const DailyCalendarScreen(),
                routes: [
                  GoRoute(path: 'trophies', builder: (_, __) => const TrophyCabinetScreen()),
                  GoRoute(path: 'today', builder: (_, __) => const DailyDoneScreen()),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/stats',
                builder: (_, __) => const StatsScreen(),
                routes: [
                  GoRoute(
                      path: 'achievements',
                      builder: (_, __) => const AchievementsScreen()),
                ],
              ),
            ]),
          ],
        ),
        GoRoute(
          path: '/play',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => BoardScreen(
            args: s.extra as PlayArgs? ?? const PlayArgs.resume(),
          ),
        ),
        GoRoute(
          path: '/lesson/:id',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => LessonScreen(lesson: lessonById(s.pathParameters['id']!)!),
          routes: [
            GoRoute(
              path: 'quiz',
              parentNavigatorKey: _rootKey,
              builder: (_, s) => QuizScreen(lesson: lessonById(s.pathParameters['id']!)!),
            ),
            GoRoute(
              path: 'done',
              parentNavigatorKey: _rootKey,
              builder: (_, s) =>
                  LessonCompleteScreen(lesson: lessonById(s.pathParameters['id']!)!),
            ),
          ],
        ),
        GoRoute(
            path: '/classic',
            parentNavigatorKey: _rootKey,
            builder: (_, __) => const ClassicSetupScreen()),
        GoRoute(
          path: '/settings',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const GameplaySettingsScreen(),
          routes: [
            GoRoute(
                path: 'appearance',
                parentNavigatorKey: _rootKey,
                builder: (_, __) => const AppearanceSettingsScreen()),
          ],
        ),
        GoRoute(
            path: '/shop',
            parentNavigatorKey: _rootKey,
            builder: (_, __) => const ShopScreen()),
        GoRoute(
            path: '/help',
            parentNavigatorKey: _rootKey,
            builder: (_, __) => const HowToPlayScreen()),
        GoRoute(
          path: '/report/:wordId',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => ReportWordScreen(wordId: s.pathParameters['wordId']!),
        ),
        GoRoute(
          path: '/legal/:kind',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => LegalScreen(kind: s.pathParameters['kind']!),
        ),
      ],
    );

class _MainShell extends StatelessWidget {
  const _MainShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Main'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Daily'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Statistics'),
        ],
      ),
    );
  }
}

class GeezSudokuApp extends ConsumerStatefulWidget {
  const GeezSudokuApp({super.key});

  @override
  ConsumerState<GeezSudokuApp> createState() => _GeezSudokuAppState();
}

class _GeezSudokuAppState extends ConsumerState<GeezSudokuApp> {
  late final GoRouter _router = buildRouter(ref);

  void _syncReminder() {
    final enabled = ref.read(settingsProvider).dailyReminder;
    final solved = ref.read(progressProvider).daily.containsKey(dayKey(DateTime.now()));
    Reminders.sync(enabled: enabled, solvedToday: solved);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReminder());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.dailyReminder), (prev, on) {
      if (on && prev == false) Reminders.requestPermission();
      _syncReminder();
    });
    ref.listen(progressProvider.select((p) => p.daily.length), (_, __) => _syncReminder());
    final mode = ref.watch(settingsProvider.select((s) => s.theme));
    final colors = switch (mode) {
      GsThemeMode.dark => GsColors.dark,
      GsThemeMode.parchment => GsColors.parchment,
      _ => GsColors.light,
    };
    return MaterialApp.router(
      title: 'Ge’ez Sudoku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(colors),
      darkTheme: AppTheme.build(GsColors.dark),
      themeMode: mode == GsThemeMode.system ? ThemeMode.system : ThemeMode.light,
      routerConfig: _router,
    );
  }
}
