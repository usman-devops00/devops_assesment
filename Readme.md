# DevOps Assesment Infrastructure

A complete DevOps infrastructure setup featuring a Node.js/TypeScript backend with PostgreSQL, HashiCorp Vault for secrets management, Traefik for reverse proxy, and full automation with Docker Compose and Ansible.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Traefik     │    │     Backend     │    │   PostgreSQL    │
│ (Reverse Proxy) │────│   (Node.js)     │────│   (Database)    │
│     :8443       │    │     :3000       │    │     :5432       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                       ┌─────────────────┐
                       │   HashiCorp     │
                       │     Vault       │
                       │   (Secrets)     │
                       │     :8200       │
                       └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Make (optional, for convenience commands)
- curl & jq (for testing)
- Ansible (optional, for automation)

### 1. Clone and Setup

```bash
# Clone the repository
git clone <your-repo>
cd devops-assesment

# Create required directories
mkdir -p vault-init/output traefik certs init-db backups

# Make scripts executable
chmod +x vault-init/init-vault.sh
chmod +x test-infrastructure.sh
```

### 2. Start Infrastructure

```bash
# Option 1: Using Make (recommended)
make up

# Option 2: Using Docker Compose directly
docker network create traefik-network
docker-compose up -d --build
```

### 3. Verify Installation

```bash
# Check service health
make health

# Run API tests
make test

# View service status
make status
```

## 📁 Project Structure

```
devops-challenge/
├── src/
│   ├── app.ts              
│   └── config.ts           
├── vault-init/
│   ├── init-vault.sh       
│   └── output/             
├── dist/                   
├── traefik/                
├── certs/                  
├── backups/                
├── package.json            
├── tsconfig.json           
├── Dockerfile              
├── docker-compose.yml     
├── Makefile               
├── setup.yml              
├── .dockerignore          
├── .env.example           
├── k6-test.js             
├── test-infrastructure.sh 
└── README.md              
```

## 🛠️ Available Commands

| Command | Description |
|---------|-------------|
| `make up` | Start all services |
| `make down` | Stop all services |
| `make logs` | View service logs |
| `make test` | Run API tests |
| `make health` | Check service health |
| `make status` | Show service status |
| `make clean` | Clean up containers/volumes |
| `make restart` | Restart all services |
| `make dev` | Quick development cycle |
| `make backup` | Backup database |
| `make monitor` | Monitor resource usage |

## 🌐 Access Points

After starting the infrastructure:

- **Backend API**: http://localhost:8443/api
- **Health Check**: http://localhost:8443/api/health
- **Users API**: http://localhost:8443/api/users
- **Traefik Dashboard**: http://localhost:8080
- **Vault UI**: http://localhost:8200
- **PostgreSQL**: localhost:5432

## 🔐 Security Features

### Vault Integration
- Database credentials stored securely in Vault
- AppRole authentication for service-to-service communication
- Automatic credential rotation support
- Policy-based access control

### Network Security
- Isolated Docker networks
- Services not exposed unless necessary
- Traefik handles SSL termination
- Non-root container execution

### Application Security
- Input validation on API endpoints
- Unique constraint violations handled gracefully
- Health checks for service monitoring
- SQL injection protection via parameterized queries

## 🌐 API Endpoints

### Health Check
```bash
GET /api/health
```
Response:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "database": "connected"
}
```

### Users Management

#### Get All Users
```bash
GET /api/users
```

#### Create User
```bash
POST /api/users
Content-Type: application/json

{
  "username": "newuser",
  "email": "user@example.com"
}
```



### Manual Testing

```bash
# Health check
curl http://localhost:8443/api/health

# List users
curl http://localhost:8443/api/users

# Create user
curl -X POST http://localhost:8443/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com"}'
```

### Automated Testing

```bash
# Run all tests
make test

# Run comprehensive infrastructure tests
./test-infra.sh

# Test specific functionality
curl -s http://localhost:8443/api/health | jq .status
```

### Load Testing with K6

```bash
# Install K6
brew install k6  

# Run load test
k6 run k6-test.js
```

## 🔧 Configuration

### Environment Variables

Key environment variables (see `.env.example` for full list):

- `DB_HOST`: Database host (default: postgres)
- `DB_PORT`: Database port (default: 5432)
- `DB_NAME`: Database name (default: devops_challenge)
- `VAULT_URL`: Vault server URL (default: http://vault:8200)
- `VAULT_TOKEN`: Vault authentication token
- `PORT`: Application port (default: 3000)

### Vault Configuration

The application uses HashiCorp Vault for secure credential management:

1. **Development Mode**: Uses root token for simplicity
2. **Production**: Should use AppRole authentication

#### AppRole Setup (Automated via Ansible)

```bash
# Enable AppRole auth
vault auth enable approle

# Create policy
vault policy write backend-policy vault-policy.hcl

# Create role
vault write auth/approle/role/backend \
  token_policies="backend-policy" \
  token_ttl=1h \
  token_max_ttl=4h
```

##  Monitoring & Logging

### Service Logs

```bash
# All services
make logs

# Specific service
docker-compose logs -f backend
docker-compose logs -f vault
docker-compose logs -f postgres
```

### Health Monitoring

```bash
# Check all services
make health

# Individual health checks
curl http://localhost:8443/api/health
curl http://localhost:8200/v1/sys/health
```

### Resource Monitoring

```bash
# View resource usage
make monitor

# Detailed stats
docker stats
```

## 🛠️ Development

### Local Development

```bash
# Start services in development mode
docker-compose up -d postgres vault traefik

# Run backend locally
npm install
npm run dev
```

### Building

```bash
# Build backend image
make build

# Full rebuild
docker-compose build --no-cache
```

### Database Access

```bash
# Connect to PostgreSQL
make shell-postgres

# Or manually
docker exec -it postgres psql -U postgres -d devops_assesment
```

## 🔄 Backup & Recovery

### Database Backup

```bash
# Create backup
make backup

# Manual backup
docker exec postgres pg_dump -U postgres devops_assesment > backup.sql
```

### Restore Database

```bash
# Restore from backup
docker exec -i postgres psql -U postgres -d devops_assesment < backup.sql
```

## 🚨 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check Docker daemon
docker info

# Check port conflicts
netstat -tlnp | grep :8443

# Recreate network
docker network rm traefik-network
docker network create traefik-network
```

#### Vault Authentication Issues
```bash
# Check Vault status
curl http://localhost:8200/v1/sys/health

# Reinitialize Vault
docker-compose restart vault-init
```

#### Database Connection Issues
```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Test connection
docker exec postgres pg_isready -U postgres
```

#### Backend API Issues
```bash
# Check backend logs
docker-compose logs backend

# Test health endpoint
curl http://localhost:8443/api/health
```

### Debug Mode

```bash
# Enable debug logging
export DEBUG=true

# Restart with verbose output
docker-compose up --build
```

## 🎯 What's Included

✅ **Containerization**: Multi-stage Docker build  
✅ **Reverse Proxy**: Traefik with port 8443 routing  
✅ **Database**: PostgreSQL with health checks  
✅ **Secrets Management**: HashiCorp Vault with AppRole  
✅ **Networking**: Isolated Docker networks  
✅ **Automation**: Make commands and Ansible playbooks  
✅ **Testing**: Comprehensive test suite and K6 load testing  
✅ **Security**: Non-root containers, input validation  
✅ **Monitoring**: Health checks and logging  



