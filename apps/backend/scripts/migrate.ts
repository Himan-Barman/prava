import path from 'path';

import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { db, pool } from '../src/db';

async function run() {
  await migrate(db, {
    migrationsFolder: path.resolve(__dirname, '../src/db/migrations'),
  });
  await pool.end();
}

run().catch((err) => {
  console.error('Migration failed', err);
  process.exit(1);
});
