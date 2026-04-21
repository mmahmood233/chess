// game_board_screen.dart — In-game screen showing the chess board and player panels.
//
// Layout (top → bottom):
//   • Opponent panel — shows their colour, highlights when it's their turn.
//   • [CustomChessBoard] — interactive board, takes all remaining vertical space.
//   • Player panel     — shows our colour, highlights when it's our turn.
//
// The screen listens to [gameStateProvider] for two state transitions:
//   • status → completed  → shows the game-over dialog.
//   • isMyTurn → true     → shows a "Your turn!" snackbar.
//
// Navigation back to the main menu happens from the game-over dialog or the
// resign confirmation dialog — both call [GameStateNotifier.resetGame] and
// then [Navigator.popUntil(isFirst)].
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../widgets/custom_chess_board.dart';

// ── Chess.com dark palette ────────────────────────────────────────────────────
const _bgDark    = Color(0xFF312E2B);
const _panelDark = Color(0xFF272522);
const _green     = Color(0xFF769656);

class GameBoardScreen extends ConsumerStatefulWidget {
  const GameBoardScreen({super.key});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  /// Guards against showing the game-over dialog more than once.
  bool _gameOverShown = false;

  /// Forwards tap events from [CustomChessBoard] to the notifier.
  void _onMove(String from, String to, {String? promotion}) {
    ref
        .read(gameStateProvider.notifier)
        .makeMove(from, to, promotion: promotion);
  }

  @override
  Widget build(BuildContext context) {
    final gs       = ref.watch(gameStateProvider);
    final notifier = ref.read(gameStateProvider.notifier);
    final isMyTurn = gs.isMyTurn;
    final myColor  = gs.myColor ?? PlayerColor.white;
    final amWhite  = myColor == PlayerColor.white;

    // Listen for state transitions that require UI side-effects
    ref.listen<GameState>(gameStateProvider, (prev, next) {
      if (!mounted) return;

      // Game over — show result dialog once
      if (next.status == GameStatus.completed &&
          prev?.status != GameStatus.completed) {
        _showGameOver(context, next);
      }

      // Turn changed to ours — show a brief snackbar prompt
      if (prev?.isMyTurn == false && next.isMyTurn == true) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.timer, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Your turn!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    // Opponent is always rendered at the top; we are at the bottom.
    // The board is flipped automatically for black by CustomChessBoard.
    final opponentColor =
        amWhite ? PlayerColor.black : PlayerColor.white;

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _panelDark,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Chess',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        actions: [
          // Resign button — prompts for confirmation before abandoning the game
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Resign',
            onPressed: () => _confirmLeave(context, notifier),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Opponent panel ─────────────────────────────────────────────────
          _PlayerPanel(
            color: opponentColor,
            label: 'Opponent',
            isTurn: !isMyTurn && gs.status == GameStatus.inProgress,
          ),

          // ── Board ──────────────────────────────────────────────────────────
          Expanded(
            child: Container(
              color: _bgDark,
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: CustomChessBoard(
                fen: gs.fen,
                onMove: _onMove,
                isWhite: amWhite,
                isMyTurn: isMyTurn,
                lastMoveFrom: gs.lastMoveFrom,
                lastMoveTo: gs.lastMoveTo,
              ),
            ),
          ),

          // ── Player panel ───────────────────────────────────────────────────
          _PlayerPanel(
            color: myColor,
            label: 'You',
            isTurn: isMyTurn && gs.status == GameStatus.inProgress,
          ),
        ],
      ),
    );
  }

  /// Displays a modal dialog with the game result.
  /// Called once when [GameState.status] transitions to [GameStatus.completed].
  void _showGameOver(BuildContext context, GameState gs) {
    if (_gameOverShown) return;
    _gameOverShown = true;

    // Short delay so the last move animation finishes before the dialog appears
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      final myId = gs.myColor == PlayerColor.white
          ? gs.whitePlayerId
          : gs.blackPlayerId;
      final didIWin = gs.winner != null && gs.winner == myId;

      // Determine display strings and colours based on the end reason
      String title;
      String subtitle;
      Color titleColor;
      IconData icon;

      switch (gs.endReason) {
        case 'checkmate':
          title      = didIWin ? 'You Win!'  : 'You Lose';
          subtitle   = didIWin ? 'Victory by checkmate' : 'Checkmated';
          titleColor = didIWin ? _green : Colors.red.shade400;
          icon       = didIWin ? Icons.emoji_events : Icons.sentiment_dissatisfied;
          break;
        case 'stalemate':
          title = 'Draw'; subtitle = 'Stalemate';
          titleColor = Colors.orange; icon = Icons.handshake_outlined;
          break;
        case 'draw':
          title = 'Draw'; subtitle = 'Agreement';
          titleColor = Colors.orange; icon = Icons.handshake_outlined;
          break;
        case 'threefold_repetition':
          title = 'Draw'; subtitle = 'Threefold repetition';
          titleColor = Colors.orange; icon = Icons.handshake_outlined;
          break;
        case 'insufficient_material':
          title = 'Draw'; subtitle = 'Insufficient material';
          titleColor = Colors.orange; icon = Icons.handshake_outlined;
          break;
        case 'opponent_left':
          title = 'You Win!'; subtitle = 'Opponent resigned';
          titleColor = _green; icon = Icons.emoji_events;
          break;
        default:
          title = 'Game Over'; subtitle = '';
          titleColor = Colors.white; icon = Icons.sports_esports;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        builder: (ctx) => Dialog(
          backgroundColor: _panelDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: titleColor),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 16, color: Colors.white60),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ref.read(gameStateProvider.notifier).resetGame();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: const Text(
                      'Back to Menu',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Asks the player to confirm before resigning.
  void _confirmLeave(BuildContext context, GameStateNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _panelDark,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag, color: Colors.white60, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Resign?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your opponent will win the game.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        notifier.leaveGame();
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                      child: const Text('Resign'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Player panel widget ────────────────────────────────────────────────────────

/// Horizontal strip showing a king icon, the player label ("You" / "Opponent"),
/// their colour, and an animated "Your Turn" badge when it is their move.
class _PlayerPanel extends StatelessWidget {
  final PlayerColor color;
  final String label;

  /// Whether this panel's player is currently expected to move.
  final bool isTurn;

  const _PlayerPanel({
    required this.color,
    required this.label,
    required this.isTurn,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = color == PlayerColor.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isTurn ? const Color(0xFF3D3A37) : _panelDark,
        // Green left border when it is this player's turn
        border: isTurn
            ? const Border(left: BorderSide(color: _green, width: 3))
            : null,
      ),
      child: Row(
        children: [
          // King icon representing this player's colour
          SizedBox(
            width: 36,
            height: 36,
            child: isWhite ? WhiteKing(size: 32) : BlackKing(size: 32),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isTurn ? Colors.white : Colors.white54,
                  fontSize: 15,
                  fontWeight:
                      isTurn ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                isWhite ? 'White' : 'Black',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          // "Your Turn" badge — only shown for the active player
          if (isTurn)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Your Turn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
