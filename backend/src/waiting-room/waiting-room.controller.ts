/**
 * waiting-room.controller.ts — REST API for matchmaking and friend invitations.
 *
 * All routes are prefixed with /waiting-room.
 *
 * Endpoints:
 *   POST   /join            — Add a player to the public queue; auto-matches if
 *                             another player is already waiting.
 *   DELETE /leave/:playerId — Remove a player from the queue (e.g. they pressed
 *                             Cancel on the waiting room screen).
 *   GET    /players         — List all players currently in the queue (debug / admin).
 *   POST   /invite          — Send a direct game invitation to a specific player.
 *   POST   /accept-invite   — Accept an invitation; creates a game and notifies
 *                             both players via WebSocket.
 *   POST   /decline-invite  — Decline an invitation; notifies the inviter.
 */
import { Controller, Post, Delete, Get, Body, Param } from '@nestjs/common';
import { WaitingRoomService } from './waiting-room.service';

@Controller('waiting-room')
export class WaitingRoomController {
  constructor(private waitingRoomService: WaitingRoomService) {}

  /** Join the public matchmaking queue. Returns immediately with either
   *  { status: 'waiting' } or { status: 'game_created', gameId, … }. */
  @Post('join')
  async joinWaitingRoom(@Body() body: { playerId: string }) {
    return this.waitingRoomService.joinWaitingRoom(body.playerId);
  }

  /** Remove the player from the queue so they are no longer matched. */
  @Delete('leave/:playerId')
  async leaveWaitingRoom(@Param('playerId') playerId: string) {
    await this.waitingRoomService.leaveWaitingRoom(playerId);
    return { message: 'Left waiting room' };
  }

  /** Returns the list of players currently waiting for a match. */
  @Get('players')
  async getWaitingPlayers() {
    return this.waitingRoomService.getWaitingPlayers();
  }

  /** Deliver a game invitation to the invited player over WebSocket. */
  @Post('invite')
  async invitePlayer(@Body() body: { inviterId: string; invitedId: string }) {
    return this.waitingRoomService.invitePlayer(body.inviterId, body.invitedId);
  }

  /** Accept a pending invitation — creates a game and notifies both players. */
  @Post('accept-invite')
  async acceptInvite(@Body() body: { inviterId: string; invitedId: string }) {
    return this.waitingRoomService.acceptInvite(body.inviterId, body.invitedId);
  }

  /** Decline a pending invitation — notifies the inviter via WebSocket. */
  @Post('decline-invite')
  async declineInvite(@Body() body: { inviterId: string; invitedId: string }) {
    return this.waitingRoomService.declineInvite(body.inviterId, body.invitedId);
  }
}
