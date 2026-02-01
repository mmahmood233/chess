import { Controller, Post, Delete, Get, Body, Param } from '@nestjs/common';
import { WaitingRoomService } from './waiting-room.service';

@Controller('waiting-room')
export class WaitingRoomController {
  constructor(private waitingRoomService: WaitingRoomService) {}

  @Post('join')
  async joinWaitingRoom(@Body() body: { playerId: string }) {
    return this.waitingRoomService.joinWaitingRoom(body.playerId);
  }

  @Delete('leave/:playerId')
  async leaveWaitingRoom(@Param('playerId') playerId: string) {
    await this.waitingRoomService.leaveWaitingRoom(playerId);
    return { message: 'Left waiting room' };
  }

  @Get('players')
  async getWaitingPlayers() {
    return this.waitingRoomService.getWaitingPlayers();
  }

  @Post('invite')
  async invitePlayer(@Body() body: { inviterId: string; invitedId: string }) {
    return this.waitingRoomService.invitePlayer(body.inviterId, body.invitedId);
  }
}
