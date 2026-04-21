/**
 * app.module.ts — Root NestJS module.
 *
 * Imports the two feature modules that make up the application:
 *   • GameModule       — WebSocket gateway + chess move validation
 *   • WaitingRoomModule — REST matchmaking endpoints + invite flow
 *
 * PrismaService is registered here as a shared provider so it is available
 * across the entire application context.
 */
import { Module } from '@nestjs/common';
import { GameModule } from './game/game.module';
import { WaitingRoomModule } from './waiting-room/waiting-room.module';
import { PrismaService } from './prisma.service';

@Module({
  imports: [GameModule, WaitingRoomModule],
  providers: [PrismaService],
})
export class AppModule {}
