import 'dotenv/config';

export default {
  schema: './src/db/schema',
  out: './src/db/migrations',

  dialect: 'postgresql',

  dbCredentials: {
    url: process.env.DATABASE_URL,
  },
};
