# Docker Deployment Guide

This guide explains how to deploy the PhoenixDotNet application in a Docker container.

## Prerequisites

- Docker Engine 20.10 or later
- Docker Compose 2.0 or later

## Quick Start

### Build and Run with Docker Compose

The easiest way to deploy everything (Phoenix + Application) is using Docker Compose:

```bash
# Build and start all services
docker-compose up --build

# Or run in detached mode
docker-compose up --build -d

# View logs
docker-compose logs -f phoenix-app

# Stop all services
docker-compose down
```

### Build Docker Image Manually

If you want to build the Docker image separately:

```bash
# Build the image
docker build -t phoenix-dotnet-app:latest .

# Run the container (requires Phoenix to be running separately)
docker run --rm \
  --network phoenixdotnet_obdb-net \
  -e Phoenix__Server=opdb-docker \
  -e Phoenix__Port=8765 \
  -e Phoenix__ConnectionString="Driver={Phoenix};Server=opdb-docker;Port=8765" \
  phoenix-dotnet-app:latest
```

## Docker Compose Services

The `docker-compose.yml` file includes two services:

1. **opdb-docker**: Apache Phoenix Query Server (port 8765)
2. **phoenix-app**: The .NET application container

Both services are connected via the `obdb-net` network, allowing the application to communicate with Phoenix using the service name `opdb-docker`.

## Configuration

### Environment Variables

The application can be configured via environment variables in the docker-compose.yml:

```yaml
environment:
  - Phoenix__Server=opdb-docker      # Phoenix service name
  - Phoenix__Port=8765               # Phoenix Query Server port
  - Phoenix__ConnectionString=...    # Full connection string
```

### Configuration Files

The application supports environment-specific configuration:

- `appsettings.json` - Base configuration
- `appsettings.Development.json` - Development settings (localhost)
- `appsettings.Production.json` - Production settings (container networking)

In containers, environment variables override configuration file values.

## Container Networking

The application container connects to Phoenix using Docker's internal DNS:

- **Service Name**: `opdb-docker` (defined in docker-compose.yml)
- **Port**: `8765` (internal container port)
- **Network**: `obdb-net` (bridge network)

## ODBC Driver in Container

The Dockerfile installs `unixODBC` and `unixODBC-dev` packages. However, you may need to:

1. **Install a Phoenix ODBC Driver**: Copy the driver files into the container
2. **Configure `/etc/odbcinst.ini`**: Register the ODBC driver
3. **Configure `/etc/odbc.ini`**: Set up DSN if needed

### Example: Adding ODBC Driver to Dockerfile

If you have a Phoenix ODBC driver, you can add it to the Dockerfile:

```dockerfile
# In the runtime stage
COPY phoenix-odbc-driver.so /usr/lib/x86_64-linux-gnu/odbc/
COPY odbcinst.ini /etc/odbcinst.ini
```

## Running the Application

### View Application Logs

```bash
# Follow logs
docker-compose logs -f phoenix-app

# View last 100 lines
docker-compose logs --tail=100 phoenix-app
```

### Run Interactively

To run the container interactively and see output:

```yaml
# In docker-compose.yml, uncomment:
stdin_open: true
tty: true
```

Then:
```bash
docker-compose up phoenix-app
```

### Execute Commands in Container

```bash
# Open a shell in the running container
docker-compose exec phoenix-app /bin/bash

# Check ODBC drivers
odbcinst -q -d

# Test connection
odbcinst -q -s
```

## Troubleshooting

### Container Cannot Connect to Phoenix

1. **Check network connectivity**:
   ```bash
   docker-compose exec phoenix-app ping opdb-docker
   ```

2. **Verify Phoenix is running**:
   ```bash
   docker-compose ps
   docker-compose logs opdb-docker
   ```

3. **Check port accessibility**:
   ```bash
   docker-compose exec phoenix-app nc -zv opdb-docker 8765
   ```

### ODBC Driver Issues

1. **Driver not found**:
   ```bash
   # Check installed drivers
   docker-compose exec phoenix-app odbcinst -q -d
   
   # Check driver configuration
   docker-compose exec phoenix-app cat /etc/odbcinst.ini
   ```

2. **Connection string errors**:
   - Verify the driver name matches what's installed
   - Check connection string format in environment variables

### Application Errors

1. **View logs**:
   ```bash
   docker-compose logs phoenix-app
   ```

2. **Check application configuration**:
   ```bash
   docker-compose exec phoenix-app cat appsettings.json
   docker-compose exec phoenix-app env | grep Phoenix
   ```

## Production Considerations

### Security

- Use secrets management for connection strings
- Don't expose unnecessary ports
- Use read-only filesystem where possible
- Run containers as non-root user

### Performance

- Set appropriate resource limits:
  ```yaml
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 512M
  ```

### Monitoring

- Add health checks to docker-compose.yml
- Set up logging aggregation
- Monitor container metrics

### Example Health Check

```yaml
healthcheck:
  test: ["CMD", "dotnet", "PhoenixDotNet.dll", "--health-check"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

## Multi-Stage Build

The Dockerfile uses a multi-stage build:

1. **Build stage**: Uses .NET SDK to compile the application
2. **Publish stage**: Publishes the application
3. **Runtime stage**: Uses .NET Runtime (smaller image)

This results in a smaller final image (~200MB vs ~800MB with SDK).

## Building for Different Platforms

### Build for ARM64 (Apple Silicon, Raspberry Pi)

```bash
docker buildx build --platform linux/arm64 -t phoenix-dotnet-app:arm64 .
```

### Build for AMD64

```bash
docker buildx build --platform linux/amd64 -t phoenix-dotnet-app:amd64 .
```

## CI/CD Integration

### Example GitHub Actions

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker image
        run: docker build -t phoenix-dotnet-app:${{ github.sha }} .
      
      - name: Run tests (if any)
        run: docker run --rm phoenix-dotnet-app:${{ github.sha }}
```

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [.NET Docker Images](https://hub.docker.com/_/microsoft-dotnet)
- [unixODBC Documentation](http://www.unixodbc.org/)
