# Chess Backend

Multiplayer Chess Backend built with NestJS, TypeScript, Socket.io, chess.js, and PostgreSQL.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Set up environment variables:
```bash
cp .env.example .env
```

Edit `.env` and configure your PostgreSQL database URL.

3. Generate Prisma client and run migrations:
```bash
npm run prisma:generate
npm run prisma:migrate
```

4. Start the development server:
```bash
npm run start:dev
```

The server will run on `http://localhost:3000`.

## API Endpoints

### REST Endpoints

- `POST /waiting-room/join` - Join the waiting room
- `DELETE /waiting-room/leave/:playerId` - Leave the waiting room
- `GET /waiting-room/players` - Get all waiting players
- `POST /waiting-room/invite` - Invite a player to a game

### WebSocket Events

#### Client to Server:
- `register` - Register player socket connection
- `joinGame` - Join a game room
- `makeMove` - Make a chess move

#### Server to Client:
- `registered` - Confirmation of registration
- `playerJoined` - Player joined the game
- `moveMade` - Move was successfully made
- `yourTurn` - Notification that it's your turn
- `gameOver` - Game has ended
- `moveError` - Move was invalid

## Architecture

- **Game Service**: Handles chess logic and move validation using chess.js
- **Game Gateway**: WebSocket handler for real-time game communication
- **Waiting Room Service**: Manages matchmaking and game creation
- **Prisma**: Database ORM for PostgreSQL
