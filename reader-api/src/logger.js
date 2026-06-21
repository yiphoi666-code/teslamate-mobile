const crypto = require('crypto');
const { AsyncLocalStorage } = require('async_hooks');

const MAX_SQL_LENGTH = 900;
const MAX_PARAM_LENGTH = 160;
const requestContext = new AsyncLocalStorage();

function info(event, fields = {}) {
  write('info', event, fields);
}

function warn(event, fields = {}) {
  write('warn', event, fields);
}

function error(event, fields = {}) {
  write('error', event, fields);
}

function write(level, event, fields) {
  const payload = {
    ts: new Date().toISOString(),
    level,
    event,
    ...fields,
  };

  const line = JSON.stringify(payload);
  if (level === 'error') {
    console.error(line);
    return;
  }

  console.log(line);
}

function createRequestId() {
  return crypto.randomUUID();
}

function apiLogger(req, res, next) {
  const startedAt = process.hrtime.bigint();
  req.requestId = req.header('x-request-id') || createRequestId();

  info('api_request_started', {
    requestId: req.requestId,
    method: req.method,
    path: req.path,
    query: sanitizeQuery(req.query),
    ip: req.ip,
    userAgent: req.header('user-agent') || null,
  });

  res.on('finish', () => {
    const durationMs = elapsedMs(startedAt);
    const fields = {
      requestId: req.requestId,
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      durationMs,
      contentLength: res.getHeader('content-length') || null,
    };

    if (res.statusCode >= 500) {
      error('api_request_completed', fields);
    } else if (res.statusCode >= 400) {
      warn('api_request_completed', fields);
    } else {
      info('api_request_completed', fields);
    }
  });

  requestContext.run({ requestId: req.requestId }, next);
}

function logQueryStarted(queryId, text, params) {
  info('db_query_started', {
    requestId: currentRequestId(),
    queryId,
    sql: sanitizeSql(text),
    params: sanitizeParams(params),
  });
}

function logQueryCompleted(queryId, startedAt, result) {
  info('db_query_completed', {
    requestId: currentRequestId(),
    queryId,
    durationMs: elapsedMs(startedAt),
    rowCount: typeof result?.rowCount === 'number' ? result.rowCount : null,
  });
}

function logQueryFailed(queryId, startedAt, errorValue) {
  error('db_query_failed', {
    requestId: currentRequestId(),
    queryId,
    durationMs: elapsedMs(startedAt),
    error: errorValue.message,
    code: errorValue.code || null,
  });
}

function sanitizeSql(text) {
  return truncate(String(text || '').replace(/\s+/g, ' ').trim(), MAX_SQL_LENGTH);
}

function sanitizeParams(params) {
  if (!Array.isArray(params) || params.length === 0) {
    return [];
  }

  return params.map((value) => sanitizeParam(value));
}

function sanitizeQuery(query) {
  const safe = {};
  for (const [key, value] of Object.entries(query || {})) {
    safe[key] = sanitizeParam(value);
  }
  return safe;
}

function sanitizeParam(value) {
  if (value === null || value === undefined) {
    return value;
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item) => sanitizeParam(item));
  }

  if (typeof value === 'object') {
    return '[object]';
  }

  return truncate(String(value), MAX_PARAM_LENGTH);
}

function truncate(value, maxLength) {
  if (value.length <= maxLength) {
    return value;
  }

  return `${value.slice(0, maxLength)}...`;
}

function elapsedMs(startedAt) {
  return Number((process.hrtime.bigint() - startedAt) / 1000000n);
}

function currentRequestId() {
  return requestContext.getStore()?.requestId || null;
}

module.exports = {
  apiLogger,
  createRequestId,
  currentRequestId,
  info,
  warn,
  error,
  logQueryStarted,
  logQueryCompleted,
  logQueryFailed,
};
