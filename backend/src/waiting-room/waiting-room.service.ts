import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { GameService } from '../game/game.service';
import { GameGateway } from '../game/game.gateway';

@Injectable()
export class WaitingRoomService {
  constructor(
    private prisma: PrismaService,
    private gameService: GameService,
    private gameGateway: GameGateway,
  ) {}

  async joinWaitingRoom(playerId: string): Promise<any> {
    const existingPlayer = await this.prisma.waitingPlayer.findUnique({
      where: { playerId },
    });

    if (existingPlayer) {
      return { status: 'already_waiting', playerId };
    }

    const waitingPlayers = await this.prisma.waitingPlayer.findMany();

    if (waitingPlayers.length > 0) {
      const opponent = waitingPlayers[0];
      
      await this.prisma.waitingPlayer.delete({
        where: { id: opponent.id },
      });

      const whitePlayerId = Math.random() > 0.5 ? playerId : opponent.playerId;
      const blackPlayerId = whitePlayerId === playerId ? opponent.playerId : playerId;

      const game = await this.gameService.createGame(whitePlayerId, blackPlayerId);

      this.gameGateway.notifyGameStart(game.id, whitePlayerId, blackPlayerId);

      return {
        status: 'game_created',
        gameId: game.id,
        whitePlayerId,
        blackPlayerId,
        yourColor: playerId === whitePlayerId ? 'white' : 'black',
      };
    } else {
      await this.prisma.waitingPlayer.create({
        data: { playerId },
      });

      return { status: 'waiting', playerId };
    }
  }

  async leaveWaitingRoom(playerId: string): Promise<void> {
    await this.prisma.waitingPlayer.deleteMany({
      where: { playerId },
    });
  }

  async getWaitingPlayers(): Promise<any[]> {
    return this.prisma.waitingPlayer.findMany();
  }

  async invitePlayer(inviterId: string, invitedId: string): Promise<any> {
    const whitePlayerId = Math.random() > 0.5 ? inviterId : invitedId;
    const blackPlayerId = whitePlayerId === inviterId ? invitedId : inviterId;

    const game = await this.gameService.createGame(whitePlayerId, blackPlayerId);

    this.gameGateway.notifyGameStart(game.id, whitePlayerId, blackPlayerId);

    return {
      status: 'game_created',
      gameId: game.id,
      whitePlayerId,
      blackPlayerId,
    };
  }
}
