/**
 * waiting-room.service.ts — Matchmaking and invitation business logic.
 *
 * Handles two ways to start a game:
 *
 *   1. Public matchmaking (joinWaitingRoom)
 *      A player joins the queue.  If another player is already waiting the two
 *      are paired immediately; otherwise the newcomer waits until someone else
 *      joins.  Colours are assigned randomly.
 *
 *   2. Friend invitations (invitePlayer / acceptInvite / declineInvite)
 *      Player A sends an invite to Player B by UUID.  The invite is delivered
 *      over WebSocket.  If B accepts, a game is created and both players
 *      receive 'gameStarted' via WebSocket.  If B declines, A is notified.
 *
 * In both cases the game is created via GameService and players are notified
 * via GameGateway — keeping transport concerns out of this service.
 */
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { GameService } from '../game/game.service';
import { GameGateway } from '../game/game.gateway';

const STARTING_FEN =
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

@Injectable()
export class WaitingRoomService {
  constructor(
    private prisma: PrismaService,
    private gameService: GameService,
    private gameGateway: GameGateway,
  ) {}

  /**
   * Add a player to the public matchmaking queue.
   *
   * Steps:
   *   1. Remove any stale queue entry for this player (handles duplicate joins).
   *   2. Look for another waiting player (excluding self to prevent self-match).
   *   3a. If found — remove the opponent from the queue, create a game, notify
   *       both players via WebSocket, and return game details.
   *   3b. If not found — add this player to the queue and return 'waiting'.
   */
  async joinWaitingRoom(playerId: string): Promise<any> {
    // Clear stale entries so the player never matches with themselves
    await this.prisma.waitingPlayer.deleteMany({ where: { playerId } });

    // Find the earliest-joined player who is not this player
    const waitingPlayers = await this.prisma.waitingPlayer.findMany({
      where: { NOT: { playerId } },
      orderBy: { createdAt: 'asc' },
    });

    if (waitingPlayers.length > 0) {
      const opponent = waitingPlayers[0];

      // Remove the matched opponent from the queue before creating the game
      await this.prisma.waitingPlayer.delete({ where: { id: opponent.id } });

      // Randomly assign colours so neither side always gets white
      const whitePlayerId =
        Math.random() > 0.5 ? playerId : opponent.playerId;
      const blackPlayerId =
        whitePlayerId === playerId ? opponent.playerId : playerId;

      const game = await this.gameService.createGame(
        whitePlayerId,
        blackPlayerId,
      );

      // Notify both players via WebSocket that the game has started
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

    // No opponent available yet — add to the queue
    await this.prisma.waitingPlayer.create({ data: { playerId } });
    return { status: 'waiting', playerId };
  }

  /** Remove a player from the waiting queue (e.g. they pressed Cancel). */
  async leaveWaitingRoom(playerId: string): Promise<void> {
    await this.prisma.waitingPlayer.deleteMany({ where: { playerId } });
  }

  /** Returns all players currently in the queue. Used for debugging. */
  async getWaitingPlayers(): Promise<any[]> {
    return this.prisma.waitingPlayer.findMany();
  }

  /**
   * Deliver a friend invitation to the invited player's active WebSocket.
   * Always returns 'invitation_sent' — the caller (Flutter) shows a snackbar.
   * If the invited player is offline the gateway logs a warning and the invite
   * is silently dropped (they would need to be re-invited when online).
   */
  async invitePlayer(inviterId: string, invitedId: string): Promise<any> {
    this.gameGateway.sendInvitation(inviterId, invitedId);
    return { status: 'invitation_sent', inviterId, invitedId };
  }

  /**
   * Accept a pending invitation.
   * Creates a game with randomly assigned colours, then notifies both players
   * via WebSocket so they navigate to the game board.
   */
  async acceptInvite(inviterId: string, invitedId: string): Promise<any> {
    const whitePlayerId = Math.random() > 0.5 ? inviterId : invitedId;
    const blackPlayerId =
      whitePlayerId === inviterId ? invitedId : inviterId;

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
    };
  }

  /** Decline an invitation and notify the original inviter via WebSocket. */
  async declineInvite(inviterId: string, invitedId: string): Promise<any> {
    this.gameGateway.notifyInviteDeclined(inviterId, invitedId);
    return { status: 'invitation_declined' };
  }
}
