# Runbook

Build:

```powershell
cd apps/backend
npm run build
```

Run API:

```powershell
npm start
```

Run worker:

```powershell
npm run worker
```

Run scheduler:

```powershell
npm run scheduler
```

Validate:

```powershell
npm test
```

If PostgreSQL is unavailable, reject writes and keep the instance unready. If Redis is unavailable, continue durable PostgreSQL operations and degrade cache, presence and typing behavior.
