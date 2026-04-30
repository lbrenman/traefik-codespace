const express = require('express');
const app = express();
const PORT = process.env.PORT || 3001;
const SERVICE_NAME = process.env.SERVICE_NAME || 'API Service 1';

app.use(express.json());

// Middleware: add service identification header to every response
app.use((req, res, next) => {
  res.setHeader('X-Served-By', SERVICE_NAME);
  next();
});

// In-memory products store
let products = [
  { id: 1, name: 'Laptop Pro', category: 'Electronics', price: 1299.99, stock: 45 },
  { id: 2, name: 'Wireless Mouse', category: 'Electronics', price: 29.99, stock: 200 },
  { id: 3, name: 'Standing Desk', category: 'Furniture', price: 499.00, stock: 30 },
  { id: 4, name: 'USB-C Hub', category: 'Electronics', price: 49.99, stock: 150 },
  { id: 5, name: 'Ergonomic Chair', category: 'Furniture', price: 399.00, stock: 25 },
];

// GET /  — Service info
app.get('/', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    description: 'Products REST API — auto-discovered by Traefik',
    version: '1.0.0',
    routes: [
      'GET  /         — Service info',
      'GET  /health   — Health check',
      'GET  /products — List all products',
      'GET  /products/:id — Get product by ID',
      'POST /products — Create product',
      'PUT  /products/:id — Update product',
      'DELETE /products/:id — Delete product',
    ]
  });
});

// GET /health
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: SERVICE_NAME, uptime: process.uptime() });
});

// GET /products
app.get('/products', (req, res) => {
  const { category } = req.query;
  let result = products;
  if (category) {
    result = products.filter(p => p.category.toLowerCase() === category.toLowerCase());
  }
  res.json({ count: result.length, products: result });
});

// GET /products/:id
app.get('/products/:id', (req, res) => {
  const product = products.find(p => p.id === parseInt(req.params.id));
  if (!product) return res.status(404).json({ error: 'Product not found' });
  res.json(product);
});

// POST /products
app.post('/products', (req, res) => {
  const { name, category, price, stock } = req.body;
  if (!name || !category || price === undefined) {
    return res.status(400).json({ error: 'name, category, and price are required' });
  }
  const newProduct = {
    id: products.length + 1,
    name,
    category,
    price: parseFloat(price),
    stock: parseInt(stock) || 0,
  };
  products.push(newProduct);
  res.status(201).json(newProduct);
});

// PUT /products/:id
app.put('/products/:id', (req, res) => {
  const idx = products.findIndex(p => p.id === parseInt(req.params.id));
  if (idx === -1) return res.status(404).json({ error: 'Product not found' });
  products[idx] = { ...products[idx], ...req.body, id: products[idx].id };
  res.json(products[idx]);
});

// DELETE /products/:id
app.delete('/products/:id', (req, res) => {
  const idx = products.findIndex(p => p.id === parseInt(req.params.id));
  if (idx === -1) return res.status(404).json({ error: 'Product not found' });
  const deleted = products.splice(idx, 1);
  res.json({ deleted: deleted[0] });
});

app.listen(PORT, () => {
  console.log(`✅ ${SERVICE_NAME} running on port ${PORT}`);
  console.log(`   Traefik will route /api1/* → this service`);
});
