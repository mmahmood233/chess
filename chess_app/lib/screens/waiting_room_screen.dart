// waiting_room_screen.dart — Public matchmaking / waiting room UI.
//
// Shown when the player taps "Play Online".  Immediately joins the server's
// waiting queue on mount.  When a match is found the server pushes a
// 'gameStarted' WebSocket event which [GameStateNotifier._handleGameStarted]
// handles — it navigates to [GameBoardScreen] automatically.
//
// The screen animates a pulsing chess knight while waiting and provides a
// Cancel button that leaves the queue and pops the screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';

// ── Chess.com dark palette ────────────────────────────────────────────────────
const _bgDark    = Color(0xFF312E2B);
const _panelDark = Color(0xFF272522);
const _green     = Color(0xFF769656);

class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  /// Whether this player is actively in the waiting queue.
  bool _isWaiting = false;

  /// Controls the pulsing animation on the chess knight icon.
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Pulse the knight between 70 % and 100 % opacity/scale, looping
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    // Join the waiting room after the first frame so the widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinWaiting();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    // Leave the queue only if a game has NOT started; if a game is in progress
    // we must not remove the player from the room.
    if (_isWaiting) {
      final status = ref.read(gameStateProvider).status;
      if (status != GameStatus.inProgress) {
        ref.read(gameStateProvider.notifier).leaveWaitingRoom();
      }
    }
    super.dispose();
  }

  /// Calls [GameStateNotifier.joinWaitingRoom] and marks us as waiting.
  Future<void> _joinWaiting() async {
    setState(() => _isWaiting = true);
    await ref.read(gameStateProvider.notifier).joinWaitingRoom();
  }

  @override
  Widget build(BuildContext context) {
    // When the game starts the notifier navigates away automatically via
    // navigatorKey.  We just clear _isWaiting here so dispose() skips
    // the redundant leaveWaitingRoom call.
    ref.listen<GameState>(gameStateProvider, (prev, next) {
      if (next.status == GameStatus.inProgress && next.gameId != null) {
        if (mounted) setState(() => _isWaiting = false);
      }
    });

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _panelDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Find Game',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() => _isWaiting = false);
            ref.read(gameStateProvider.notifier).leaveWaitingRoom();
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing knight — visual feedback that we are searching
              FadeTransition(
                opacity: _pulseAnim,
                child: ScaleTransition(
                  scale: _pulseAnim,
                  child: WhiteKnight(size: 80),
                ),
              ),
              const SizedBox(height: 40),

              // Spinner + searching label
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: _green,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: 14),
                  Text(
                    'Searching for an opponent…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'We\'ll pair you with another player shortly.',
                style: TextStyle(color: Colors.white38, fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 56),

              // Cancel — leave queue and go back to the main menu
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white60,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    setState(() => _isWaiting = false);
                    ref.read(gameStateProvider.notifier).leaveWaitingRoom();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
