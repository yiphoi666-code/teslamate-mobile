const { Pool } = require('pg');
const config = require('./config');
const {
  createRequestId,
  logQueryCompleted,
  logQueryFailed,
  logQueryStarted,
} = require('./logger');

const pool = new Pool(config.database);

async function query(text, params = []) {
  const queryId = createRequestId();
  const startedAt = process.hrtime.bigint();
  logQueryStarted(queryId, text, params);

  try {
    const result = await pool.query(text, params);
    logQueryCompleted(queryId, startedAt, result);
    return result;
  } catch (error) {
    logQueryFailed(queryId, startedAt, error);
    throw error;
  }
}

async function one(text, params = []) {
  const result = await query(text, params);
  return result.rows[0] || null;
}

async function checkConnection() {
  try {
    const result = await one(`
      select
        current_database() as database_name,
        current_user as user_name,
        version() as postgres_version
    `);
    return {
      connected: true,
      databaseName: result.database_name,
      userName: result.user_name,
      postgresVersion: result.postgres_version,
    };
  } catch (error) {
    return {
      connected: false,
      error: error.message,
    };
  }
}

module.exports = {
  pool,
  query,
  one,
  checkConnection,
};
