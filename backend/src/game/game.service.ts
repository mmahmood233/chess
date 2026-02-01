import { Injectable } from '@nestjs/common';
import { Chess } from 'chess.js';
import { PrismaService } from '../prisma.service';
import { GameStatus, IMoveRequest, IMoveResponse } from '../common/interfaces/game.interface';

@Injectable()
export class GameService {
  constructor(private prisma: PrismaService) {}

  async createGame(whitePlayerId: string, blackPlayerId: string): Promise<any> {
    const chess = new Chess();
    
    const game = await this.prisma.game.create({
      data: {
        whitePlayerId,
        blackPlayerId,
        currentTurn: whitePlayerId,
        fen: chess.fen(),
        pgn: '',
        status: GameStatus.IN_PROGRESS,
        moveHistory: [],
      },
    });

    return game;
  }

  async getGame(gameId: string): Promise<any> {
    return this.prisma.game.findUnique({
      where: { id: gameId },
    });
  }

  async makeMove(gameId: string, playerId: string, moveRequest: IMoveRequest): Promise<IMoveResponse> {
    const game = await this.getGame(gameId);

    if (!game) {
      return { success: false, error: 'Game not found' };
    }

    if (game.status !== GameStatus.IN_PROGRESS) {
      return { success: false, error: 'Game is not in progress' };
    }

    if (game.currentTurn !== playerId) {
      return { success: false, error: 'Not your turn' };
    }

    const chess = new Chess(game.fen);

    try {
      const move = chess.move({
        from: moveRequest.from,
        to: moveRequest.to,
        promotion: moveRequest.promotion || 'q',
      });

      if (!move) {
        return { success: false, error: 'Illegal move' };
      }

      const nextTurn = game.currentTurn === game.whitePlayerId 
        ? game.blackPlayerId 
        : game.whitePlayerId;

      const isGameOver = chess.isGameOver();
      let winner: string | undefined;
      let endReason: string | undefined;

      if (isGameOver) {
        if (chess.isCheckmate()) {
          winner = playerId;
          endReason = 'checkmate';
        } else if (chess.isStalemate()) {
          endReason = 'stalemate';
        } else if (chess.isDraw()) {
          endReason = 'draw';
        } else if (chess.isThreefoldRepetition()) {
          endReason = 'threefold_repetition';
        } else if (chess.isInsufficientMaterial()) {
          endReason = 'insufficient_material';
        }
      }

      await this.prisma.game.update({
        where: { id: gameId },
        data: {
          fen: chess.fen(),
          pgn: chess.pgn(),
          currentTurn: nextTurn,
          status: isGameOver ? GameStatus.COMPLETED : GameStatus.IN_PROGRESS,
          winner,
          endReason,
          moveHistory: {
            push: `${moveRequest.from}-${moveRequest.to}`,
          },
        },
      });

      return {
        success: true,
        fen: chess.fen(),
        pgn: chess.pgn(),
        move: `${moveRequest.from}-${moveRequest.to}`,
        isGameOver,
        winner,
        endReason,
      };
    } catch (error) {
      return { success: false, error: 'Invalid move' };
    }
  }

  async deleteGame(gameId: string): Promise<void> {
    await this.prisma.game.delete({
      where: { id: gameId },
    });
  }
}
