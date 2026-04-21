/// game_state.dart — Immutable model for the entire chess game state.
///
/// [GameState] is the single source of truth consumed by the UI.
/// [GameStateNotifier] (in game_provider.dart) is the only place that
/// produces new instances — no widget ever mutates state directly.

/// Sentinel type used in [GameState.copyWith] to distinguish "caller passed
/// null explicitly" from "caller did not pass this field at all".
/// Fields that use this pattern (currentTurn, lastMoveFrom, lastMoveTo) can
/// be explicitly cleared by passing null, while omitting the argument keeps
/// the previous value.
class _Undefined {
  const _Undefined();
}

/// Lifecycle of a game session from the client's perspective.
enum GameStatus {
  waiting,    // Player is in the waiting room, no game yet
  inProgress, // A game is active
  completed,  // The game has ended (checkmate, draw, resign, disconnect)
}

/// Which colour this player is controlling in the current game.
enum PlayerColor { white, black }

/// Full snapshot of the current game, including board position, player IDs,
/// whose turn it is, and metadata needed to render the UI.
class GameState {
  /// Server-assigned UUID for this game session.
  final String? gameId;

  /// Player IDs assigned to each colour.
  final String? whitePlayerId;
  final String? blackPlayerId;

  /// UUID of the player whose turn it currently is.
  /// Null when no game is active or between turns.
  final String? currentTurn;

  /// Current board position in Forsyth-Edwards Notation.
  final String fen;

  /// Full move history in Portable Game Notation.
  final String pgn;

  final GameStatus status;

  /// UUID of the winning player, or null for draws.
  final String? winner;

  /// Machine-readable reason the game ended:
  /// 'checkmate' | 'stalemate' | 'draw' | 'threefold_repetition' |
  /// 'insufficient_material' | 'opponent_left'
  final String? endReason;

  /// This client's colour — set once the server assigns colours at game start.
  final PlayerColor? myColor;

  /// The origin square of the most recent move (used for last-move highlight).
  final String? lastMoveFrom;

  /// The destination square of the most recent move.
  final String? lastMoveTo;

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
    this.lastMoveFrom,
    this.lastMoveTo,
  });

  /// Returns a copy of this state with the specified fields replaced.
  ///
  /// Fields typed as [Object?] with a default of [_Undefined] support
  /// explicit null passing: pass `currentTurn: null` to clear the field;
  /// omit it to keep the current value.
  GameState copyWith({
    String? gameId,
    String? whitePlayerId,
    String? blackPlayerId,
    Object? currentTurn = const _Undefined(),
    String? fen,
    String? pgn,
    GameStatus? status,
    String? winner,
    String? endReason,
    PlayerColor? myColor,
    Object? lastMoveFrom = const _Undefined(),
    Object? lastMoveTo = const _Undefined(),
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      whitePlayerId: whitePlayerId ?? this.whitePlayerId,
      blackPlayerId: blackPlayerId ?? this.blackPlayerId,
      currentTurn: currentTurn is _Undefined
          ? this.currentTurn
          : currentTurn as String?,
      fen: fen ?? this.fen,
      pgn: pgn ?? this.pgn,
      status: status ?? this.status,
      winner: winner ?? this.winner,
      endReason: endReason ?? this.endReason,
      myColor: myColor ?? this.myColor,
      lastMoveFrom: lastMoveFrom is _Undefined
          ? this.lastMoveFrom
          : lastMoveFrom as String?,
      lastMoveTo: lastMoveTo is _Undefined
          ? this.lastMoveTo
          : lastMoveTo as String?,
    );
  }

  /// True when it is this client's turn to move.
  bool get isMyTurn =>
      currentTurn != null && currentTurn == _getMyPlayerId();

  /// Returns this client's player UUID based on the assigned colour.
  String? _getMyPlayerId() {
    if (myColor == PlayerColor.white) return whitePlayerId;
    if (myColor == PlayerColor.black) return blackPlayerId;
    return null;
  }
}
