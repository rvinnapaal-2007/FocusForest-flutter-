import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'firebase_options.dart';
import 'models/forest_tree.dart';
import 'providers/study_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/ai_coach_screen.dart';
import 'screens/focus_forest_screen.dart';
import 'screens/programmer_hub_screen.dart';
import 'screens/progress_heatmap_screen.dart';
import 'widgets/forest_painters.dart';
import 'widgets/brand_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  runApp(const FocusForestApp());
}

class FocusForestApp extends StatelessWidget {
  const FocusForestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StudyProvider(),
      child: MaterialApp(
        title: '${AppConfig.appName} - AI Study Coach',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF10B981),
          scaffoldBackgroundColor: const Color(0xFF08150F),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF10B981),
            secondary: Color(0xFF38BDF8),
            surface: Color(0xFF102A20),
          ),
          fontFamily: 'Roboto',
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Chooses between splash, login and the app depending on the Firebase session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<StudyProvider, AuthStatus>((p) => p.authStatus);
    switch (status) {
      case AuthStatus.initializing:
      case AuthStatus.loadingData:
        return const _SplashScreen();
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.ready:
        return const MainNavigationShell();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ForestBackdrop(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GrowingTree(species: TreeSpecies.pine, height: 200),
              const SizedBox(height: 8),
              const FocusForestLogo(height: 52),
              const SizedBox(height: 6),
              Text('Growing your forest...', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _onTabChange(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    // If the focus session was cancelled because the user left the app
    // (YouTube, WhatsApp, Instagram, another browser tab...), tell them.
    final leftNotice = context.select<StudyProvider, bool>((p) => p.leftAppNotice);
    if (leftNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final provider = context.read<StudyProvider>();
        if (!provider.consumeLeftAppNotice()) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            backgroundColor: Color(0xFF7F1D1D),
            duration: Duration(seconds: 6),
            content: Text('You left the app during your focus session - your tree withered 🥀. Stay in the app to grow it!'),
          ));
      });
    }
    final fullscreenLost = context.select<StudyProvider, bool>((p) => p.fullscreenLost);
    final screens = [
      HomeDashboardScreen(onTabChange: _onTabChange),
      const AiCoachScreen(),
      const FocusForestScreen(),
      const ProgrammerHubScreen(),
      const ProgressHeatmapScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          if (fullscreenLost)
            Material(
              color: const Color(0xFF7F1D1D),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('You left full screen! Return within 10 seconds or your tree withers 🥀',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => context.read<StudyProvider>().returnToFocus(),
                        child: const Text('Return'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                for (var i = 0; i < screens.length; i++)
                  TickerMode(enabled: i == _currentIndex, child: screens[i]),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B1F17),
          border: Border(top: BorderSide(color: Color(0x3310B981), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabChange,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF0B1F17),
          selectedItemColor: const Color(0xFF34D399),
          selectedFontSize: 11,
          unselectedFontSize: 10,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.psychology_rounded), label: 'AI Coach'),
            BottomNavigationBarItem(icon: Icon(Icons.forest_rounded), label: 'Focus Forest'),
            BottomNavigationBarItem(icon: Icon(Icons.code_rounded), label: 'Coders Hub'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Heatmap'),
          ],
        ),
      ),
    );
  }
}
