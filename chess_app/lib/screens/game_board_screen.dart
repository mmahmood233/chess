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

  void _showGameOverDialog(String message, {bool returnToMenu = false}) {
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
              if (returnToMenu) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Text('OK'),
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
    
    print('Building GameBoardScreen - status: ${gameState.status}, endReason: ${gameState.endReason}');

    ref.listen<GameState>(gameStateProvider, (previous, next) {
      print('GameState listen triggered - prev: ${previous?.status}/${previous?.endReason}, next: ${next.status}/${next.endReason}');
      
      if (next.status == GameStatus.completed && previous?.status != GameStatus.completed) {
        print('Game completed detected!');
        String message = 'Game Over!';
        bool shouldReturnToMenu = false;
        
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
        } else if (next.endReason == 'opponent_left') {
          print('Opponent left detected! Showing dialog...');
          message = 'Your opponent has left the game. You win!';
          shouldReturnToMenu = true;
        }
        
        print('Showing game over dialog: $message');
        Future.delayed(const Duration(milliseconds: 500), () {
          print('Calling _showGameOverDialog');
          _showGameOverDialog(message, returnToMenu: shouldReturnToMenu);
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
                        Navigator.pop(context);
                        ref.read(gameStateProvider.notifier).leaveGame();
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
