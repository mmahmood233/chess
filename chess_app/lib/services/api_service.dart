import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

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

  Future<void> leaveWaitingRoom(String playerId) async {
    try {
      await _dio.delete('/waiting-room/leave/$playerId');
    } catch (e) {
      throw Exception('Failed to leave waiting room: $e');
    }
  }

  Future<List<dynamic>> getWaitingPlayers() async {
    try {
      final response = await _dio.get('/waiting-room/players');
      return response.data;
    } catch (e) {
      throw Exception('Failed to get waiting players: $e');
    }
  }

  Future<Map<String, dynamic>> invitePlayer(
      String inviterId, String invitedId) async {
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

  Future<Map<String, dynamic>> acceptInvite(
      String inviterId, String invitedId) async {
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

  Future<Map<String, dynamic>> declineInvite(
      String inviterId, String invitedId) async {
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
