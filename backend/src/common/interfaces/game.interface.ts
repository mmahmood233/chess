/**
 * game.interface.ts — Shared types and enums for the chess game domain.
 *
 * These definitions are used by both the GameService (business logic) and the
 * GameGateway (WebSocket layer) to keep the data shapes consistent.
 */

/** Full shape of a game row returned from Prisma. */
export interface IGame {
  id: string;
  whitePlayerId: string;
  blackPlayerId: string;
  /** UUID of the player whose turn it currently is. */
  currentTurn: string;
  /** Board position in Forsyth-Edwards Notation (FEN). */
  fen: string;
  /** Move history in Portable Game Notation (PGN). */
  pgn: string;
  status: GameStatus;
  winner?: string;
  /** Human-readable reason the game ended (e.g. 'checkmate', 'stalemate'). */
  endReason?: string;
  /** Compact move history array, each entry formatted as "e2-e4". */
  moveHistory: string[];
  createdAt: Date;
  updatedAt: Date;
}

/** Lifecycle states a game can be in. */
export enum GameStatus {
  WAITING    = 'waiting',
  IN_PROGRESS = 'in_progress',
  COMPLETED  = 'completed',
}

/** Which colour a player is controlling. */
export enum PlayerColor {
  WHITE = 'white',
  BLACK = 'black',
}

/** Payload sent by the client when submitting a move. */
export interface IMoveRequest {
  from: string;        // e.g. "e2"
  to: string;          // e.g. "e4"
  promotion?: string;  // piece letter for pawn promotion, e.g. "q"
}

/** Result returned by GameService.makeMove(). */
export interface IMoveResponse {
  success: boolean;
  fen?: string;         // Updated board FEN after the move
  pgn?: string;         // Updated PGN after the move
  move?: string;        // Compact "from-to" representation
  error?: string;       // Error message if success is false
  isGameOver?: boolean;
  winner?: string;      // Player UUID of the winner, or undefined for draws
  endReason?: string;   // 'checkmate' | 'stalemate' | 'draw' | …
}
