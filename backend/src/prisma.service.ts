/**
 * prisma.service.ts — Thin NestJS wrapper around the Prisma client.
 *
 * Extends PrismaClient so it can be injected like any NestJS service.
 * Opens the database connection when the module initialises and closes it
 * cleanly when the application shuts down, preventing connection leaks.
 */
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  /** Called by NestJS once the module is ready — opens the DB connection. */
  async onModuleInit() {
    await this.$connect();
  }

  /** Called on graceful shutdown — closes the DB connection. */
  async onModuleDestroy() {
    await this.$disconnect();
  }
}
