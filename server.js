const express = require('express');
const path = require('path');
const os = require('os');
const { Pool } = require('pg');

const PORT = process.env.PORT || 3000;

// Database connection details come from environment variables (set by Ansible / Jenkins in `docker run -e ...`)
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'employee_portal',
  user: process.env.DB_USER || 'portal_user',
  password: process.env.DB_PASSWORD || 'portal_pass',
  connectionTimeoutMillis: 5000,
});

// Create the employees table and seed sample rows on first start
async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS employees (
      id         SERIAL PRIMARY KEY,
      name       VARCHAR(100) NOT NULL,
      role       VARCHAR(100) NOT NULL,
      department VARCHAR(100) NOT NULL,
      status     VARCHAR(20)  NOT NULL DEFAULT 'Online'
    )`);
  const { rows } = await pool.query('SELECT COUNT(*)::int AS count FROM employees');
  if (rows[0].count === 0) {
    await pool.query(`
      INSERT INTO employees (name, role, department, status) VALUES
        ('Priya Sharma', 'Frontend Developer', 'Engineering', 'Online'),
        ('Rohan Mehta',  'UI Designer',        'Design',      'Offline'),
        ('Simran Kaur',  'HR Executive',       'HR',          'Online'),
        ('Arjun Verma',  'Payroll Analyst',    'Finance',     'Online'),
        ('Neha Iyer',    'DevOps Engineer',    'Engineering', 'Offline')`);
    console.log('Seeded employees table');
  }
}

const app = express();

app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'index.html')));

// Health check: proves the app can reach PostgreSQL
app.get('/api/health', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT version() AS version, current_database() AS db, NOW() AS time');
    res.json({
      status: 'ok',
      db: 'connected',
      database: rows[0].db,
      dbHost: process.env.DB_HOST,
      postgres: rows[0].version,
      time: rows[0].time,
      server: os.hostname(),
    });
  } catch (err) {
    res.status(500).json({ status: 'error', db: 'disconnected', error: err.message, server: os.hostname() });
  }
});

app.get('/api/employees', async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT id, name, role, department, status FROM employees ORDER BY id');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`Employee Portal listening on port ${PORT}`);
  initDb().catch((err) => console.error('Database init failed:', err.message));
});
