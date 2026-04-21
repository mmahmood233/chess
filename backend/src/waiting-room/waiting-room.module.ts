/**
 * waiting-room.module.ts — Feature module for matchmaking and invitations.
 *
 * Imports GameModule so WaitingRoomService can inject GameGateway (to send
 * WebSocket notifications after a game is created) and GameService (to
 * persist the new game record).
 */
import { Module } from '@nestjs/common';
import { WaitingRoomService } from './waiting-room.service';
import { WaitingRoomController } from './waiting-room.controller';
import { PrismaService } from '../prisma.service';
import { GameModule } from '../game/game.module';

@Module({
  imports: [GameModule],
  controllers: [WaitingRoomController],
  providers: [WaitingRoomService, PrismaService],
})
export class WaitingRoomModule {}
