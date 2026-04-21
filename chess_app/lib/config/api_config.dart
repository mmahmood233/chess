/// api_config.dart — Centralised backend URL configuration.
///
/// Change [baseUrl] to point at your backend server when running on a
/// physical device or a remote host.  The Flutter app reads this value in
/// both [ApiService] (HTTP) and [WebSocketService] (Socket.io).
class ApiConfig {
  /// Base URL for REST API calls and Socket.io connection.
  static const String baseUrl = 'http://127.0.0.1:3000';

  /// WebSocket URL (kept for reference; socket_io_client uses baseUrl directly).
  static const String wsUrl = 'ws://127.0.0.1:3000';

  // ── REST endpoint paths ────────────────────────────────────────────────────
  static const String joinWaitingRoom  = '$baseUrl/waiting-room/join';
  static const String leaveWaitingRoom = '$baseUrl/waiting-room/leave';
  static const String getWaitingPlayers = '$baseUrl/waiting-room/players';
  static const String invitePlayer     = '$baseUrl/waiting-room/invite';
}
