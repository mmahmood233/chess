import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  bool _isWaiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinWaitingRoom();
    });
  }

  Future<void> _joinWaitingRoom() async {
    setState(() => _isWaiting = true);
    await ref.read(gameStateProvider.notifier).joinWaitingRoom();
  }

  @override
  void dispose() {
    // Only leave waiting room on dispose if we're still actively waiting
    // and the game hasn't started. If game started, we were already removed
    // from the waiting list by the server.
    if (_isWaiting) {
      final gameStatus = ref.read(gameStateProvider).status;
      if (gameStatus != GameStatus.inProgress) {
        ref.read(gameStateProvider.notifier).leaveWaitingRoom();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When the game starts the provider navigates via navigatorKey (popUntil + push).
    // We only need to track _isWaiting so dispose doesn't double-call leave.
    ref.listen<GameState>(gameStateProvider, (previous, next) {
      if (next.status == GameStatus.inProgress && next.gameId != null) {
        if (mounted) setState(() => _isWaiting = false);
        // Navigation is handled by the provider's _handleGameStarted.
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Room'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.purple.shade900,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Searching for opponent...',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please wait while we find you a match',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _isWaiting = false);
                      ref.read(gameStateProvider.notifier).leaveWaitingRoom();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
