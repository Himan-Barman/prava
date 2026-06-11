# Deployment Topology

Initial production topology:

- 2+ API instances.
- 2+ WebSocket-capable API instances or dedicated realtime-gateway instances.
- 2+ worker instances.
- 1 scheduler leader.
- Managed PostgreSQL.
- Managed Redis.
- Cloudinary or S3-compatible media storage.
- Central logs and metrics.
- Automated PostgreSQL backups.

Use `/api/health` for liveness and `/api/ready` for readiness.
