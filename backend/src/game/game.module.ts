/**
 * game.module.ts — Feature module for everything chess-game related.
 *
 * Provides and exports:
 *   • GameService   — chess.js validation, Prisma DB access
 *   • GameGateway   — Socket.io WebSocket gateway
 *
 * Both are exported so WaitingRoomModule can inject GameGateway to fire
 * WebSocket events (e.g. notifyGameStart, sendInvitation) after a game
 * is created via REST.
 */
import { Module } from '@nestjs/common';
import { GameService } from './game.service';
import { GameGateway } from './game.gateway';
import { PrismaService } from '../prisma.service';

@Module({
  providers: [GameService, GameGateway, PrismaService],
  exports: [GameService, GameGateway],
})
export class GameModule {}
