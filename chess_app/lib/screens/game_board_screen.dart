import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../widgets/custom_chess_board.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  const GameBoardScreen({super.key});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  bool _gameOverShown = false;

  void _onMove(String from, String to, {String? promotion}) {
    ref.read(gameStateProvider.notifier).makeMove(from, to, promotion: promotion);
  }

  void _showGameOverDialog(BuildContext context, String title, String message,
      {bool returnToMenu = false}) {
    if (_gameOverShown) return;
    _gameOverShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(gameStateProvider.notifier).resetGame();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final notifier = ref.read(gameStateProvider.notifier);

    ref.listen<GameState>(gameStateProvider, (previous, next) {
      if (!mounted) return;
      if (next.status == GameStatus.completed &&
          previous?.status != GameStatus.completed) {
        _resolveGameOver(context, next);
      }

      // "Your turn" snackbar — only show when turn flips TO us
      if (previous?.isMyTurn == false && next.isMyTurn == true) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your turn!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    final isMyTurn = gameState.isMyTurn;
    final myColor = gameState.myColor ?? PlayerColor.white;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Chess'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Leave game',
            onPressed: () => _confirmLeave(context, notifier),
          ),
        ],
      ),
      body: Column(
        children: [
          // Turn banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            color: isMyTurn ? Colors.green.shade700 : Colors.blueGrey.shade700,
            child: Column(
              children: [
                Text(
                  isMyTurn ? 'Your Turn' : "Opponent's Turn",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: myColor == PlayerColor.white
                            ? Colors.white
                            : Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Playing as ${myColor == PlayerColor.white ? 'White' : 'Black'}',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Board
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: CustomChessBoard(
                  fen: gameState.fen,
                  onMove: _onMove,
                  isWhite: myColor == PlayerColor.white,
                  isMyTurn: isMyTurn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resolveGameOver(BuildContext context, GameState state) {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      final endReason = state.endReason ?? '';
      String title;
      String message;

      switch (endReason) {
        case 'checkmate':
          final myPlayerId = state.myColor == PlayerColor.white
              ? state.whitePlayerId
              : state.blackPlayerId;
          final didIWin = state.winner == myPlayerId;
          title = didIWin ? 'You Win! 🏆' : 'You Lose';
          message = didIWin
              ? 'Congratulations! You won by checkmate!'
              : 'You were checkmated. Better luck next time!';
          break;
        case 'stalemate':
          title = 'Draw';
          message = 'The game ended in a stalemate.';
          break;
        case 'draw':
          title = 'Draw';
          message = 'The game ended in a draw.';
          break;
        case 'threefold_repetition':
          title = 'Draw';
          message = 'Draw by threefold repetition.';
          break;
        case 'insufficient_material':
          title = 'Draw';
          message = 'Draw by insufficient material.';
          break;
        case 'opponent_left':
          title = 'Opponent Left';
          message = 'Your opponent left the game. You win!';
          break;
        default:
          title = 'Game Over';
          message = 'The game has ended.';
      }

      _showGameOverDialog(context, title, message, returnToMenu: true);
    });
  }

  void _confirmLeave(BuildContext context, GameStateNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Game'),
        content: const Text(
            'Are you sure you want to resign? Your opponent will win.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.leaveGame();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
