import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/game_state.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../main.dart';
import '../screens/game_board_screen.dart';

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
  bool _opponentLeftHandled = false;

  GameStateNotifier(this._wsService, this._apiService, this._playerId)
      : super(GameState()) {
    _initWebSocket();
  }

  void _initWebSocket() {
    _wsService.connect();
    
    // Wait for connection before registering
    Future.delayed(const Duration(milliseconds: 500), () {
      _wsService.register(_playerId);
    });

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
      case 'opponentLeft':
        _handleOpponentLeft(data);
        break;
    }
  }

  void _handleGameStarted(Map<String, dynamic> data) {
    print('=== GAME STARTED EVENT RECEIVED ===');
    print('Data: $data');
    print('My player ID: $_playerId');
    
    final gameId = data['gameId'] as String;
    final whitePlayerId = data['whitePlayerId'] as String;
    final blackPlayerId = data['blackPlayerId'] as String;

    final myColor = whitePlayerId == _playerId
        ? PlayerColor.white
        : PlayerColor.black;

    print('Game ID: $gameId');
    print('White: $whitePlayerId, Black: $blackPlayerId');
    print('My color: $myColor');

    state = state.copyWith(
      gameId: gameId,
      whitePlayerId: whitePlayerId,
      blackPlayerId: blackPlayerId,
      currentTurn: whitePlayerId,
      status: GameStatus.inProgress,
      myColor: myColor,
    );

    _wsService.joinGame(gameId, _playerId);
    
    // Navigate to game board using global navigator
    final context = navigatorKey.currentContext;
    print('Navigator context available: ${context != null}');
    
    if (context != null) {
      print('Navigating to game board...');
      
      // Close any open dialogs first
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      // Then navigate to game board
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const GameBoardScreen(),
        ),
      );
      print('Navigation pushed');
    } else {
      print('ERROR: Navigator context is null, cannot navigate!');
    }
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

  void _handleOpponentLeft(Map<String, dynamic> data) {
    print('Opponent left event received: $data');
    _opponentLeftHandled = true;
    state = state.copyWith(
      status: GameStatus.completed,
      endReason: 'opponent_left',
      winner: _playerId,
    );
    print('Game state updated to completed with opponent_left reason');
    
    // Show notification and navigate back to menu
    final context = navigatorKey.currentContext;
    if (context != null) {
      print('Showing opponent left notification from provider');
      
      // Show snackbar notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Your opponent has left the game. You win!'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      
      // Navigate back to main menu after a delay
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).popUntil((route) => route.isFirst);
        resetGame();
      });
    } else {
      print('ERROR: Navigator context is null!');
    }
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

  Future<Map<String, dynamic>> invitePlayer(String invitedPlayerId) async {
    try {
      // Ensure WebSocket is registered before inviting
      await Future.delayed(const Duration(milliseconds: 1000));
      
      final result = await _apiService.invitePlayer(_playerId, invitedPlayerId);
      
      final gameId = result['gameId'] as String;
      final whitePlayerId = result['whitePlayerId'] as String;
      final blackPlayerId = result['blackPlayerId'] as String;
      
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
      
      return {'success': true, 'gameId': gameId};
    } catch (e) {
      print('Error inviting player: $e');
      return {'success': false, 'error': e.toString()};
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

  void leaveGame() {
    if (state.gameId != null) {
      _wsService.leaveGame(state.gameId!, _playerId);
    }
    resetGame();
  }

  void resetGame() {
    _opponentLeftHandled = false;
    state = GameState();
  }
}
