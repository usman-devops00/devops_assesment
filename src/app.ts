import express from 'express';
import { Pool } from 'pg';
import { initializeConfig } from './config';

const app = express();
app.use(express.json());

let pool: Pool;

async function initializeDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('Database initialized');
  } catch (error) {
    console.error('Database initialization failed:', error);
  }
}

// Health check endpoint
app.get('/api/health', async (req, res) => {
  try {
    // Check database connection
    await pool.query('SELECT 1');
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      database: 'connected',
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      database: 'disconnected',
    });
  }
});

// Get all users
app.get('/api/users', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, username, email, created_at FROM users ORDER BY id'
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create a user
app.post('/api/users', async (req, res) => {
  try {
    const { username, email } = req.body;

    if (!username || !email) {
      return res.status(400).json({ error: 'Username and email are required' });
    }

    const result = await pool.query(
      'INSERT INTO users (username, email) VALUES ($1, $2) RETURNING id, username, email, created_at',
      [username, email]
    );

    res.status(201).json(result.rows[0]);
  } catch (error: any) {
    console.error('Error creating user:', error);
    if (error.code === '23505') {
      // Unique constraint violation
      res.status(409).json({ error: 'Username or email already exists' });
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
});

async function initializeApp() {
  try {
    console.log('Initializing application...');

    // Get database configuration from Vault
    const dbConfig = await initializeConfig();
    console.log('Database configuration loaded from Vault');

    // Initialize database connection
    pool = new Pool(dbConfig);

    // Test database connection
    await pool.query('SELECT 1');
    console.log('Database connection established');

    // Initialize database tables
    await initializeDatabase();

    // Start server
    const PORT = process.env.PORT || 3000;
    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to initialize application:', error);
    process.exit(1);
  }
}

// Start the application
initializeApp();

export default app;
