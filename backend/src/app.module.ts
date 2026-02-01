import { Module } from '@nestjs/common';
import { GameModule } from './game/game.module';
import { WaitingRoomModule } from './waiting-room/waiting-room.module';
import { PrismaService } from './prisma.service';

@Module({
  imports: [GameModule, WaitingRoomModule],
  providers: [PrismaService],
})
export class AppModule {}
