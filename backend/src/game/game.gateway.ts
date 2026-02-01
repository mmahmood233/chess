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
  cors: {
    origin: '*',
  },
})
export class GameGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private playerSockets: Map<string, Socket> = new Map();
  private socketToPlayer: Map<string, string> = new Map();

  constructor(private gameService: GameService) {}

  handleConnection(client: Socket) {
    console.log(`Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    const playerId = this.socketToPlayer.get(client.id);
    if (playerId) {
      this.playerSockets.delete(playerId);
      this.socketToPlayer.delete(client.id);
    }
    console.log(`Client disconnected: ${client.id}`);
  }

  @SubscribeMessage('register')
  handleRegister(
    @MessageBody() data: { playerId: string },
    @ConnectedSocket() client: Socket,
  ) {
    this.playerSockets.set(data.playerId, client);
    this.socketToPlayer.set(client.id, data.playerId);
    client.emit('registered', { playerId: data.playerId });
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

    if (result.success) {
      this.server.to(data.gameId).emit('moveMade', {
        playerId: data.playerId,
        move: data.move,
        fen: result.fen,
        pgn: result.pgn,
      });

      const game = await this.gameService.getGame(data.gameId);
      const nextPlayerId = game.currentTurn;

      const nextPlayerSocket = this.playerSockets.get(nextPlayerId);
      if (nextPlayerSocket) {
        nextPlayerSocket.emit('yourTurn', {
          gameId: data.gameId,
        });
      }

      if (result.isGameOver) {
        this.server.to(data.gameId).emit('gameOver', {
          winner: result.winner,
          endReason: result.endReason,
          message: this.getGameOverMessage(result.winner, result.endReason),
        });
      }
    } else {
      client.emit('moveError', {
        error: result.error,
      });
    }
  }

  private getGameOverMessage(winner: string | undefined, endReason: string | undefined): string {
    if (endReason === 'checkmate') {
      return `Game over! ${winner} wins by checkmate!`;
    } else if (endReason === 'stalemate') {
      return 'Game over! Draw by stalemate.';
    } else if (endReason === 'draw') {
      return 'Game over! Draw.';
    } else if (endReason === 'threefold_repetition') {
      return 'Game over! Draw by threefold repetition.';
    } else if (endReason === 'insufficient_material') {
      return 'Game over! Draw by insufficient material.';
    }
    return 'Game over!';
  }

  notifyGameStart(gameId: string, whitePlayerId: string, blackPlayerId: string) {
    this.server.to(gameId).emit('gameStarted', {
      gameId,
      whitePlayerId,
      blackPlayerId,
    });

    const whiteSocket = this.playerSockets.get(whitePlayerId);
    if (whiteSocket) {
      whiteSocket.emit('yourTurn', { gameId });
    }
  }
}
