import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  
  bool get isConnected => _channel != null;

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiConfig.wsUrl));
      
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message as String);
          _messageController.add(data);
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket connection closed');
          _channel = null;
        },
      );
    } catch (e) {
      print('Failed to connect WebSocket: $e');
    }
  }

  void send(String event, Map<String, dynamic> data) {
    if (_channel != null) {
      final message = jsonEncode({
        'event': event,
        'data': data,
      });
      _channel!.sink.add(message);
    }
  }

  void register(String playerId) {
    send('register', {'playerId': playerId});
  }

  void joinGame(String gameId, String playerId) {
    send('joinGame', {'gameId': gameId, 'playerId': playerId});
  }

  void makeMove(String gameId, String playerId, Map<String, String> move) {
    send('makeMove', {
      'gameId': gameId,
      'playerId': playerId,
      'move': move,
    });
  }

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
  }
}
