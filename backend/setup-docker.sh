#!/bin/bash

echo "🚀 Setting up Chess Backend with Docker PostgreSQL..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first:"
    echo "   https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Stop and remove existing container if it exists
echo "🧹 Cleaning up existing containers..."
docker stop chess-postgres 2>/dev/null || true
docker rm chess-postgres 2>/dev/null || true

# Start PostgreSQL container
echo "🐘 Starting PostgreSQL container..."
docker run --name chess-postgres \
  -e POSTGRES_PASSWORD=chess123 \
  -e POSTGRES_USER=chess \
  -e POSTGRES_DB=chess_db \
  -p 5432:5432 \
  -d postgres:15

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

# Create .env file
echo "📝 Creating .env file..."
cat > .env << EOF
DATABASE_URL="postgresql://chess:chess123@localhost:5432/chess_db?schema=public"
PORT=3000
EOF

echo "✅ .env file created!"

# Generate Prisma client
echo "🔧 Generating Prisma client..."
npm run prisma:generate

# Run migrations
echo "🗄️  Running database migrations..."
npm run prisma:migrate

echo ""
echo "✅ Setup complete! You can now start the server with:"
echo "   npm run start:dev"
echo ""
echo "📊 To view your database, run:"
echo "   npm run prisma:studio"
echo ""
echo "🛑 To stop the database later, run:"
echo "   docker stop chess-postgres"
