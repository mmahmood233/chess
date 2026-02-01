import { Module } from '@nestjs/common';
import { GameService } from './game.service';
import { GameGateway } from './game.gateway';
import { PrismaService } from '../prisma.service';

@Module({
  providers: [GameService, GameGateway, PrismaService],
  exports: [GameService, GameGateway],
})
export class GameModule {}
