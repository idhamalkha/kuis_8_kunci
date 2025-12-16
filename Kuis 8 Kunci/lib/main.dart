/// Main App Entry Point

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/quiz_provider.dart';
import 'services/storage_service.dart';
import 'services/backend_service.dart';
import 'screens/home_screen.dart';
import 'pages/create_room.dart';
import 'pages/join_room.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase if configured and enabled
  if (AppConfig.useSupabase) {
    if (!AppConfig.hasSupabaseCredentials) {
      // Credentials not provided; log warning and fall back to non-supabase mode
      // (Keep useSupabase true so app continues to use supabase-aware codepaths,
      // but Supabase will not be initialized which may cause runtime errors.)
      // You should provide --dart-define=SUPABASE_URL=... and SUPABASE_ANON_KEY=...
      // when running or building the app.
      // We still initialize StorageService below.
    } else {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    }
  } else {
    // Start backend server (Android only) when not using Supabase
    await BackendService.startBackend();
  }

  // Initialize services
  await StorageService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => QuizProvider(),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        routes: {
          '/create': (_) => const CreateRoomPage(),
          '/join': (_) => const JoinRoomPage(),
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          textTheme: GoogleFonts.notoSansTextTheme(),
          // Global page transition to reduce flicker and create consistent
          // smooth fade + slight upward slide between pages.
          pageTransitionsTheme: PageTransitionsTheme(builders: {
            TargetPlatform.android: FadeSlidePageTransitionsBuilder(),
            TargetPlatform.iOS: FadeSlidePageTransitionsBuilder(),
            TargetPlatform.linux: FadeSlidePageTransitionsBuilder(),
            TargetPlatform.macOS: FadeSlidePageTransitionsBuilder(),
            TargetPlatform.windows: FadeSlidePageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadeSlidePageTransitionsBuilder(),
          }),
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Custom global transitions builder: subtle fade + slide for smoother page changes.
class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // When route is a PopupRoute (dialogs), keep default behavior.
    if (route.settings.name != null && route is PopupRoute) {
      return child;
    }

    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
