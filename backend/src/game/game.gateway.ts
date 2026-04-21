/**
 * game.gateway.ts — Socket.io WebSocket gateway.
 *
 * Handles all real-time communication between the server and connected clients.
 *
 * Key responsibilities:
 *   • Register players: map a stable player UUID to their current Socket.
 *   • Relay moves: validate via GameService, then broadcast to the game room.
 *   • Send turn notifications: emit 'yourTurn' to the next player after each move.
 *   • Detect disconnects: notify the opponent and abandon the game if needed.
 *   • Reconnection support: re-sync the player with their active game on re-register.
 *   • Friend invitations: deliver 'inviteReceived' events to online players.
 *
 * ── Socket maps ──────────────────────────────────────────────────────────────
 * playerSockets  : playerId  → currently active Socket
 * socketToPlayer : socketId  → playerId
 *
 * Two maps are kept so lookups work in both directions.  The socketToPlayer map
 * may contain stale entries for old sockets — the race-condition guard in
 * handleDisconnect prevents those from incorrectly cleaning up a fresh socket.
 */
import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { GameService } from './game.service';
import { MoveDto } from '../common/dto/move.dto';

@WebSocketGateway({
  cors: { origin: '*' },
})
export class GameGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  /** playerId → currently-active Socket */
  private playerSockets: Map<string, Socket> = new Map();
  /** socketId → playerId  (may contain stale entries for old sockets) */
  private socketToPlayer: Map<string, string> = new Map();

  constructor(private gameService: GameService) {}

  /** Fired when any client opens a WebSocket connection. */
  handleConnection(client: Socket) {
    console.log(`[WS] connected: ${client.id}`);
  }

  /**
   * Fired when a client socket disconnects.
   *
   * Race-condition guard: Socket.io re-uses the same player UUID across
   * reconnects, but each reconnect gets a NEW socketId.  If the player
   * already re-registered with a new socket by the time this disconnect
   * event fires for the old socket, we must not touch playerSockets or
   * abandon the game — that would undo the fresh registration.
   */
  async handleDisconnect(client: Socket) {
    const playerId = this.socketToPlayer.get(client.id);
    console.log(
      `[WS] disconnected: ${client.id} (player: ${playerId ?? 'unknown'})`,
    );

    if (!playerId) return;

    // Always remove the stale socketId → playerId entry.
    this.socketToPlayer.delete(client.id);

    // If the player already registered a NEW socket (reconnection), the
    // playerSockets map points to the new socket, not this one.
    // In that case this is a "stale disconnect" — do NOT touch playerSockets
    // or abandon the game.
    const currentSocket = this.playerSockets.get(playerId);
    if (!currentSocket || currentSocket.id !== client.id) {
      console.log(
        `[WS] Stale disconnect ignored for ${playerId} (already re-registered)`,
      );
      return;
    }

    // This socket IS the active one — the player truly left.
    this.playerSockets.delete(playerId);

    try {
      const game = await this.gameService.findActiveGameByPlayer(playerId);
      if (game) {
        // Notify the opponent that this player has gone
        const opponentId =
          game.whitePlayerId === playerId
            ? game.blackPlayerId
            : game.whitePlayerId;

        const opponentSocket = this.playerSockets.get(opponentId);
        if (opponentSocket) {
          opponentSocket.emit('opponentLeft', {
            gameId: game.id,
            message: 'Your opponent has disconnected.',
          });
        }

        // Record the abandonment; the remaining player wins
        await this.gameService.abandonGame(game.id, playerId);
      }
    } catch (err) {
      console.error('[WS] handleDisconnect error:', err);
    }
  }

  /**
   * 'register' event — called by every client on connect (and on reconnect).
   *
   * Stores the player → socket mapping so the server can reach this player
   * later (e.g. for turn notifications, invitations).
   *
   * If the player had a stale socket entry from before, that old socketId is
   * removed from socketToPlayer so a delayed disconnect for it is ignored.
   *
   * After registration, any active game is resumed by emitting 'gameStarted'
   * with the current FEN and turn information.
   */
  @SubscribeMessage('register')
  async handleRegister(
    @MessageBody() data: { playerId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const { playerId } = data;
    console.log(`[WS] register: player=${playerId} socket=${client.id}`);

    // Clean up the stale reverse mapping for the player's previous socket so
    // handleDisconnect for the old socket treats it as a no-op.
    const oldSocket = this.playerSockets.get(playerId);
    if (oldSocket && oldSocket.id !== client.id) {
      console.log(
        `[WS] Removing stale socket mapping ${oldSocket.id} for ${playerId}`,
      );
      this.socketToPlayer.delete(oldSocket.id);
    }

    this.playerSockets.set(playerId, client);
    this.socketToPlayer.set(client.id, playerId);
    client.emit('registered', { playerId });

    // Resume any active game for this player (reconnection support)
    const game = await this.gameService.findActiveGameByPlayer(playerId);
    if (game) {
      console.log(`[WS] Resuming game ${game.id} for ${playerId}`);
      client.join(game.id);
      client.emit('gameStarted', {
        gameId: game.id,
        whitePlayerId: game.whitePlayerId,
        blackPlayerId: game.blackPlayerId,
        fen: game.fen,
        currentTurn: game.currentTurn,
      });
      // Restore the turn indicator if it's this player's turn
      if (game.currentTurn === playerId) {
        client.emit('yourTurn', { gameId: game.id });
      }
    }
  }

  /**
   * 'joinGame' event — adds the client socket to the named Socket.io room.
   * Rooms ensure that broadcasts (moveMade, gameOver …) go only to the two
   * players in that game and no one else.
   */
  @SubscribeMessage('joinGame')
  handleJoinGame(
    @MessageBody() data: { gameId: string; playerId: string },
    @ConnectedSocket() client: Socket,
  ) {
    client.join(data.gameId);
    this.server.to(data.gameId).emit('playerJoined', {
      playerId: data.playerId,
      gameId: data.gameId,
    });
  }

  /**
   * 'leaveGame' event — explicit resign / leave while a game is in progress.
   * Notifies the opponent and marks the game as abandoned.
   */
  @SubscribeMessage('leaveGame')
  async handleLeaveGame(
    @MessageBody() data: { gameId: string; playerId: string },
    @ConnectedSocket() _client: Socket,
  ) {
    const game = await this.gameService.getGame(data.gameId);
    if (!game || game.status !== 'IN_PROGRESS') return;

    const opponentId =
      game.whitePlayerId === data.playerId
        ? game.blackPlayerId
        : game.whitePlayerId;

    const opponentSocket = this.playerSockets.get(opponentId);
    if (opponentSocket) {
      opponentSocket.emit('opponentLeft', {
        gameId: data.gameId,
        message: 'Your opponent has left the game.',
      });
    }

    await this.gameService.abandonGame(data.gameId, data.playerId);
  }

  /**
   * 'makeMove' event — validates and applies a chess move.
   *
   * On success:
   *   • Broadcasts 'moveMade' to the entire game room (both players).
   *   • If the game is over, broadcasts 'gameOver' to the room.
   *   • Otherwise emits 'yourTurn' to the next player.
   *
   * On failure:
   *   • Emits 'moveError' back to the sender only.
   */
  @SubscribeMessage('makeMove')
  async handleMove(
    @MessageBody() data: { gameId: string; playerId: string; move: MoveDto },
    @ConnectedSocket() client: Socket,
  ) {
    const result = await this.gameService.makeMove(
      data.gameId,
      data.playerId,
      data.move,
    );

    if (!result.success) {
      client.emit('moveError', { error: result.error ?? 'Illegal move' });
      return;
    }

    // Broadcast the confirmed move to both players in the room
    this.server.to(data.gameId).emit('moveMade', {
      playerId: data.playerId,
      move: data.move,
      fen: result.fen,
      pgn: result.pgn,
    });

    if (result.isGameOver) {
      // Notify both players of the game result
      this.server.to(data.gameId).emit('gameOver', {
        winner: result.winner,
        endReason: result.endReason,
        message: this.getGameOverMessage(result.winner, result.endReason),
      });
    } else {
      // Notify the next player that it is their turn
      const updatedGame = await this.gameService.getGame(data.gameId);
      if (updatedGame) {
        const nextSocket = this.playerSockets.get(updatedGame.currentTurn);
        if (nextSocket) {
          nextSocket.emit('yourTurn', { gameId: data.gameId });
        }
      }
    }
  }

  // ── Called by WaitingRoomService ───────────────────────────────────────────

  /**
   * Sends a game invitation to the invited player's active socket.
   * Returns true if the socket was found and the event was sent, false otherwise.
   * A false return means the invited player is not currently connected.
   */
  sendInvitation(inviterId: string, invitedId: string): boolean {
    const socket = this.playerSockets.get(invitedId);
    if (socket) {
      socket.emit('inviteReceived', { inviterId, invitedId });
      console.log(`[WS] Invitation sent from ${inviterId} to ${invitedId}`);
      return true;
    }
    console.warn(
      `[WS] sendInvitation: no active socket for invited player ${invitedId}`,
    );
    return false;
  }

  /** Notifies the original inviter that their invitation was declined. */
  notifyInviteDeclined(inviterId: string, invitedId: string) {
    const socket = this.playerSockets.get(inviterId);
    if (socket) {
      socket.emit('inviteDeclined', { invitedId });
    }
  }

  /**
   * Called by WaitingRoomService after a game is created (either via
   * auto-match or friend invite).  Adds both players to the Socket.io
   * room for the new game and sends each their personalised 'gameStarted'
   * payload.  White also receives the first 'yourTurn' signal.
   */
  notifyGameStart(
    gameId: string,
    whitePlayerId: string,
    blackPlayerId: string,
    fen: string,
  ) {
    const whiteSocket = this.playerSockets.get(whitePlayerId);
    const blackSocket = this.playerSockets.get(blackPlayerId);

    if (whiteSocket) {
      whiteSocket.join(gameId);
      whiteSocket.emit('gameStarted', {
        gameId,
        whitePlayerId,
        blackPlayerId,
        fen,
        currentTurn: whitePlayerId, // White moves first
      });
      whiteSocket.emit('yourTurn', { gameId }); // Prompt white immediately
    } else {
      console.warn(
        `[WS] notifyGameStart: white socket missing (${whitePlayerId})`,
      );
    }

    if (blackSocket) {
      blackSocket.join(gameId);
      blackSocket.emit('gameStarted', {
        gameId,
        whitePlayerId,
        blackPlayerId,
        fen,
        currentTurn: whitePlayerId, // Black sees white's turn too
      });
    } else {
      console.warn(
        `[WS] notifyGameStart: black socket missing (${blackPlayerId})`,
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /** Returns a human-readable game-over message for the given end reason. */
  private getGameOverMessage(winner?: string, endReason?: string): string {
    switch (endReason) {
      case 'checkmate':              return `Checkmate! ${winner} wins!`;
      case 'stalemate':              return 'Draw by stalemate.';
      case 'draw':                   return 'The game ended in a draw.';
      case 'threefold_repetition':   return 'Draw by threefold repetition.';
      case 'insufficient_material':  return 'Draw by insufficient material.';
      default:                       return 'Game over.';
    }
  }
}
