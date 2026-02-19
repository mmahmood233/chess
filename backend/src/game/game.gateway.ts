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

  async handleDisconnect(client: Socket) {
    const playerId = this.socketToPlayer.get(client.id);
    console.log(`Client disconnected: ${client.id}, playerId: ${playerId}`);
    
    if (playerId) {
      try {
        // Find if player is in an active game
        const game = await this.gameService.findActiveGameByPlayer(playerId);
        console.log(`Found active game for player ${playerId}:`, game?.id);
        
        if (game) {
          // Notify the opponent that this player left
          const opponentId = game.whitePlayerId === playerId 
            ? game.blackPlayerId 
            : game.whitePlayerId;
          
          console.log(`Notifying opponent ${opponentId} that player ${playerId} left`);
          
          const opponentSocket = this.playerSockets.get(opponentId);
          if (opponentSocket) {
            console.log(`Emitting opponentLeft event to ${opponentId}`);
            opponentSocket.emit('opponentLeft', {
              gameId: game.id,
              message: 'Your opponent has left the game',
            });
          } else {
            console.log(`Opponent socket not found for ${opponentId}`);
          }
          
          // Mark game as abandoned
          await this.gameService.abandonGame(game.id, playerId);
          console.log(`Game ${game.id} marked as abandoned`);
        }
        
        this.playerSockets.delete(playerId);
        this.socketToPlayer.delete(client.id);
      } catch (error) {
        console.error('Error in handleDisconnect:', error);
      }
    }
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

  @SubscribeMessage('leaveGame')
  async handleLeaveGame(
    @MessageBody() data: { gameId: string; playerId: string },
    @ConnectedSocket() client: Socket,
  ) {
    console.log('Player leaving game:', data);
    
    const game = await this.gameService.getGame(data.gameId);
    if (game) {
      const opponentId = game.whitePlayerId === data.playerId 
        ? game.blackPlayerId 
        : game.whitePlayerId;
      
      const opponentSocket = this.playerSockets.get(opponentId);
      if (opponentSocket) {
        console.log(`Notifying opponent ${opponentId} that player left`);
        opponentSocket.emit('opponentLeft', {
          gameId: data.gameId,
          message: 'Your opponent has left the game',
        });
      }
      
      await this.gameService.abandonGame(data.gameId, data.playerId);
    }
  }

  @SubscribeMessage('makeMove')
  async handleMove(
    @MessageBody() data: { gameId: string; playerId: string; move: MoveDto },
    @ConnectedSocket() client: Socket,
  ) {
    console.log('Move received:', data);
    const result = await this.gameService.makeMove(
      data.gameId,
      data.playerId,
      data.move,
    );

    console.log('Move result:', result);

    if (result.success) {
      console.log('Broadcasting move to room:', data.gameId);
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
    const whiteSocket = this.playerSockets.get(whitePlayerId);
    const blackSocket = this.playerSockets.get(blackPlayerId);

    if (whiteSocket) {
      whiteSocket.join(gameId);
      whiteSocket.emit('gameStarted', {
        gameId,
        whitePlayerId,
        blackPlayerId,
      });
      whiteSocket.emit('yourTurn', { gameId });
    }

    if (blackSocket) {
      blackSocket.join(gameId);
      blackSocket.emit('gameStarted', {
        gameId,
        whitePlayerId,
        blackPlayerId,
      });
    }
  }
}
