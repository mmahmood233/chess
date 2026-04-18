import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_state.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../main.dart';
import '../screens/game_board_screen.dart';

/// Overridden in main() with a persistent UUID from SharedPreferences.
final playerIdProvider = Provider<String>((ref) => throw UnimplementedError('playerIdProvider must be overridden in main()'));

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>(
  (ref) => GameStateNotifier(
    ref.watch(websocketServiceProvider),
    ref.watch(apiServiceProvider),
    ref.watch(playerIdProvider),
  ),
);

class GameStateNotifier extends StateNotifier<GameState> {
  final WebSocketService _wsService;
  final ApiService _apiService;
  final String _playerId;

  GameStateNotifier(this._wsService, this._apiService, this._playerId)
      : super(GameState()) {
    _initWebSocket();
  }

  void _initWebSocket() async {
    _wsService.connect();
    _wsService.messages.listen(_handleWebSocketMessage);
    try {
      await _wsService.waitForConnection();
      _wsService.register(_playerId);
    } catch (_) {
      // Will retry on reconnect event
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final event = message['event'] as String?;
    final data = message['data'] as Map<String, dynamic>?;

    if (event == null) return;

    switch (event) {
      case 'reconnected':
        // Re-register after reconnect so server knows our socket again
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

  void _handleGameStarted(Map<String, dynamic> data) {
    final gameId = data['gameId'] as String;
    final whitePlayerId = data['whitePlayerId'] as String;
    final blackPlayerId = data['blackPlayerId'] as String;
    // Server sends current FEN (especially important for reconnections)
    final fen = data['fen'] as String? ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    // Server sends who has the current turn (important for reconnections)
    final serverCurrentTurn = data['currentTurn'] as String? ?? whitePlayerId;

    final myColor = whitePlayerId == _playerId
        ? PlayerColor.white
        : PlayerColor.black;

    state = state.copyWith(
      gameId: gameId,
      whitePlayerId: whitePlayerId,
      blackPlayerId: blackPlayerId,
      currentTurn: serverCurrentTurn,
      status: GameStatus.inProgress,
      myColor: myColor,
      fen: fen,
    );

    _wsService.joinGame(gameId, _playerId);

    // Navigate to game board from any screen
    final context = navigatorKey.currentContext;
    if (context != null) {
      // Pop everything back to root (main menu), then push game board
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GameBoardScreen()),
      );
    }
  }

  void _handleMoveMade(Map<String, dynamic> data) {
    final fen = data['fen'] as String?;
    final pgn = data['pgn'] as String?;
    final playerId = data['playerId'] as String?;

    if (fen == null) return;

    if (playerId == _playerId) {
      // Our move was confirmed — clear turn indicator; server will send yourTurn to opponent
      state = state.copyWith(
        fen: fen,
        pgn: pgn ?? state.pgn,
        currentTurn: null,
      );
    } else {
      // Opponent made a move — update board; we'll get yourTurn if it's now our go
      state = state.copyWith(fen: fen, pgn: pgn ?? state.pgn);
    }
  }

  void _handleYourTurn(Map<String, dynamic> data) {
    // Server tells us it's our turn — set currentTurn to our ID so isMyTurn becomes true
    state = state.copyWith(currentTurn: _playerId);
  }

  void _handleGameOver(Map<String, dynamic> data) {
    state = state.copyWith(
      status: GameStatus.completed,
      winner: data['winner'] as String?,
      endReason: data['endReason'] as String?,
      currentTurn: null,
    );
  }

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

  void _handleInviteReceived(Map<String, dynamic> data) {
    final inviterId = data['inviterId'] as String;
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Game Invitation'),
        content: const Text('A player wants to challenge you to a game. Accept?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _apiService.declineInvite(inviterId, _playerId);
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _apiService.acceptInvite(inviterId, _playerId);
              // gameStarted WS event will handle navigation
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _handleInviteDeclined(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invitation Declined'),
        content: const Text('Your invitation was declined.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleOpponentLeft(Map<String, dynamic> data) {
    state = state.copyWith(
      status: GameStatus.completed,
      endReason: 'opponent_left',
      winner: _playerId,
      currentTurn: null,
    );
    // The GameBoardScreen's ref.listen picks this up and shows the dialog
  }

  // ── Public actions ──────────────────────────────────────────────────────────

  Future<void> joinWaitingRoom() async {
    try {
      await _wsService.waitForConnection();
      final result = await _apiService.joinWaitingRoom(_playerId);
      final status = result['status'] as String;

      if (status == 'game_created') {
        // Game was created immediately (we were matched with a waiting player).
        // The server also emits gameStarted via WebSocket — that handler
        // will update state and navigate. We just ensure we're in the room.
        final gameId = result['gameId'] as String;
        final whitePlayerId = result['whitePlayerId'] as String;
        final blackPlayerId = result['blackPlayerId'] as String;
        final yourColor = result['yourColor'] as String;

        state = state.copyWith(
          gameId: gameId,
          whitePlayerId: whitePlayerId,
          blackPlayerId: blackPlayerId,
          currentTurn: whitePlayerId,
          status: GameStatus.inProgress,
          myColor: yourColor == 'white' ? PlayerColor.white : PlayerColor.black,
        );
        _wsService.joinGame(gameId, _playerId);
      }
      // status == 'waiting' → just sit tight; server will emit gameStarted when matched
    } catch (e) {
      // Show error if waiting room call fails
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

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

  Future<void> leaveWaitingRoom() async {
    try {
      await _apiService.leaveWaitingRoom(_playerId);
    } catch (_) {}
  }

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

  void leaveGame() {
    if (state.gameId != null) {
      _wsService.leaveGame(state.gameId!, _playerId);
    }
    resetGame();
  }

  void resetGame() {
    state = GameState();
  }
}
