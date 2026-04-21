/**
 * move.dto.ts — Data Transfer Objects for WebSocket and REST payloads.
 *
 * These classes describe the shape of data coming in from clients.
 * NestJS uses them with the @MessageBody() and @Body() decorators.
 */

/** Payload for a single chess move (from square, to square, optional promotion). */
export class MoveDto {
  from: string;        // Origin square, e.g. "e2"
  to: string;          // Destination square, e.g. "e4"
  promotion?: string;  // Piece letter if promoting a pawn: 'q' | 'r' | 'b' | 'n'
}

/** Payload used when a player joins a game room. */
export class JoinGameDto {
  playerId: string;
}

/** Payload used when creating or requesting a new game. */
export class CreateGameDto {
  playerId: string;
  invitedPlayerId?: string; // Provided only for private (friend) invites
}
