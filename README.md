# Shire

Monorepo for a local-first desktop coding assistant.

## Tech Stack

- Bun workspaces + Turborepo
- Electron + React (`apps/desktop`)
- SQLite + Drizzle (`packages/db`)
- Local tools package (`packages/tools`)

## Quickstart

### 1. Install dependencies

```bash
bun install
```

### 2. Run the app in development

```bash
bun run dev
```

### 3. Build all packages

```bash
bun run build
```

## Database Commands

Generate migrations:

```bash
bun run generate
```

Run migrations:

```bash
bun run migrate
```

Run migrations directly with a database path:

```bash
bun run --filter @shire/db migrate ./shire.db
```

## Useful Workspace Commands

Clean build outputs:

```bash
bun run clean
```

Build desktop app only:

```bash
bun run --filter @shire/desktop build
```

Create distributable desktop binaries:

```bash
bun run --filter @shire/desktop dist
```
