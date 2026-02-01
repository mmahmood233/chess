# Chess - Multiplayer Chess Application

A full-stack real-time multiplayer chess application with Flutter mobile frontend and NestJS backend.

## Project Structure

```
chess/
├── backend/          # NestJS backend with WebSocket support
└── chess_app/        # Flutter mobile application
```

## Features

### Core Features
- ✅ Real-time multiplayer chess matches
- ✅ Automatic matchmaking via waiting room
- ✅ Server-side move validation using chess.js
- ✅ Turn-based gameplay with notifications
- ✅ Game state persistence with PostgreSQL
- ✅ WebSocket communication for real-time updates
- ✅ Checkmate, stalemate, and draw detection
- ✅ Clean architecture following mobile best practices

### UI Screens
- **Main Menu**: Entry point with "Find Game" option
- **Waiting Room**: Matchmaking screen with loading indicator
- **Game Board**: Interactive chess board with real-time updates

## Tech Stack

### Backend
- **NestJS**: TypeScript framework for scalable server applications
- **Socket.io**: Real-time bidirectional event-based communication
- **chess.js**: Chess engine for move validation and game logic
- **Prisma**: Modern database ORM
- **PostgreSQL**: Relational database for game state

### Frontend
- **Flutter**: Cross-platform mobile framework
- **Riverpod**: State management solution
- **Dio**: HTTP client for REST API
- **WebSocket**: Real-time communication
- **flutter_chess_board**: Chess UI component

## Setup Instructions

### Backend Setup

1. Navigate to backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Set up environment variables:
```bash
cp .env.example .env
```
Edit `.env` and configure your PostgreSQL database URL.

4. Generate Prisma client and run migrations:
```bash
npm run prisma:generate
npm run prisma:migrate
```

5. Start the development server:
```bash
npm run start:dev
```

The backend will run on `http://localhost:3000`.

### Frontend Setup

1. Navigate to Flutter app directory:
```bash
cd chess_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure backend URL (if needed):
Edit `lib/config/api_config.dart` to point to your backend server.

4. Run the app:
```bash
flutter run
```

## Architecture

### Backend Architecture
- **Authoritative Server**: All game logic and validation on server
- **WebSocket Gateway**: Real-time move broadcasting
- **Game Service**: Chess logic using chess.js library
- **Waiting Room Service**: Matchmaking and game creation
- **Prisma ORM**: Database access layer

### Frontend Architecture
- **Clean Architecture**: Separation of concerns
- **Unidirectional Data Flow**: Predictable state updates
- **Provider Pattern**: Riverpod for dependency injection
- **Layer Separation**:
  - **Models**: Data structures (GameState, PlayerColor, etc.)
  - **Services**: API and WebSocket communication
  - **Providers**: State management with Riverpod
  - **Screens**: UI components (dumb layer)

## Game Flow

1. Player opens app and clicks "Find Game"
2. Player enters waiting room
3. Backend matches two players and creates game
4. Players assigned white/black randomly
5. Game starts, white plays first
6. Players take turns making moves
7. Backend validates each move
8. Moves broadcast to both players in real-time
9. Turn notifications alert players
10. Game ends on checkmate/stalemate/draw
11. Both players receive game over message

## API Endpoints

### REST Endpoints
- `POST /waiting-room/join` - Join waiting room
- `DELETE /waiting-room/leave/:playerId` - Leave waiting room
- `GET /waiting-room/players` - Get waiting players
- `POST /waiting-room/invite` - Invite specific player

### WebSocket Events

**Client → Server:**
- `register` - Register player connection
- `joinGame` - Join game room
- `makeMove` - Submit chess move

**Server → Client:**
- `registered` - Registration confirmed
- `gameStarted` - Game created and started
- `moveMade` - Move executed successfully
- `yourTurn` - Turn notification
- `gameOver` - Game ended
- `moveError` - Invalid move rejected

## Design Principles

### Mobile Best Practices
- UI is a "dumb" layer (renders state, forwards actions)
- Unidirectional data flow
- Explicit state handling (loading, success, error, empty)
- Offline-first thinking with error handling
- Network requests with timeouts and retries
- Proper app lifecycle management
- Performance optimized (no main thread blocking)

### Backend Best Practices
- Single source of truth for game state
- Server-side validation (never trust client)
- Fair play enforcement
- Reconnection support
- Clean separation of concerns

## Testing

To test the application:

1. Start the backend server
2. Run two instances of the Flutter app (on different devices/emulators)
3. Click "Find Game" on both instances
4. Players will be matched automatically
5. Play chess in real-time!

## Future Enhancements

- Player authentication and profiles
- Game history and replay
- ELO rating system
- Private game invitations
- Chat functionality
- Time controls (blitz, rapid, classical)
- Spectator mode
- Move hints and analysis

## License

MIT
