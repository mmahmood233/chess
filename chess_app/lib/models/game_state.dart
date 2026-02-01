enum GameStatus {
  waiting,
  inProgress,
  completed,
}

enum PlayerColor {
  white,
  black,
}

class GameState {
  final String? gameId;
  final String? whitePlayerId;
  final String? blackPlayerId;
  final String? currentTurn;
  final String fen;
  final String pgn;
  final GameStatus status;
  final String? winner;
  final String? endReason;
  final PlayerColor? myColor;

  GameState({
    this.gameId,
    this.whitePlayerId,
    this.blackPlayerId,
    this.currentTurn,
    this.fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.pgn = '',
    this.status = GameStatus.waiting,
    this.winner,
    this.endReason,
    this.myColor,
  });

  GameState copyWith({
    String? gameId,
    String? whitePlayerId,
    String? blackPlayerId,
    String? currentTurn,
    String? fen,
    String? pgn,
    GameStatus? status,
    String? winner,
    String? endReason,
    PlayerColor? myColor,
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      whitePlayerId: whitePlayerId ?? this.whitePlayerId,
      blackPlayerId: blackPlayerId ?? this.blackPlayerId,
      currentTurn: currentTurn ?? this.currentTurn,
      fen: fen ?? this.fen,
      pgn: pgn ?? this.pgn,
      status: status ?? this.status,
      winner: winner ?? this.winner,
      endReason: endReason ?? this.endReason,
      myColor: myColor ?? this.myColor,
    );
  }

  bool get isMyTurn => currentTurn != null && currentTurn == _getMyPlayerId();

  String? _getMyPlayerId() {
    if (myColor == PlayerColor.white) return whitePlayerId;
    if (myColor == PlayerColor.black) return blackPlayerId;
    return null;
  }
}
