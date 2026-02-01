export interface IGame {
  id: string;
  whitePlayerId: string;
  blackPlayerId: string;
  currentTurn: string;
  fen: string;
  pgn: string;
  status: GameStatus;
  winner?: string;
  endReason?: string;
  moveHistory: string[];
  createdAt: Date;
  updatedAt: Date;
}

export enum GameStatus {
  WAITING = 'waiting',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
}

export enum PlayerColor {
  WHITE = 'white',
  BLACK = 'black',
}

export interface IMoveRequest {
  from: string;
  to: string;
  promotion?: string;
}

export interface IMoveResponse {
  success: boolean;
  fen?: string;
  pgn?: string;
  move?: string;
  error?: string;
  isGameOver?: boolean;
  winner?: string;
  endReason?: string;
}
