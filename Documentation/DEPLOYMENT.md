# Deployment Guide

## Production Deployment Recommendations

### Version Pinning

**Important**: Always pin specific image versions in production instead of using `latest`.

**Current Issue**:
```yaml
# docker-compose.yml (development)
image: cloudera/opdb-docker:latest
```

**Recommended for Production**:
```yaml
# docker-compose.production.yml
image: cloudera/opdb-docker:6.0.0  # or specific version
```

**Why**: Using `latest` can cause:
- Unexpected breaking changes
- Incompatible versions between deployments
- Difficult debugging of version-specific issues
- Security vulnerabilities from untested updates

### Environment-Specific Configuration

Create separate configuration files for different environments:

1. **Development**: `docker-compose.yml` (uses `latest`)
2. **Staging**: `docker-compose.staging.yml` (uses specific version)
3. **Production**: `docker-compose.production.yml` (uses specific version)

### Example Production Configuration

```yaml
# docker-compose.production.yml
services:
  opdb-docker:
    image: cloudera/opdb-docker:6.0.0  # Specific version
    # ... rest of configuration
    
  phoenix-app:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - Phoenix__Server=opdb-docker
      - Phoenix__Port=8765
      - HBase__Server=opdb-docker
      - HBase__Port=8080
      - ASPNETCORE_ENVIRONMENT=Production
    # ... rest of configuration
```

### Security Considerations

1. **Network Security**:
   - Use Docker bridge networks for internal communication
   - Only expose necessary ports (8099, 8100)
   - Do not expose Phoenix Query Server (8765) or HBase REST API (8080) to public networks

2. **Environment Variables**:
   - Use environment variables for all configuration
   - Never commit sensitive data to git
   - Use secrets management in production (e.g., Docker secrets, Kubernetes secrets, etc.)

3. **Image Security**:
   - Use specific image tags
   - Regularly update and scan images for vulnerabilities
   - Use read-only volumes where possible

### Deployment Steps

1. **Build and Test Locally**:
   ```bash
   docker-compose -f docker-compose.production.yml build
   docker-compose -f docker-compose.production.yml up -d
   ```

2. **Verify Health**:
   ```bash
   curl http://localhost:8099/api/phoenix/health
   ```

3. **Run Tests**:
   ```bash
   cd tests && ./run_all_tests.sh
   ```

4. **Monitor Logs**:
   ```bash
   docker-compose -f docker-compose.production.yml logs -f
   ```

### Scaling Considerations

For production scaling:

1. **Horizontal Scaling**: Run multiple `phoenix-app` instances behind a load balancer
2. **Database Scaling**: Phoenix/HBase cluster configuration (beyond scope of this guide)
3. **Resource Limits**: Set appropriate CPU and memory limits in Docker Compose

### Monitoring and Logging

1. **Health Checks**: Use the built-in health check endpoint
2. **Logging**: Configure logging levels for production
3. **Metrics**: Consider adding application metrics (Prometheus, etc.)

### Backup and Recovery

1. **HBase Data**: Configure HBase backup strategies
2. **Configuration**: Version control all configuration files
3. **Disaster Recovery**: Document recovery procedures

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Security Best Practices](./SECURITY.md)
- [Setup Guide](./SETUP.md) - Docker build setup
- [Troubleshooting Guide](./TROUBLESHOOTING.md)

