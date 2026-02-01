class ApiConfig {
  static const String baseUrl = 'http://localhost:3000';
  static const String wsUrl = 'ws://localhost:3000';
  
  static const String joinWaitingRoom = '$baseUrl/waiting-room/join';
  static const String leaveWaitingRoom = '$baseUrl/waiting-room/leave';
  static const String getWaitingPlayers = '$baseUrl/waiting-room/players';
  static const String invitePlayer = '$baseUrl/waiting-room/invite';
}
