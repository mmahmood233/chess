# Testing Guide

This guide will help you test the multiplayer chess application.

## Prerequisites

- PostgreSQL database running
- Node.js and npm installed
- Flutter SDK installed
- Two devices/emulators for testing multiplayer

## Backend Setup & Testing

### 1. Set Up Database

Create a PostgreSQL database:
```bash
createdb chess_db
```

Or use Docker:
```bash
docker run --name postgres-chess -e POSTGRES_PASSWORD=password -e POSTGRES_DB=chess_db -p 5432:5432 -d postgres
```

### 2. Configure Environment

Create `.env` file in `backend/` directory:
```bash
cd backend
cp .env.example .env
```

Edit `.env`:
```
DATABASE_URL="postgresql://postgres:password@localhost:5432/chess_db?schema=public"
PORT=3000
```

### 3. Install Dependencies & Setup Database

```bash
npm install
npm run prisma:generate
npm run prisma:migrate
```

### 4. Start Backend Server

```bash
npm run start:dev
```

You should see:
```
Chess backend running on port 3000
```

### 5. Test Backend Endpoints

Test waiting room endpoint:
```bash
curl -X POST http://localhost:3000/waiting-room/join \
  -H "Content-Type: application/json" \
  -d '{"playerId": "test-player-1"}'
```

Expected response:
```json
{"status": "waiting", "playerId": "test-player-1"}
```

## Frontend Setup & Testing

### 1. Install Flutter Dependencies

```bash
cd chess_app
flutter pub get
```

### 2. Verify Backend Connection

Check `lib/config/api_config.dart`:
- For iOS Simulator: Use `http://localhost:3000`
- For Android Emulator: Use `http://10.0.2.2:3000`
- For Physical Device: Use your computer's IP (e.g., `http://192.168.1.100:3000`)

### 3. Run the App

```bash
flutter run
```

## Testing Scenarios

### Scenario 1: Basic Matchmaking

**Steps:**
1. Start backend server
2. Launch app on Device 1
3. Click "Find Game"
4. Launch app on Device 2
5. Click "Find Game"

**Expected:**
- Both players enter waiting room
- Players are automatically matched
- Game board appears on both devices
- One player has white pieces, other has black
- White player can move first

### Scenario 2: Move Validation

**Steps:**
1. Start a game between two players
2. Try to make an illegal move (e.g., move pawn 3 squares)
3. Try to move opponent's pieces
4. Try to move when it's not your turn

**Expected:**
- Illegal moves are rejected
- Board resets to previous position
- Error message appears
- Only valid moves are accepted

### Scenario 3: Turn Notifications

**Steps:**
1. Start a game
2. White player makes a move
3. Observe black player's device

**Expected:**
- Black player receives "Your turn!" notification
- Turn indicator updates
- Board updates with opponent's move

### Scenario 4: Checkmate

**Steps:**
1. Start a game
2. Play until checkmate (or use Scholar's Mate for quick test)

**Scholar's Mate moves:**
- White: e4
- Black: e5
- White: Bc4
- Black: Nc6
- White: Qh5
- Black: Nf6
- White: Qxf7# (checkmate)

**Expected:**
- Game over dialog appears on both devices
- Winner is announced
- Message: "You won by checkmate!" or "You lost by checkmate!"
- Option to return to main menu

### Scenario 5: Stalemate

**Steps:**
1. Play until stalemate position
2. Make the stalemating move

**Expected:**
- Game over dialog appears
- Message: "Draw by stalemate!"
- Both players see the same result

### Scenario 6: Reconnection

**Steps:**
1. Start a game
2. Close app on one device
3. Reopen app
4. Navigate back to game

**Expected:**
- Game state is preserved
- Board shows current position
- Player can continue playing

### Scenario 7: Waiting Room Cancellation

**Steps:**
1. Click "Find Game"
2. Enter waiting room
3. Click "Cancel"

**Expected:**
- Return to main menu
- Player removed from waiting room
- No game created

## Functional Requirements Checklist

### UI Screens
- ✅ Main menu screen
- ✅ Game board screen
- ✅ Waiting room screen

### Multiplayer Features
- ✅ Real-time matches enabled
- ✅ Players can join public games
- ✅ Waiting room for matchmaking
- ✅ White pieces play first
- ✅ Turn notifications

### Game Logic
- ✅ Move validation (illegal moves prevented)
- ✅ Chess rules enforced
- ✅ Checkmate detection
- ✅ Stalemate detection
- ✅ Draw detection

### Backend
- ✅ UUID generated for each game session
- ✅ Game state management
- ✅ WebSocket real-time communication
- ✅ Game over messages sent to both players

## Common Issues & Solutions

### Issue: Backend won't start
**Solution:** 
- Check PostgreSQL is running
- Verify DATABASE_URL in .env
- Run `npm run prisma:generate`

### Issue: Flutter app can't connect to backend
**Solution:**
- Check backend is running on port 3000
- Update API URL in `api_config.dart` for your device
- For Android emulator, use `10.0.2.2` instead of `localhost`

### Issue: Moves not updating in real-time
**Solution:**
- Check WebSocket connection
- Verify both players are in the same game room
- Check browser console for errors

### Issue: Game doesn't end on checkmate
**Solution:**
- Verify chess.js is properly validating moves
- Check game over detection logic in backend
- Review WebSocket event handlers

## Performance Testing

### Test 1: Multiple Concurrent Games
1. Start 4+ instances of the app
2. Create 2+ simultaneous games
3. Verify all games work independently

### Test 2: Rapid Moves
1. Make moves quickly in succession
2. Verify all moves are processed
3. Check for race conditions

### Test 3: Network Interruption
1. Start a game
2. Disable network briefly
3. Re-enable network
4. Verify game recovers

## Next Steps After Testing

Once all tests pass:
1. Deploy backend to production server
2. Update Flutter app with production API URL
3. Build release version of Flutter app
4. Test on physical devices
5. Submit to app stores (optional)

## Support

If you encounter issues:
1. Check backend logs
2. Check Flutter console output
3. Verify database state with `npm run prisma:studio`
4. Review WebSocket messages in browser dev tools
