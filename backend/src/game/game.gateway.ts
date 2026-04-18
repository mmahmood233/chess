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

  /** playerId → connected Socket */
  private playerSockets: Map<string, Socket> = new Map();
  /** socketId → playerId */
  private socketToPlayer: Map<string, string> = new Map();

  constructor(private gameService: GameService) {}

  handleConnection(client: Socket) {
    console.log(`[WS] connected: ${client.id}`);
  }

  async handleDisconnect(client: Socket) {
    const playerId = this.socketToPlayer.get(client.id);
    console.log(`[WS] disconnected: ${client.id} (player ${playerId})`);

    if (playerId) {
      try {
        const game = await this.gameService.findActiveGameByPlayer(playerId);
        if (game) {
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

          await this.gameService.abandonGame(game.id, playerId);
        }
      } catch (err) {
        console.error('[WS] handleDisconnect error:', err);
      }

      this.playerSockets.delete(playerId);
      this.socketToPlayer.delete(client.id);
    }
  }

  @SubscribeMessage('register')
  async handleRegister(
    @MessageBody() data: { playerId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const { playerId } = data;

    // Update maps (re-registration replaces stale socket)
    this.playerSockets.set(playerId, client);
    this.socketToPlayer.set(client.id, playerId);
    client.emit('registered', { playerId });

    // Resume any active game for this player
    const game = await this.gameService.findActiveGameByPlayer(playerId);
    if (game) {
      console.log(`[WS] Resuming game ${game.id} for player ${playerId}`);
      client.join(game.id);
      client.emit('gameStarted', {
        gameId: game.id,
        whitePlayerId: game.whitePlayerId,
        blackPlayerId: game.blackPlayerId,
        fen: game.fen,
        currentTurn: game.currentTurn,
      });
      // Tell player it's their turn if so
      if (game.currentTurn === playerId) {
        client.emit('yourTurn', { gameId: game.id });
      }
    }
  }

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

  @SubscribeMessage('leaveGame')
  async handleLeaveGame(
    @MessageBody() data: { gameId: string; playerId: string },
    @ConnectedSocket() client: Socket,
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

    // Broadcast new board state to everyone in the room
    this.server.to(data.gameId).emit('moveMade', {
      playerId: data.playerId,
      move: data.move,
      fen: result.fen,
      pgn: result.pgn,
    });

    if (result.isGameOver) {
      // Notify both players of the result — no yourTurn after game ends
      this.server.to(data.gameId).emit('gameOver', {
        winner: result.winner,
        endReason: result.endReason,
        message: this.getGameOverMessage(result.winner, result.endReason),
      });
    } else {
      // Tell the next player it is their turn
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

  sendInvitation(inviterId: string, invitedId: string) {
    const socket = this.playerSockets.get(invitedId);
    if (socket) {
      socket.emit('inviteReceived', { inviterId, invitedId });
    } else {
      console.warn(`[WS] sendInvitation: socket not found for ${invitedId}`);
    }
  }

  notifyInviteDeclined(inviterId: string, invitedId: string) {
    const socket = this.playerSockets.get(inviterId);
    if (socket) {
      socket.emit('inviteDeclined', { invitedId });
    }
  }

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
        currentTurn: whitePlayerId, // White always starts
      });
      whiteSocket.emit('yourTurn', { gameId });
    } else {
      console.warn(`[WS] notifyGameStart: white socket not found (${whitePlayerId})`);
    }

    if (blackSocket) {
      blackSocket.join(gameId);
      blackSocket.emit('gameStarted', {
        gameId,
        whitePlayerId,
        blackPlayerId,
        fen,
        currentTurn: whitePlayerId, // White always starts
      });
      // Black does NOT get yourTurn — it is white's turn
    } else {
      console.warn(`[WS] notifyGameStart: black socket not found (${blackPlayerId})`);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  private getGameOverMessage(
    winner: string | undefined,
    endReason: string | undefined,
  ): string {
    switch (endReason) {
      case 'checkmate':
        return `Checkmate! ${winner} wins!`;
      case 'stalemate':
        return 'Draw by stalemate.';
      case 'draw':
        return 'The game ended in a draw.';
      case 'threefold_repetition':
        return 'Draw by threefold repetition.';
      case 'insufficient_material':
        return 'Draw by insufficient material.';
      default:
        return 'Game over.';
    }
  }
}
