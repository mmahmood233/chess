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
  void _onMove(String from, String to, {String? promotion}) {
    ref.read(gameStateProvider.notifier).makeMove(from, to, promotion: promotion);
  }

  void _showGameOverDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(gameStateProvider.notifier).resetGame();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Back to Menu'),
          ),
        ],
      ),
    );
  }

  void _showTurnNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your turn!'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);

    ref.listen<GameState>(gameStateProvider, (previous, next) {
      if (next.status == GameStatus.completed) {
        String message = 'Game Over!';
        if (next.endReason == 'checkmate') {
          final didIWin = next.winner == 
              (next.myColor == PlayerColor.white ? next.whitePlayerId : next.blackPlayerId);
          message = didIWin ? 'You won by checkmate!' : 'You lost by checkmate!';
        } else if (next.endReason == 'stalemate') {
          message = 'Draw by stalemate!';
        } else if (next.endReason == 'draw') {
          message = 'Draw!';
        } else if (next.endReason == 'threefold_repetition') {
          message = 'Draw by threefold repetition!';
        } else if (next.endReason == 'insufficient_material') {
          message = 'Draw by insufficient material!';
        }
        
        Future.delayed(const Duration(milliseconds: 500), () {
          _showGameOverDialog(message);
        });
      }

      if (previous?.isMyTurn == false && next.isMyTurn == true) {
        _showTurnNotification();
      }
    });

    final isMyTurn = gameState.isMyTurn;
    final myColor = gameState.myColor ?? PlayerColor.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Game'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Leave Game'),
                  content: const Text('Are you sure you want to leave?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(gameStateProvider.notifier).resetGame();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text('Leave'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isMyTurn ? Colors.green.shade100 : Colors.grey.shade200,
            child: Column(
              children: [
                Text(
                  isMyTurn ? 'Your Turn' : 'Opponent\'s Turn',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isMyTurn ? Colors.green.shade900 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are playing as ${myColor == PlayerColor.white ? 'White' : 'Black'}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
}
