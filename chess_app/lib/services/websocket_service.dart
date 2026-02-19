import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';

class WebSocketService {
  IO.Socket? _socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  
  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    try {
      _socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      });

      _socket!.onConnect((_) {
        print('Socket.io connected');
      });

      _socket!.onDisconnect((_) {
        print('Socket.io disconnected');
      });

      _socket!.onError((error) {
        print('Socket.io error: $error');
      });

      _socket!.on('registered', (data) {
        _messageController.add({'event': 'registered', 'data': data});
      });

      _socket!.on('gameStarted', (data) {
        _messageController.add({'event': 'gameStarted', 'data': data});
      });

      _socket!.on('playerJoined', (data) {
        _messageController.add({'event': 'playerJoined', 'data': data});
      });

      _socket!.on('moveMade', (data) {
        _messageController.add({'event': 'moveMade', 'data': data});
      });

      _socket!.on('yourTurn', (data) {
        _messageController.add({'event': 'yourTurn', 'data': data});
      });

      _socket!.on('gameOver', (data) {
        _messageController.add({'event': 'gameOver', 'data': data});
      });

      _socket!.on('moveError', (data) {
        _messageController.add({'event': 'moveError', 'data': data});
      });

      _socket!.on('opponentLeft', (data) {
        _messageController.add({'event': 'opponentLeft', 'data': data});
      });

      _socket!.on('inviteReceived', (data) {
        _messageController.add({'event': 'inviteReceived', 'data': data});
      });

      _socket!.on('inviteDeclined', (data) {
        _messageController.add({'event': 'inviteDeclined', 'data': data});
      });
    } catch (e) {
      print('Error connecting to WebSocket: $e');
    }
  }

  void register(String playerId) {
    _socket?.emit('register', {'playerId': playerId});
  }

  void joinGame(String gameId, String playerId) {
    _socket?.emit('joinGame', {'gameId': gameId, 'playerId': playerId});
  }

  void makeMove(String gameId, String playerId, Map<String, String> move) {
    _socket?.emit('makeMove', {
      'gameId': gameId,
      'playerId': playerId,
      'move': move,
    });
  }

  void leaveGame(String gameId, String playerId) {
    _socket?.emit('leaveGame', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _messageController.close();
  }
}
