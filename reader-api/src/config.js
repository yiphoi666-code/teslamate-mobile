const dotenv = require('dotenv');

dotenv.config({ quiet: true });

const usingDatabaseUrl = Boolean(process.env.DATABASE_URL);

function boolFromEnv(value) {
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

const database = process.env.DATABASE_URL
  ? {
      connectionString: process.env.DATABASE_URL,
      ssl: boolFromEnv(process.env.DATABASE_SSL)
        ? { rejectUnauthorized: false }
        : false,
    }
  : {
      host: process.env.DATABASE_HOST || '127.0.0.1',
      port: Number(process.env.DATABASE_PORT || 5432),
      database: process.env.DATABASE_NAME || 'teslamate',
      user: process.env.DATABASE_USER || 'teslamate_readonly',
      password: process.env.DATABASE_PASSWORD || '',
      ssl: boolFromEnv(process.env.DATABASE_SSL)
        ? { rejectUnauthorized: false }
        : false,
    };

module.exports = {
  port: Number(process.env.PORT || 8787),
  token: process.env.READER_API_TOKEN || '',
  usingDatabaseUrl,
  databaseName: process.env.DATABASE_NAME || 'teslamate',
  databaseHost: process.env.DATABASE_HOST || '127.0.0.1',
  databasePort: Number(process.env.DATABASE_PORT || 5432),
  databaseUser: process.env.DATABASE_USER || 'teslamate_readonly',
  database,
};
