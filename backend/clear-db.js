const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function clearWaitingRoom() {
  await prisma.waitingPlayer.deleteMany({});
  console.log('Cleared all waiting players');
  await prisma.$disconnect();
}

clearWaitingRoom();
