// websocket_service.dart — Socket.io WebSocket client wrapper.
//
// Wraps socket_io_client to provide a clean interface for the rest of the app:
//   • [connect]           — Open the socket and register all event listeners.
//   • [waitForConnection] — Await readiness before emitting events (avoids
//                           fire-and-forget on a not-yet-connected socket).
//   • [messages]          — Broadcast stream of normalised event maps consumed
//                           by [GameStateNotifier].
//   • Typed emit helpers  — [register], [joinGame], [makeMove], [leaveGame].
//
// ── Reconnection handling ────────────────────────────────────────────────────
// socket_io_client 2.x fires [onConnect] on BOTH initial connection and every
// subsequent reconnect.  The [_hasEverConnected] flag distinguishes the two:
//   • First connect  → emits `connected` event (handled by _initWebSocket).
//   • Reconnect      → emits `reconnected` event (handled by the provider,
//                       which re-calls register() so the server maps the new
//                       socketId to this player UUID).
//
// [onDisconnect] resets the [_connected] Completer so that any pending
// [waitForConnection] call will block until the socket re-establishes.
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';

class WebSocketService {
  IO.Socket? _socket;

  /// Broadcast stream — all incoming socket events are normalised to
  /// `{ 'event': String, 'data': Map<String, dynamic> }` and added here.
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  /// Completer that completes once the socket is connected.
  /// Reset to a new uncompleted instance on disconnect so future
  /// [waitForConnection] calls block until the next connect event.
  Completer<void> _connected = Completer<void>();

  /// Tracks whether the socket has ever successfully connected so
  /// subsequent [onConnect] firings can be identified as reconnects.
  bool _hasEverConnected = false;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Waits until the socket is connected before returning.
  /// Returns immediately if already connected.
  /// Throws a [TimeoutException] if the connection is not established within
  /// [timeout] (default 10 seconds).
  Future<void> waitForConnection({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_socket?.connected == true) return;
    await _connected.future.timeout(timeout, onTimeout: () {
      throw TimeoutException(
        'WebSocket connection timed out after ${timeout.inSeconds}s',
      );
    });
  }

  /// Opens the Socket.io connection and registers all event handlers.
  /// Safe to call multiple times — subsequent calls reuse the same socket.
  void connect() {
    try {
      _socket = IO.io(ApiConfig.baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionDelay': 1000,       // Wait 1 s before first retry
        'reconnectionDelayMax': 5000,    // Cap retry delay at 5 s
        'reconnectionAttempts': 10,
      });

      // ── Connection lifecycle ───────────────────────────────────────────────

      _socket!.onConnect((_) {
        // Complete the Completer so waitForConnection() unblocks
        if (!_connected.isCompleted) {
          _connected.complete();
        }

        if (_hasEverConnected) {
          // This is a reconnect — signal the provider to re-register
          _messageController.add({
            'event': 'reconnected',
            'data': <String, dynamic>{},
          });
        } else {
          _hasEverConnected = true;
          _messageController.add({
            'event': 'connected',
            'data': <String, dynamic>{},
          });
        }
      });

      _socket!.onDisconnect((_) {
        // Reset completer so future waitForConnection() calls block until reconnect
        if (_connected.isCompleted) {
          _connected = Completer<void>();
        }
        _messageController.add({
          'event': 'disconnected',
          'data': <String, dynamic>{},
        });
      });

      _socket!.onError((_) {
        // Connection errors are handled by the reconnection logic above
      });

      // ── Game events ────────────────────────────────────────────────────────

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
        _messageController
            .add({'event': 'inviteReceived', 'data': _toMap(data)});
      });

      _socket!.on('inviteDeclined', (data) {
        _messageController
            .add({'event': 'inviteDeclined', 'data': _toMap(data)});
      });
    } catch (_) {
      // Silently ignore — reconnection logic will retry
    }
  }

  /// Normalises socket event payloads to [Map<String, dynamic>].
  /// socket_io_client may deliver data as a raw [Map] without the correct
  /// generic types; this helper ensures consistent typing throughout the app.
  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ── Emit helpers ────────────────────────────────────────────────────────────

  /// Register this player's UUID with the server, binding it to this socket.
  void register(String playerId) {
    _socket?.emit('register', {'playerId': playerId});
  }

  /// Join the Socket.io room for [gameId] so move broadcasts are received.
  void joinGame(String gameId, String playerId) {
    _socket?.emit('joinGame', {'gameId': gameId, 'playerId': playerId});
  }

  /// Submit a move to the server for validation.
  void makeMove(
    String gameId,
    String playerId,
    Map<String, dynamic> move,
  ) {
    _socket?.emit('makeMove', {
      'gameId': gameId,
      'playerId': playerId,
      'move': move,
    });
  }

  /// Resign / leave the game.  The server will notify the opponent.
  void leaveGame(String gameId, String playerId) {
    _socket?.emit('leaveGame', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  /// Disconnect the socket and close the event stream.
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    if (!_messageController.isClosed) {
      _messageController.close();
    }
  }
}
