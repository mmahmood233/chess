const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  // Delete all games
  await prisma.game.deleteMany({});
  console.log('Cleared all games');
  
  // Delete all waiting players
  await prisma.waitingPlayer.deleteMany({});
  console.log('Cleared all waiting players');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
