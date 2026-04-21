/**
 * main.ts — Application entry point.
 *
 * Bootstraps the NestJS app, enables CORS for all origins (required for
 * Flutter Web and local development), then starts the HTTP + WebSocket server
 * on the port defined by the PORT environment variable (default 3000).
 */
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Allow requests from any origin so Flutter Web (served on a different port)
  // and mobile devices can reach the backend without CORS errors.
  app.enableCors({
    origin: '*',
    credentials: true,
  });

  const port = process.env.PORT || 3000;
  await app.listen(port);
  console.log(`Chess backend running on port ${port}`);
}

bootstrap();
