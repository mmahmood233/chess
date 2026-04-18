import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { GameService } from '../game/game.service';
import { GameGateway } from '../game/game.gateway';

const STARTING_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

@Injectable()
export class WaitingRoomService {
  constructor(
    private prisma: PrismaService,
    private gameService: GameService,
    private gameGateway: GameGateway,
  ) {}

  async joinWaitingRoom(playerId: string): Promise<any> {
    // Remove any stale entries for this player
    await this.prisma.waitingPlayer.deleteMany({ where: { playerId } });

    // Don't match a player against themselves (shouldn't happen, but guard it)
    const waitingPlayers = await this.prisma.waitingPlayer.findMany({
      where: { NOT: { playerId } },
      orderBy: { createdAt: 'asc' },
    });

    if (waitingPlayers.length > 0) {
      const opponent = waitingPlayers[0];

      await this.prisma.waitingPlayer.delete({ where: { id: opponent.id } });

      // Randomly assign colours
      const whitePlayerId = Math.random() > 0.5 ? playerId : opponent.playerId;
      const blackPlayerId =
        whitePlayerId === playerId ? opponent.playerId : playerId;

      const game = await this.gameService.createGame(
        whitePlayerId,
        blackPlayerId,
      );

      this.gameGateway.notifyGameStart(
        game.id,
        whitePlayerId,
        blackPlayerId,
        game.fen ?? STARTING_FEN,
      );

      return {
        status: 'game_created',
        gameId: game.id,
        whitePlayerId,
        blackPlayerId,
        yourColor: playerId === whitePlayerId ? 'white' : 'black',
      };
    }

    // No opponent yet — add to waiting list
    await this.prisma.waitingPlayer.create({ data: { playerId } });
    return { status: 'waiting', playerId };
  }

  async leaveWaitingRoom(playerId: string): Promise<void> {
    await this.prisma.waitingPlayer.deleteMany({ where: { playerId } });
  }

  async getWaitingPlayers(): Promise<any[]> {
    return this.prisma.waitingPlayer.findMany();
  }

  async invitePlayer(inviterId: string, invitedId: string): Promise<any> {
    this.gameGateway.sendInvitation(inviterId, invitedId);
    return { status: 'invitation_sent', inviterId, invitedId };
  }

  async acceptInvite(inviterId: string, invitedId: string): Promise<any> {
    const whitePlayerId = Math.random() > 0.5 ? inviterId : invitedId;
    const blackPlayerId =
      whitePlayerId === inviterId ? invitedId : inviterId;

    const game = await this.gameService.createGame(whitePlayerId, blackPlayerId);

    this.gameGateway.notifyGameStart(
      game.id,
      whitePlayerId,
      blackPlayerId,
      game.fen ?? STARTING_FEN,
    );

    return {
      status: 'game_created',
      gameId: game.id,
      whitePlayerId,
      blackPlayerId,
    };
  }

  async declineInvite(inviterId: string, invitedId: string): Promise<any> {
    this.gameGateway.notifyInviteDeclined(inviterId, invitedId);
    return { status: 'invitation_declined' };
  }
}
