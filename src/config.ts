import vault from 'node-vault';

interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}

let databaseConfig: DatabaseConfig | null = null;

export async function initializeConfig(): Promise<DatabaseConfig> {
  if (databaseConfig) {
    return databaseConfig;
  }

  try {
    console.log('Connecting to Vault...');

    const vaultClient = vault({
      apiVersion: 'v1',
      endpoint: process.env.VAULT_URL || 'http://localhost:8200',
      token: process.env.VAULT_TOKEN,
    });

    // Read database credentials from Vault
    const result = await vaultClient.read('secret/data/database');
    const dbCredentials = result.data.data;

    databaseConfig = {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'devops_assesment',
      user: dbCredentials.username,
      password: dbCredentials.password,
    };

    console.log('Database credentials loaded from Vault');
    return databaseConfig;
  } catch (error) {
    console.error('Failed to fetch credentials from Vault:', error);

    // Fallback to environment variables for local development
    console.log('Falling back to environment variables...');
    databaseConfig = {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'devops_assesment',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'q12345',
    };

    return databaseConfig;
  }
}

export const config = {
  vault: {
    url: process.env.VAULT_URL || 'http://localhost:8200',
    token: process.env.VAULT_TOKEN || '',
  },
};
