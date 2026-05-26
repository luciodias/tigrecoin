# TigreCoin

Prova de conceito de uma carteira digital em Haskell, construída com **Servant**, **postgresql-simple** e autenticação **JWT**.

## Funcionalidades

- Registro e login de usuários com hash bcrypt
- Carteira com saldo (depósito e saque)
- Histórico de transações completo
- Autenticação via JWT
- Migrations SQL automáticas

## Stack

| Camada     | Tecnologia         |
|------------|--------------------|
| Build      | Cabal              |
| HTTP       | Servant            |
| Banco      | postgresql-simple  |
| Auth       | JWT (jose)         |
| Senhas     | bcrypt             |
| Ambiente   | dotenv             |

## Pré-requisitos

- GHC 9.4+
- `cabal-install` 3.10+
- PostgreSQL rodando (local ou remoto)
- `libpq-dev` (Ubuntu/Debian)

```bash
sudo apt install libpq-dev postgresql
```

## Quickstart

```bash
# 1. Clone o repositório
git clone <url>
cd tigrecoin

# 2. Configure o ambiente
cp .env.example .env
# Edite .env com suas credenciais:
#   DATABASE_URL=postgres://user:pass@localhost:5432/tigrecoin
#   JWT_SECRET=uma-chave-secreta-aleatoria
#   PORT=8080

# 3. Crie o banco de dados
sudo -u postgres createdb tigrecoin

# 4. Build e execute (migrations rodam automaticamente)
cabal run
```

## Estrutura do Projeto

```
tigrecoin/
├── app/Main.hs                  # Entry point (Warp server)
├── src/
│   ├── App.hs                   # Montagem das rotas Servant
│   ├── Config.hs                # Tipo Env (pool, jwtSecret, etc.)
│   ├── Auth/
│   │   ├── JWT.hs               # Geração/verificação de tokens
│   │   └── Middleware.hs        # Guard de autenticação
│   ├── Database/
│   │   ├── Connection.hs        # Pool de conexões
│   │   ├── Migrations.hs        # Runner de migrations
│   │   └── Queries/
│   │       ├── User.hs          # SQL para usuários
│   │       ├── Wallet.hs        # SQL para carteiras
│   │       └── Transaction.hs   # SQL para transações
│   ├── API/
│   │   ├── Auth.hs              # POST /auth/register, /auth/login
│   │   ├── User.hs              # GET/PUT/DELETE /users/{id}
│   │   ├── Wallet.hs            # GET /wallet, POST /wallet/deposit/withdraw
│   │   └── Transaction.hs       # GET /transactions, /transactions/{id}
│   ├── Models/
│   │   ├── User.hs              # Tipos User, RegisterRequest, etc.
│   │   ├── Wallet.hs            # Tipo Wallet
│   │   └── Transaction.hs       # Tipo Transaction
│   └── Types/
│       ├── AppM.hs              # Monad AppM (ReaderT Env Handler)
│       └── Errors.hs            # Tipos de erro da API
├── migrations/
│   ├── 001_create_users.sql
│   ├── 002_create_wallets.sql
│   └── 003_create_transactions.sql
├── test/
│   ├── Spec.hs                  # Main dos testes
│   ├── Helper.hs                # Setup compartilhado (pool, tokens, etc.)
│   ├── Auth/JWTSpec.hs
│   └── API/
│       ├── AuthSpec.hs
│       ├── WalletSpec.hs
│       ├── UserSpec.hs
│       └── TransactionSpec.hs
├── tigrecoin.cabal
├── cabal.project
├── .env.example
└── AGENTS.md
```

## API Endpoints

### Públicos

```
POST /api/auth/register    → Registro de usuário (cria carteira automaticamente)
POST /api/auth/login       → Login, retorna token JWT
```

### Protegidos (Bearer token)

```
GET    /api/users/{id}         → Dados do usuário
PUT    /api/users/{id}         → Atualizar usuário
DELETE /api/users/{id}         → Deletar usuário (role=admin)

GET    /api/wallet             → Saldo da carteira
POST   /api/wallet/deposit     → Depositar coins
POST   /api/wallet/withdraw    → Sacar coins

GET    /api/transactions       → Listar transações (paginado)
GET    /api/transactions/{id}  → Detalhe da transação
```

### Exemplos com curl

```bash
# Registrar
curl -s -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@test.com","password":"secret"}'

# Login
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@test.com","password":"secret"}' | tr -d '"')

# Ver carteira
curl -s http://localhost:8080/api/api/wallet \
  -H "Authorization: Bearer $TOKEN"

# Depositar
curl -s -X POST http://localhost:8080/api/wallet/deposit \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": 100.0}'

# Listar transações
curl -s http://localhost:8080/api/transactions \
  -H "Authorization: Bearer $TOKEN"
```

## Build

```bash
cabal build
```

Para build com otimização:

```bash
cabal build --enable-optimization
```

## Testes

```bash
# 1. Crie o banco de testes
sudo -u postgres createdb tigrecoin_test

# 2. Execute os testes
cabal test
```

Os testes criam e destroem o schema automaticamente (via `TRUNCATE`). O banco de testes é configurado pela variável `DATABASE_URL_TEST`; se não definida, o fallback é `postgres://postgres:postgres@localhost:5432/tigrecoin_test`.

Para rodar com mais detalhes:

```bash
cabal test --test-show-details=direct
```

### Lint

```bash
cabal install hlint   # apenas na primeira vez
hlint src/
```

## Migrations

As migrations rodam **automaticamente** na inicialização do servidor e dos testes.

Os arquivos SQL ficam em `migrations/` com prefixo numérico. O runner:

1. Cria a tabela de controle `_migrations`
2. Compara os arquivos pendentes com os já executados
3. Aplica cada migration pendente dentro de uma transação

Para adicionar uma nova migration, crie `migrations/004_descricao.sql`.

## Arquitetura

- **AppM** = `ReaderT Env Handler` — monad principal que carrega pool de conexão, segredo JWT e expiry
- Queries SQL puras em `Database.Queries.*` com tipagem via `FromRow`/`ToRow`
- Handlers Servant em `API.*` operam em `AppM`
- Middleware JWT extrai `UserId` do token e injeta no request
- Erros explicitamente tipados em `Types.Errors`

```
User (1) ── (1) Wallet (1) ── (N) Transaction
```

## Variáveis de Ambiente

| Variável           | Obrigatória | Default | Descrição                     |
|--------------------|-------------|---------|-------------------------------|
| `DATABASE_URL`     | Sim         | —       | String de conexão PostgreSQL  |
| `JWT_SECRET`       | Sim         | —       | Chave secreta para assinar JWT|
| `PORT`             | Não         | 8080    | Porta do servidor HTTP        |
| `DATABASE_URL_TEST`| Não         | —       | Conexão para testes (opcional)|
