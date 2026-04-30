const express = require('express');
const app = express();
const PORT = process.env.PORT || 3002;
const SERVICE_NAME = process.env.SERVICE_NAME || 'API Service 2';

app.use(express.json());

app.use((req, res, next) => {
  res.setHeader('X-Served-By', SERVICE_NAME);
  next();
});

// In-memory users store
let users = [
  { id: 1, name: 'Alice Johnson', email: 'alice@example.com', role: 'admin', active: true },
  { id: 2, name: 'Bob Smith', email: 'bob@example.com', role: 'user', active: true },
  { id: 3, name: 'Carol White', email: 'carol@example.com', role: 'user', active: false },
  { id: 4, name: 'Dave Brown', email: 'dave@example.com', role: 'moderator', active: true },
  { id: 5, name: 'Eve Davis', email: 'eve@example.com', role: 'user', active: true },
];

// GET /
app.get('/', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    description: 'Users REST API — auto-discovered by Traefik',
    version: '1.0.0',
    routes: [
      'GET  /       — Service info',
      'GET  /health — Health check',
      'GET  /users  — List all users',
      'GET  /users/:id — Get user by ID',
      'POST /users  — Create user',
      'PUT  /users/:id — Update user',
      'DELETE /users/:id — Delete user',
      'GET  /users/role/:role — Filter by role',
    ]
  });
});

// GET /health
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: SERVICE_NAME, uptime: process.uptime() });
});

// GET /users
app.get('/users', (req, res) => {
  const { active } = req.query;
  let result = users;
  if (active !== undefined) {
    result = users.filter(u => u.active === (active === 'true'));
  }
  res.json({ count: result.length, users: result });
});

// GET /users/role/:role  — must be before /users/:id
app.get('/users/role/:role', (req, res) => {
  const result = users.filter(u => u.role === req.params.role);
  res.json({ count: result.length, users: result });
});

// GET /users/:id
app.get('/users/:id', (req, res) => {
  const user = users.find(u => u.id === parseInt(req.params.id));
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json(user);
});

// POST /users
app.post('/users', (req, res) => {
  const { name, email, role } = req.body;
  if (!name || !email) {
    return res.status(400).json({ error: 'name and email are required' });
  }
  const newUser = {
    id: users.length + 1,
    name,
    email,
    role: role || 'user',
    active: true,
  };
  users.push(newUser);
  res.status(201).json(newUser);
});

// PUT /users/:id
app.put('/users/:id', (req, res) => {
  const idx = users.findIndex(u => u.id === parseInt(req.params.id));
  if (idx === -1) return res.status(404).json({ error: 'User not found' });
  users[idx] = { ...users[idx], ...req.body, id: users[idx].id };
  res.json(users[idx]);
});

// DELETE /users/:id
app.delete('/users/:id', (req, res) => {
  const idx = users.findIndex(u => u.id === parseInt(req.params.id));
  if (idx === -1) return res.status(404).json({ error: 'User not found' });
  const deleted = users.splice(idx, 1);
  res.json({ deleted: deleted[0] });
});

app.listen(PORT, () => {
  console.log(`✅ ${SERVICE_NAME} running on port ${PORT}`);
  console.log(`   Traefik will route /api2/* → this service`);
});
