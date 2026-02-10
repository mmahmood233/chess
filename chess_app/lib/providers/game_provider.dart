import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/game_state.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

final playerIdProvider = StateProvider<String>((ref) => const Uuid().v4());

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

  void _initWebSocket() {
    _wsService.connect();
    _wsService.register(_playerId);

    _wsService.messages.listen((message) {
      _handleWebSocketMessage(message);
    });
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final event = message['event'] as String?;
    final data = message['data'] as Map<String, dynamic>?;

    if (event == null || data == null) return;

    switch (event) {
      case 'gameStarted':
        _handleGameStarted(data);
        break;
      case 'moveMade':
        _handleMoveMade(data);
        break;
      case 'yourTurn':
        _handleYourTurn(data);
        break;
      case 'gameOver':
        _handleGameOver(data);
        break;
      case 'moveError':
        _handleMoveError(data);
        break;
    }
  }

  void _handleGameStarted(Map<String, dynamic> data) {
    final gameId = data['gameId'] as String;
    final whitePlayerId = data['whitePlayerId'] as String;
    final blackPlayerId = data['blackPlayerId'] as String;

    final myColor = whitePlayerId == _playerId
        ? PlayerColor.white
        : PlayerColor.black;

    state = state.copyWith(
      gameId: gameId,
      whitePlayerId: whitePlayerId,
      blackPlayerId: blackPlayerId,
      currentTurn: whitePlayerId,
      status: GameStatus.inProgress,
      myColor: myColor,
    );

    _wsService.joinGame(gameId, _playerId);
  }

  void _handleMoveMade(Map<String, dynamic> data) {
    final fen = data['fen'] as String?;
    final pgn = data['pgn'] as String?;
    final playerId = data['playerId'] as String?;

    if (fen != null) {
      // If the move was made by us, clear our turn (opponent's turn now)
      // If the move was made by opponent, keep currentTurn as is (we'll get yourTurn event if it's our turn)
      if (playerId == _playerId) {
        state = state.copyWith(
          fen: fen, 
          pgn: pgn ?? '',
          currentTurn: null, // Clear turn, will be set by yourTurn event
        );
      } else {
        state = state.copyWith(fen: fen, pgn: pgn ?? '');
      }
    }
  }

  void _handleYourTurn(Map<String, dynamic> data) {
    // When we receive 'yourTurn', it means it's OUR turn
    state = state.copyWith(currentTurn: _playerId);
  }

  void _handleGameOver(Map<String, dynamic> data) {
    final winner = data['winner'] as String?;
    final endReason = data['endReason'] as String?;

    state = state.copyWith(
      status: GameStatus.completed,
      winner: winner,
      endReason: endReason,
    );
  }

  void _handleMoveError(Map<String, dynamic> data) {
    print('Move error: ${data['error']}');
  }

  Future<void> joinWaitingRoom() async {
    try {
      // Wait for WebSocket to be fully connected
      await Future.delayed(const Duration(milliseconds: 500));
      
      final result = await _apiService.joinWaitingRoom(_playerId);
      final status = result['status'] as String;

      if (status == 'game_created') {
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
    } catch (e) {
      print('Error joining waiting room: $e');
    }
  }

  Future<void> leaveWaitingRoom() async {
    try {
      await _apiService.leaveWaitingRoom(_playerId);
    } catch (e) {
      print('Error leaving waiting room: $e');
    }
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

  void resetGame() {
    state = GameState();
  }
}
