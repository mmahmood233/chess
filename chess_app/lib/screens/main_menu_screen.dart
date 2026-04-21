// main_menu_screen.dart — App entry screen.
//
// Shows three sections:
//   • A hero banner with chess piece artwork.
//   • Two game-mode cards: "Play Online" (waiting room) and "Play a Friend"
//     (direct invite by Player ID).
//   • A Player ID card that lets the user copy their UUID to share with friends.
//
// This screen also watches [gameStateProvider] so the [GameStateNotifier] is
// constructed immediately on app launch — which connects the WebSocket and
// registers the player.  Without this, a player sitting on the main menu
// would never receive friend invitations because their socket would not be
// registered with the server.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import '../providers/game_provider.dart';
import 'waiting_room_screen.dart';

// ── Chess.com dark palette ────────────────────────────────────────────────────
const _bgDark    = Color(0xFF312E2B);
const _panelDark = Color(0xFF272522);
const _green     = Color(0xFF769656);
const _textMain  = Color(0xFFFFFFFF);
const _textDim   = Color(0xFF999999);

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerId = ref.watch(playerIdProvider);

    // Eagerly initialise the game notifier so the WebSocket connects and
    // registers this player on app launch.  Required for invite reception.
    ref.watch(gameStateProvider);

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Container(
              color: _panelDark,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  BlackKnight(size: 32),
                  const SizedBox(width: 10),
                  const Text(
                    'Chess',
                    style: TextStyle(
                      color: _textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable content ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    // Decorative banner with piece art and tagline
                    _HeroBanner(),

                    const SizedBox(height: 24),

                    // Public matchmaking
                    _GameCard(
                      icon: Icons.public,
                      title: 'Play Online',
                      subtitle: 'Random opponent · Real-time',
                      color: _green,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WaitingRoomScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Direct friend challenge
                    _GameCard(
                      icon: Icons.person_add_outlined,
                      title: 'Play a Friend',
                      subtitle: 'Challenge with their Player ID',
                      color: const Color(0xFF4A90D9),
                      onTap: () => _showInviteDialog(context, ref),
                    ),

                    const SizedBox(height: 28),

                    // Tappable card showing and allowing copy of this player's UUID
                    _PlayerIdCard(
                      playerId: playerId,
                      onTap: () => _showIdDialog(context, playerId),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  /// Shows the player's UUID in a selectable text field with a Copy button.
  void _showIdDialog(BuildContext context, String playerId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Player ID',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Share this so friends can invite you.',
                style: TextStyle(color: _textDim, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1C1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  playerId,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textMain,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: playerId));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Player ID copied!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
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

  /// Shows a text field where the user can enter a friend's Player ID and
  /// send them a game invitation.
  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _panelDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Challenge a Friend',
                style: TextStyle(
                  color: _textMain,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Enter your friend's Player ID.",
                style: TextStyle(color: _textDim, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: _textMain),
                decoration: InputDecoration(
                  hintText: 'Player ID',
                  hintStyle: const TextStyle(color: _textDim),
                  filled: true,
                  fillColor: const Color(0xFF1E1C1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textMain,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final id = ctrl.text.trim();
                        if (id.isEmpty) return;
                        Navigator.pop(ctx);
                        // Send invite via notifier; show result as a snackbar
                        final result = await ref
                            .read(gameStateProvider.notifier)
                            .invitePlayer(id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['success'] == true
                                    ? (result['message'] as String? ??
                                        'Invitation sent!')
                                    : 'Error: ${result['error']}',
                              ),
                              backgroundColor: result['success'] == true
                                  ? _green
                                  : Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                      child: const Text('Send'),
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

// ── Hero banner ───────────────────────────────────────────────────────────────

/// Decorative panel at the top of the menu showing SVG chess pieces and a
/// short description of the app.
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panelDark,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          // 2×2 grid of piece icons (white & black knight + queen)
          Column(
            children: [
              Row(children: [
                WhiteKnight(size: 40),
                const SizedBox(width: 4),
                WhiteQueen(size: 40),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                BlackKnight(size: 40),
                const SizedBox(width: 4),
                BlackQueen(size: 40),
              ]),
            ],
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Play Chess',
                  style: TextStyle(
                    color: _textMain,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Challenge players around the world in real-time multiplayer chess.',
                  style: TextStyle(
                    color: _textDim,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Game mode card ─────────────────────────────────────────────────────────────

/// A tappable card that represents a single game mode (Play Online / Play a
/// Friend).  Renders a coloured background with an icon, title, and subtitle.
class _GameCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Player ID card ─────────────────────────────────────────────────────────────

/// Displays a truncated version of the player's UUID with a copy icon.
/// Tapping opens the full ID dialog.
class _PlayerIdCard extends StatelessWidget {
  final String playerId;
  final VoidCallback onTap;

  const _PlayerIdCard({required this.playerId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panelDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, color: _textDim, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Player ID',
                    style: TextStyle(
                      color: _textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playerId,
                    style: const TextStyle(
                      color: _textDim,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.copy, color: _textDim, size: 18),
          ],
        ),
      ),
    );
  }
}
