const config = require('./config');

function requireBearerToken(req, res, next) {
  if (!config.token) {
    next();
    return;
  }

  const header = req.header('authorization') || '';
  const expected = `Bearer ${config.token}`;

  if (header === expected) {
    next();
    return;
  }

  res.status(401).json({ error: 'unauthorized' });
}

module.exports = { requireBearerToken };
