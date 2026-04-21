import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';

class WebSocketService {
  IO.Socket? _socket;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Completer<void> _connected = Completer<void>();
  bool _hasEverConnected = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Waits until the socket is connected. Returns immediately if already connected.
  Future<void> waitForConnection({Duration timeout = const Duration(seconds: 10)}) async {
    if (_socket?.connected == true) return;
    await _connected.future.timeout(timeout, onTimeout: () {
      throw TimeoutException('WebSocket connection timed out after ${timeout.inSeconds}s');
    });
  }

  void connect() {
    try {
      _socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'reconnectionAttempts': 10,
      });

      _socket!.onConnect((_) {
        if (!_connected.isCompleted) {
          _connected.complete();
        }
        if (_hasEverConnected) {
          // This is a reconnect — re-registration is needed
          _messageController.add({'event': 'reconnected', 'data': <String, dynamic>{}});
        } else {
          _hasEverConnected = true;
          _messageController.add({'event': 'connected', 'data': <String, dynamic>{}});
        }
      });

      _socket!.onDisconnect((_) {
        // Reset completer so future waitForConnection() calls will wait for reconnect
        if (_connected.isCompleted) {
          _connected = Completer<void>();
        }
        _messageController.add({'event': 'disconnected', 'data': <String, dynamic>{}});
      });

      _socket!.onError((error) {
        // ignore connection errors silently
      });

      _socket!.on('registered', (data) {
        _messageController.add({'event': 'registered', 'data': _toMap(data)});
      });

      _socket!.on('gameStarted', (data) {
        _messageController.add({'event': 'gameStarted', 'data': _toMap(data)});
      });

      _socket!.on('playerJoined', (data) {
        _messageController.add({'event': 'playerJoined', 'data': _toMap(data)});
      });

      _socket!.on('moveMade', (data) {
        _messageController.add({'event': 'moveMade', 'data': _toMap(data)});
      });

      _socket!.on('yourTurn', (data) {
        _messageController.add({'event': 'yourTurn', 'data': _toMap(data)});
      });

      _socket!.on('gameOver', (data) {
        _messageController.add({'event': 'gameOver', 'data': _toMap(data)});
      });

      _socket!.on('moveError', (data) {
        _messageController.add({'event': 'moveError', 'data': _toMap(data)});
      });

      _socket!.on('opponentLeft', (data) {
        _messageController.add({'event': 'opponentLeft', 'data': _toMap(data)});
      });

      _socket!.on('inviteReceived', (data) {
        _messageController.add({'event': 'inviteReceived', 'data': _toMap(data)});
      });

      _socket!.on('inviteDeclined', (data) {
        _messageController.add({'event': 'inviteDeclined', 'data': _toMap(data)});
      });
    } catch (e) {
      // ignore
    }
  }

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  void register(String playerId) {
    _socket?.emit('register', {'playerId': playerId});
  }

  void joinGame(String gameId, String playerId) {
    _socket?.emit('joinGame', {'gameId': gameId, 'playerId': playerId});
  }

  void makeMove(String gameId, String playerId, Map<String, dynamic> move) {
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
    if (!_messageController.isClosed) {
      _messageController.close();
    }
  }
}
