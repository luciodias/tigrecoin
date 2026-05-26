# TigreCoin — Haskell CRUD PoC

## Stack

| Layer | Technology |
|-------|-----------|
| Build | Cabal |
| HTTP  | Servant |
| DB    | `postgresql-simple` |
| Auth  | JWT (`jose`) |
| Pass  | `bcrypt` |
| Env   | `dotenv` |

## Project structure

```
tigrecoin/
├── app/Main.hs
├── src/
│   ├── App.hs
│   ├── Config.hs
│   ├── Auth/
│   │   ├── JWT.hs
│   │   └── Middleware.hs
│   ├── Database/
│   │   ├── Connection.hs
│   │   ├── Migrations.hs
│   │   └── Queries/
│   │       ├── User.hs
│   │       ├── Wallet.hs
│   │       └── Transaction.hs
│   ├── API/
│   │   ├── Auth.hs
│   │   ├── User.hs
│   │   ├── Wallet.hs
│   │   └── Transaction.hs
│   ├── Models/
│   │   ├── User.hs
│   │   ├── Wallet.hs
│   │   └── Transaction.hs
│   └── Types/
│       ├── AppM.hs
│       └── Errors.hs
├── migrations/
│   ├── 001_create_users.sql
│   ├── 002_create_wallets.sql
│   └── 003_create_transactions.sql
├── tigrecoin.cabal
├── cabal.project
├── .env.example
└── AGENTS.md
```

## Architecture

- **AppM** = `ReaderT Env Handler` (env tem pool, jwtSecret, etc.)
- **Servant** type-level API combinators → handlers em AppM
- **Middleware** JWT extrai `UserId` do token e injeta no request
- **postgresql-simple** queries SQL puras com tipagem via FromRow/ToRow

### Convention: module hierarchy

```
Models       → types + FromRow/ToRow instances
Database.Queries → funções SQL puras (appM Connection)
API          → Servant handlers (appM protegido ou público)
Auth         → JWT encode/decode + guard middleware
```

## Entity-Relationship

```
User (1) ── (1) Wallet (1) ── (N) Transaction
```

- **User**: id (UUID), name, email (UNIQUE), password_hash, role, created_at, updated_at
- **Wallet**: id (UUID), user_id (FK→User), balance (DECIMAL 15,2), created_at, updated_at
- **Transaction**: id (UUID), wallet_id (FK→Wallet), type (ENUM: deposit/withdrawal/bet/win/fee), amount, description, created_at

## API Endpoints

### Public
```
POST /api/auth/register       → User registration (cria wallet)
POST /api/auth/login           → JWT token
```

### Protected (JWT required)
```
GET    /api/users/{id}         → Show user
PUT    /api/users/{id}         → Update user
DELETE /api/users/{id}         → Delete user (role=admin)

GET    /api/wallet             → My wallet + balance
POST   /api/wallet/deposit     → Deposit coins
POST   /api/wallet/withdraw    → Withdraw coins

GET    /api/transactions       → List (paginated)
GET    /api/transactions/{id}  → Detail
```

## Auth flow

1. Register → hash bcrypt → INSERT user → INSERT wallet (balance=0)
2. Login → verify bcrypt → sign JWT `{ sub: userId, role, exp }`
3. Protected handlers extract JWT from `Authorization: Bearer <token>`

## Database Migrations

- Raw `.sql` files in `migrations/`, prefixed `NNN_description.sql`
- Runner reads files sorted by name, wraps in transaction, tracks executed names
- SQL convention: `CREATE TABLE IF NOT EXISTS`, `CREATE TYPE IF NOT EXISTS`, UUID PKs, TIMESTAMPTZ

## Coding conventions

- No comments in production code
- Pure SQL in Queries/ modules, no Template Haskell
- Explicit error types in Types/Errors.hs
- Servant `NamedRoutes` style (or standard `:<|>`)
- `newtype`s for domain primitives (UserId, WalletId, etc.)

## System requirements

- GHC 9.4+
- `cabal-install` 3.10+
- `libpq-dev` (PostgreSQL C client library)
- PostgreSQL server running (local or remote)

## Build & run commands

```bash
# Install system deps (Ubuntu/Debian)
sudo apt install libpq-dev postgresql

# Build
cabal build

# Run (requires Postgres running with .env config)
cp .env.example .env  # edit with your credentials
cabal run

# Test
cabal test

# Lint (install: cabal install hlint)
hlint src/

# Typecheck
cabal build
```

## LSP (opencode)

Haskell Language Server (HLS) 2.2.0 está instalado em `~/.local/opt/haskell-language-server-2.2.0.0/`.

```bash
# Configs adicionadas ao ~/.bashrc
export PATH="$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="/usr/lib/ghc/lib/x86_64-linux-ghc-9.4.7:$LD_LIBRARY_PATH"
```

O projeto já tem `opencode.json` configurado com HLS. Abrir arquivos `.hs` no opencode ativa o LSP automaticamente.

## Implementation order

1. `cabal init` + dependencies
2. SQL migrations
3. Models (FromRow/ToRow)
4. Database.Connection + Migrations runner
5. Database.Queries (User, Wallet, Transaction)
6. Auth.JWT + Auth.Middleware
7. API.Auth (register/login)
8. API.User (CRUD)
9. API.Wallet (deposit/withdraw)
10. API.Transaction (list/detail)
11. App.hs (mount routes, Env)
12. Main.hs (Warp)
13. .env.example + Config.hs
