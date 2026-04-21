// api_service.dart — HTTP client for all REST communication with the backend.
//
// Uses Dio with a 5 s connect timeout and a 3 s receive timeout.
// All methods throw an [Exception] on network or server errors so the caller
// can decide how to handle them (show snackbar, retry, etc.).
import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  /// Join the public matchmaking queue.
  /// Returns `{ status: 'waiting' }` or `{ status: 'game_created', gameId, … }`.
  Future<Map<String, dynamic>> joinWaitingRoom(String playerId) async {
    try {
      final response = await _dio.post(
        '/waiting-room/join',
        data: {'playerId': playerId},
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to join waiting room: $e');
    }
  }

  /// Remove this player from the matchmaking queue.
  Future<void> leaveWaitingRoom(String playerId) async {
    try {
      await _dio.delete('/waiting-room/leave/$playerId');
    } catch (e) {
      throw Exception('Failed to leave waiting room: $e');
    }
  }

  /// Fetch all players currently waiting in the queue (debug / admin use).
  Future<List<dynamic>> getWaitingPlayers() async {
    try {
      final response = await _dio.get('/waiting-room/players');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get waiting players: $e');
    }
  }

  /// Send a direct game invitation to [invitedId].
  /// The backend forwards it via WebSocket; returns `{ status: 'invitation_sent' }`.
  Future<Map<String, dynamic>> invitePlayer(
    String inviterId,
    String invitedId,
  ) async {
    try {
      final response = await _dio.post(
        '/waiting-room/invite',
        data: {'inviterId': inviterId, 'invitedId': invitedId},
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to invite player: $e');
    }
  }

  /// Accept a pending invitation from [inviterId].
  /// The backend creates a game and notifies both players via WebSocket.
  Future<Map<String, dynamic>> acceptInvite(
    String inviterId,
    String invitedId,
  ) async {
    try {
      final response = await _dio.post(
        '/waiting-room/accept-invite',
        data: {'inviterId': inviterId, 'invitedId': invitedId},
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to accept invite: $e');
    }
  }

  /// Decline a pending invitation from [inviterId].
  /// The backend notifies the inviter via WebSocket.
  Future<Map<String, dynamic>> declineInvite(
    String inviterId,
    String invitedId,
  ) async {
    try {
      final response = await _dio.post(
        '/waiting-room/decline-invite',
        data: {'inviterId': inviterId, 'invitedId': invitedId},
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to decline invite: $e');
    }
  }
}
