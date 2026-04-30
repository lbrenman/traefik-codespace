/**
 * Traefik ForwardAuth — Per-Service API Key Validator
 *
 * Flow:
 *   Client → Traefik → [forwardAuth] → GET /auth?service=api1 (this service)
 *                                           checks X-Api-Key header
 *                         200 → Traefik forwards to backend
 *                         401 → Traefik returns 401 to client
 *
 * API Keys come from environment variables:
 *   API_KEY_API1=<key-for-products-api>
 *   API_KEY_API2=<key-for-users-api>
 *   API_KEY_WHOAMI=<key-for-whoami>
 *
 * Add more services by adding API_KEY_<SERVICENAME>=<key> to .env
 */

const express = require('express');
const app = express();
const PORT = process.env.PORT || 9000;

// ---------------------------------------------------------------------------
// Build the key store from environment variables at startup
// Format: API_KEY_<SERVICENAME>=<key>
// ---------------------------------------------------------------------------
function buildKeyStore() {
  const store = {};
  for (const [envKey, value] of Object.entries(process.env)) {
    const match = envKey.match(/^API_KEY_(.+)$/);
    if (match && value) {
      const service = match[1].toLowerCase();
      store[service] = value;
      console.log(`  🔑 Key registered for service: "${service}"`);
    }
  }
  return store;
}

const KEY_STORE = buildKeyStore();

// ---------------------------------------------------------------------------
// Constant-time string comparison (prevents timing attacks)
// ---------------------------------------------------------------------------
function safeCompare(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

// ---------------------------------------------------------------------------
// Logger
// ---------------------------------------------------------------------------
function log(level, service, msg, extra = '') {
  const ts = new Date().toISOString();
  const emoji = level === 'ALLOW' ? '✅' : level === 'DENY' ? '🚫' : 'ℹ️ ';
  console.log(`[${ts}] ${emoji} [${level}] service=${service} | ${msg}${extra ? ' | ' + extra : ''}`);
}

// ---------------------------------------------------------------------------
// GET /health — liveness check
// ---------------------------------------------------------------------------
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    services_protected: Object.keys(KEY_STORE),
    uptime: Math.floor(process.uptime())
  });
});

// ---------------------------------------------------------------------------
// GET /keys — show which services have keys (NOT the key values)
// ---------------------------------------------------------------------------
app.get('/keys', (req, res) => {
  res.json({
    protected_services: Object.keys(KEY_STORE).map(s => ({
      service: s,
      key_configured: true,
      key_preview: KEY_STORE[s].slice(0, 4) + '****'
    }))
  });
});

// ---------------------------------------------------------------------------
// GET /auth?service=<name> — ForwardAuth endpoint
//
// Traefik calls this for every request to a protected route.
// The ?service= param tells us WHICH service's key to check.
// The X-Api-Key header contains the key the client provided.
// ---------------------------------------------------------------------------
app.get('/auth', (req, res) => {
  const serviceName  = (req.query.service || '').toLowerCase();
  const providedKey  = req.headers['x-api-key'] || '';
  const clientIp     = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

  // Missing ?service= param → misconfiguration in Traefik labels
  if (!serviceName) {
    log('ERROR', 'unknown', 'Missing ?service= param — check Traefik forwardAuth address');
    return res.status(500).json({ error: 'Auth misconfiguration: no service param' });
  }

  // No key configured for this service
  const expectedKey = KEY_STORE[serviceName];
  if (!expectedKey) {
    log('ERROR', serviceName, `No API key configured. Add API_KEY_${serviceName.toUpperCase()}=<key> to .env`);
    return res.status(500).json({ error: `No key configured for service: ${serviceName}` });
  }

  // Missing X-Api-Key header in request
  if (!providedKey) {
    log('DENY', serviceName, 'Missing X-Api-Key header', `ip=${clientIp}`);
    res.set('WWW-Authenticate', 'ApiKey realm="Traefik API"');
    return res.status(401).json({
      error: 'Unauthorized',
      hint: 'Include your API key in the X-Api-Key request header'
    });
  }

  // Wrong key
  if (!safeCompare(providedKey, expectedKey)) {
    log('DENY', serviceName, 'Invalid API key', `ip=${clientIp}`);
    res.set('WWW-Authenticate', 'ApiKey realm="Traefik API"');
    return res.status(401).json({
      error: 'Unauthorized',
      hint: 'The provided API key is incorrect'
    });
  }

  // ✅ Authorized — set a response header Traefik will forward downstream
  log('ALLOW', serviceName, 'Access granted', `ip=${clientIp}`);
  res.set('X-Authenticated-Service', serviceName);
  return res.status(200).send();
});

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------
app.listen(PORT, () => {
  console.log(`\n🔐 API Key Auth Service listening on port ${PORT}`);
  console.log(`   ForwardAuth endpoint : GET /auth?service=<name>`);
  console.log(`   Health endpoint      : GET /health`);
  console.log(`   Keys info endpoint   : GET /keys`);
  console.log(`\n   Protected services:`);
  if (Object.keys(KEY_STORE).length === 0) {
    console.log('   ⚠️  No keys loaded! Set API_KEY_<SERVICE>=<key> in your .env file');
  }
});
