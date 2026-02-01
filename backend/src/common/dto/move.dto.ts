export class MoveDto {
  from: string;
  to: string;
  promotion?: string;
}

export class JoinGameDto {
  playerId: string;
}

export class CreateGameDto {
  playerId: string;
  invitedPlayerId?: string;
}
