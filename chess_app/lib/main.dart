/// main.dart — Application entry point.
///
/// Responsibilities:
///   1. Read (or generate) a persistent player UUID from SharedPreferences.
///      The UUID survives app restarts so the player keeps the same identity
///      across sessions.
///   2. Override [playerIdProvider] with the real UUID so every part of the
///      app that depends on the player's identity gets the correct value.
///   3. Mount the [ProviderScope] that powers Riverpod state management.
///   4. Expose a global [navigatorKey] used by [GameStateNotifier] to push
///      navigation events (e.g. game start) from outside the widget tree.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'providers/game_provider.dart';
import 'screens/main_menu_screen.dart';

/// Global navigator key — allows [GameStateNotifier] to navigate to the game
/// board from within the provider layer, outside of any widget's BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load or create a stable UUID for this player
  final prefs = await SharedPreferences.getInstance();
  String? playerId = prefs.getString('player_id');
  if (playerId == null) {
    playerId = const Uuid().v4();
    await prefs.setString('player_id', playerId);
  }

  runApp(
    ProviderScope(
      // Override the provider so every downstream consumer gets this UUID
      overrides: [
        playerIdProvider.overrideWith((ref) => playerId!),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Wire up the global key
      title: 'Chess',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainMenuScreen(),
    );
  }
}
