# Database Setup Guide

You have two options to set up the PostgreSQL database:

## Option 1: Docker (Easiest - Recommended)

### Step 1: Start PostgreSQL with Docker
```bash
docker run --name chess-postgres \
  -e POSTGRES_PASSWORD=chess123 \
  -e POSTGRES_USER=chess \
  -e POSTGRES_DB=chess_db \
  -p 5432:5432 \
  -d postgres:15
```

### Step 2: Create .env file
Create a file named `.env` in the `backend/` directory with this content:
```
DATABASE_URL="postgresql://chess:chess123@localhost:5432/chess_db?schema=public"
PORT=3000
```

### Step 3: Run migrations and start
```bash
npm run prisma:migrate
npm run start:dev
```

---

## Option 2: Install PostgreSQL Locally

### For macOS (using Homebrew):
```bash
# Install PostgreSQL
brew install postgresql@15

# Start PostgreSQL service
brew services start postgresql@15

# Create database
createdb chess_db
```

### For Windows:
1. Download PostgreSQL from https://www.postgresql.org/download/windows/
2. Install with default settings
3. Remember the password you set during installation
4. Open pgAdmin or command line and create database `chess_db`

### For Linux (Ubuntu/Debian):
```bash
# Install PostgreSQL
sudo apt update
sudo apt install postgresql postgresql-contrib

# Start service
sudo systemctl start postgresql

# Create database
sudo -u postgres createdb chess_db
```

### Step 2: Create .env file
Create a file named `.env` in the `backend/` directory:

**If using default PostgreSQL installation:**
```
DATABASE_URL="postgresql://postgres:YOUR_PASSWORD@localhost:5432/chess_db?schema=public"
PORT=3000
```

Replace `YOUR_PASSWORD` with your PostgreSQL password.

### Step 3: Run migrations and start
```bash
npm run prisma:migrate
npm run start:dev
```

---

## Quick Start Commands (After Database is Running)

```bash
# Generate Prisma client
npm run prisma:generate

# Run database migrations
npm run prisma:migrate

# Start the development server
npm run start:dev
```

## Verify Database Connection

To check if your database is working:
```bash
npm run prisma:studio
```

This opens Prisma Studio in your browser where you can view your database tables.

---

## Troubleshooting

### "Connection refused" error
- Make sure PostgreSQL is running
- Check the port (default is 5432)
- Verify credentials in .env file

### "Database does not exist" error
- Create the database: `createdb chess_db`
- Or use Docker command above

### Permission denied
- Check username and password in DATABASE_URL
- For local PostgreSQL, default user is usually `postgres`
