# Chess - Multiplayer Chess Mobile App

A real-time multiplayer chess application built with Flutter, featuring clean architecture and state management with Riverpod.

## Features

- **Real-time Multiplayer**: Play chess with other players in real-time
- **Waiting Room**: Automatic matchmaking system
- **Move Validation**: Server-side validation ensures fair play
- **Turn Notifications**: Get notified when it's your turn
- **Game Over Detection**: Automatic detection of checkmate, stalemate, and draws
- **Clean UI**: Modern, intuitive interface

## Tech Stack

- **Flutter**: Cross-platform mobile framework
- **Riverpod**: State management
- **Dio**: HTTP client for REST API calls
- **WebSocket**: Real-time communication
- **flutter_chess_board**: Chess board UI component

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Configure backend URL:
Edit `lib/config/api_config.dart` to point to your backend server.

3. Run the app:
```bash
flutter run
```

## Architecture

- **Models**: Data models for game state
- **Providers**: Riverpod providers for state management
- **Services**: API and WebSocket services
- **Screens**: UI screens (Main Menu, Waiting Room, Game Board)
- **Config**: Configuration files

## Screens

1. **Main Menu**: Start screen with "Find Game" option
2. **Waiting Room**: Matchmaking screen while searching for opponent
3. **Game Board**: Interactive chess board with real-time updates
