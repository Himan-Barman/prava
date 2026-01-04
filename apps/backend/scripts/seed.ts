import { pool } from '../src/db';

async function run() {
  console.log('Seed script not implemented');
  await pool.end();
}

run().catch((err) => {
  console.error('Seed failed', err);
  process.exit(1);
});
