import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';

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
  bool _isWaiting = false;
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinWaiting();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    if (_isWaiting) {
      final status = ref.read(gameStateProvider).status;
      if (status != GameStatus.inProgress) {
        ref.read(gameStateProvider.notifier).leaveWaitingRoom();
      }
    }
    super.dispose();
  }

  Future<void> _joinWaiting() async {
    setState(() => _isWaiting = true);
    await ref.read(gameStateProvider.notifier).joinWaitingRoom();
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Find Game',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
              // Animated chess piece
              FadeTransition(
                opacity: _pulseAnim,
                child: ScaleTransition(
                  scale: _pulseAnim,
                  child: WhiteKnight(size: 80),
                ),
              ),
              const SizedBox(height: 40),

              // Spinner + text
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

              // Cancel button
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
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
