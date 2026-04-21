// game_provider.dart — Riverpod state management for the chess game.
//
// Providers defined here:
//   [playerIdProvider]     — The local player's UUID (overridden in main.dart).
//   [apiServiceProvider]   — Singleton [ApiService] instance.
//   [websocketServiceProvider] — Singleton [WebSocketService] instance.
//   [gameStateProvider]    — [GameStateNotifier] + [GameState].
//
// [GameStateNotifier] is the heart of the app's logic layer:
//   • Connects the WebSocket on construction and registers the player.
//   • Translates every incoming socket event into a state update.
//   • Handles navigation (game start) via the global [navigatorKey].
//   • Exposes public actions: joinWaitingRoom, invitePlayer, makeMove, etc.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../main.dart';
import '../screens/game_board_screen.dart';

/// The local player's UUID.  Overridden in main() with the value from
/// SharedPreferences so the same ID is used across app restarts.
final playerIdProvider = Provider<String>(
  (ref) => throw UnimplementedError('playerIdProvider must be overridden in main()'),
);

/// HTTP client — one instance shared across the app.
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// WebSocket client — one instance shared across the app.
/// Disposed automatically when the provider is removed from the tree.
final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Main state provider.  Exposes [GameState] and the [GameStateNotifier]
/// that drives all game-related actions.
final gameStateProvider =
    StateNotifierProvider<GameStateNotifier, GameState>(
  (ref) => GameStateNotifier(
    ref.watch(websocketServiceProvider),
    ref.watch(apiServiceProvider),
    ref.watch(playerIdProvider),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────

class GameStateNotifier extends StateNotifier<GameState> {
  final WebSocketService _wsService;
  final ApiService _apiService;
  final String _playerId;

  GameStateNotifier(this._wsService, this._apiService, this._playerId)
      : super(GameState()) {
    _initWebSocket();
  }

  /// Connects the socket, subscribes to the message stream, then waits for the
  /// connection to be ready before registering the player with the server.
  void _initWebSocket() async {
    _wsService.connect();
    _wsService.messages.listen(_handleWebSocketMessage);
    try {
      await _wsService.waitForConnection();
      _wsService.register(_playerId);
    } catch (_) {
      // Registration will be retried when the 'reconnected' event fires
    }
  }

  /// Dispatches every incoming WebSocket event to the appropriate handler.
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final event = message['event'] as String?;
    final data  = message['data']  as Map<String, dynamic>?;

    if (event == null) return;

    switch (event) {
      case 'reconnected':
        // Socket reconnected — re-register so the server maps the new socketId
        _wsService.register(_playerId);
        break;
      case 'gameStarted':
        if (data != null) _handleGameStarted(data);
        break;
      case 'moveMade':
        if (data != null) _handleMoveMade(data);
        break;
      case 'yourTurn':
        if (data != null) _handleYourTurn(data);
        break;
      case 'gameOver':
        if (data != null) _handleGameOver(data);
        break;
      case 'moveError':
        if (data != null) _handleMoveError(data);
        break;
      case 'opponentLeft':
        if (data != null) _handleOpponentLeft(data);
        break;
      case 'inviteReceived':
        if (data != null) _handleInviteReceived(data);
        break;
      case 'inviteDeclined':
        if (data != null) _handleInviteDeclined(data);
        break;
    }
  }

  // ── WebSocket event handlers ───────────────────────────────────────────────

  /// Handles both new game starts and reconnection resumes.
  /// Updates state with the server-provided FEN and current turn, then
  /// navigates to the game board (the single navigation source in the app).
  void _handleGameStarted(Map<String, dynamic> data) {
    final gameId       = data['gameId']       as String;
    final whitePlayerId = data['whitePlayerId'] as String;
    final blackPlayerId = data['blackPlayerId'] as String;
    // Server sends the current FEN — critical for reconnection mid-game
    final fen = data['fen'] as String? ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    // Server sends whose turn it is — critical for reconnection
    final serverCurrentTurn =
        data['currentTurn'] as String? ?? whitePlayerId;

    final myColor =
        whitePlayerId == _playerId ? PlayerColor.white : PlayerColor.black;

    state = state.copyWith(
      gameId: gameId,
      whitePlayerId: whitePlayerId,
      blackPlayerId: blackPlayerId,
      currentTurn: serverCurrentTurn,
      status: GameStatus.inProgress,
      myColor: myColor,
      fen: fen,
    );

    // Join the Socket.io room so move broadcasts reach this socket
    _wsService.joinGame(gameId, _playerId);

    // Navigate from whatever screen is showing to the game board
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GameBoardScreen()),
      );
    }
  }

  /// A move has been confirmed by the server — update FEN and last-move squares.
  void _handleMoveMade(Map<String, dynamic> data) {
    final fen      = data['fen']      as String?;
    final pgn      = data['pgn']      as String?;
    final playerId = data['playerId'] as String?;

    // Extract from/to squares for the last-move highlight on the board
    final moveMap = data['move'];
    final lastFrom = moveMap is Map ? moveMap['from'] as String? : null;
    final lastTo   = moveMap is Map ? moveMap['to']   as String? : null;

    if (fen == null) return;

    if (playerId == _playerId) {
      // Our own move was confirmed — clear the turn flag
      state = state.copyWith(
        fen: fen,
        pgn: pgn ?? state.pgn,
        currentTurn: null,
        lastMoveFrom: lastFrom,
        lastMoveTo: lastTo,
      );
    } else {
      // Opponent's move — update the board; 'yourTurn' will follow if applicable
      state = state.copyWith(
        fen: fen,
        pgn: pgn ?? state.pgn,
        lastMoveFrom: lastFrom,
        lastMoveTo: lastTo,
      );
    }
  }

  /// Server signals that it is this player's turn — set currentTurn so
  /// [GameState.isMyTurn] becomes true and the board accepts input.
  void _handleYourTurn(Map<String, dynamic> data) {
    state = state.copyWith(currentTurn: _playerId);
  }

  /// Game has reached a terminal state — update status, winner, and reason.
  /// The [GameBoardScreen] listens for this transition and shows the dialog.
  void _handleGameOver(Map<String, dynamic> data) {
    state = state.copyWith(
      status: GameStatus.completed,
      winner: data['winner']    as String?,
      endReason: data['endReason'] as String?,
      currentTurn: null,
    );
  }

  /// Server rejected a move — show an error snackbar.
  void _handleMoveError(Map<String, dynamic> data) {
    final error = data['error'] as String? ?? 'Illegal move';
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Show the incoming invitation dialog so the player can accept or decline.
  void _handleInviteReceived(Map<String, dynamic> data) {
    final inviterId = data['inviterId'] as String;
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF272522),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports,
                  color: Color(0xFF769656), size: 44),
              const SizedBox(height: 16),
              const Text(
                'Game Invitation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A player wants to challenge you to a game!',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _apiService.declineInvite(inviterId, _playerId);
                      },
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF769656),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _apiService.acceptInvite(inviterId, _playerId);
                        // 'gameStarted' WebSocket event will trigger navigation
                      },
                      child: const Text('Accept'),
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

  /// Show a dialog informing the inviter that their invitation was declined.
  void _handleInviteDeclined(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF272522),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_outlined,
                  color: Colors.redAccent, size: 44),
              const SizedBox(height: 16),
              const Text(
                'Invitation Declined',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your opponent declined the challenge.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF769656),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opponent disconnected or resigned — this player wins.
  /// [GameBoardScreen] listens for the completed status and shows the dialog.
  void _handleOpponentLeft(Map<String, dynamic> data) {
    state = state.copyWith(
      status: GameStatus.completed,
      endReason: 'opponent_left',
      winner: _playerId,
      currentTurn: null,
    );
  }

  // ── Public actions ──────────────────────────────────────────────────────────

  /// Join the public matchmaking queue.
  /// Waits for the WebSocket to be connected first to ensure the 'gameStarted'
  /// event can be received when the server creates a match.
  Future<void> joinWaitingRoom() async {
    try {
      await _wsService.waitForConnection();
      final result = await _apiService.joinWaitingRoom(_playerId);
      final status = result['status'] as String;

      if (status == 'game_created') {
        // Immediate match — update state so WaitingRoomScreen can react.
        // Navigation still comes from _handleGameStarted via WebSocket.
        final gameId         = result['gameId']       as String;
        final whitePlayerId  = result['whitePlayerId'] as String;
        final blackPlayerId  = result['blackPlayerId'] as String;
        final yourColor      = result['yourColor']     as String;

        state = state.copyWith(
          gameId: gameId,
          whitePlayerId: whitePlayerId,
          blackPlayerId: blackPlayerId,
          currentTurn: whitePlayerId,
          status: GameStatus.inProgress,
          myColor:
              yourColor == 'white' ? PlayerColor.white : PlayerColor.black,
        );
        _wsService.joinGame(gameId, _playerId);
      }
      // status == 'waiting' — server will push 'gameStarted' when matched
    } catch (e) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connection error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  /// Send a direct invitation to [invitedPlayerId].
  /// Returns a result map with `success: true/false` so the UI can show
  /// an appropriate snackbar.
  Future<Map<String, dynamic>> invitePlayer(String invitedPlayerId) async {
    try {
      await _wsService.waitForConnection();
      final result = await _apiService.invitePlayer(_playerId, invitedPlayerId);
      final status = result['status'] as String;
      if (status == 'invitation_sent') {
        return {'success': true, 'message': 'Invitation sent! Waiting for response...'};
      }
      return {'success': false, 'error': 'Unknown response'};
    } catch (e) {
      return {'success': false, 'error': e.toString().replaceAll('Exception: ', '')};
    }
  }

  /// Leave the waiting room (e.g. user pressed Cancel).
  Future<void> leaveWaitingRoom() async {
    try {
      await _apiService.leaveWaitingRoom(_playerId);
    } catch (_) {}
  }

  /// Submit a chess move to the server for validation.
  /// Does nothing if there is no active game.
  void makeMove(String from, String to, {String? promotion}) {
    if (state.gameId == null) return;
    _wsService.makeMove(
      state.gameId!,
      _playerId,
      {
        'from': from,
        'to': to,
        if (promotion != null) 'promotion': promotion,
      },
    );
  }

  /// Resign the current game and return to the main menu.
  void leaveGame() {
    if (state.gameId != null) {
      _wsService.leaveGame(state.gameId!, _playerId);
    }
    resetGame();
  }

  /// Reset state to the initial idle state (no game).
  void resetGame() {
    state = GameState();
  }
}
