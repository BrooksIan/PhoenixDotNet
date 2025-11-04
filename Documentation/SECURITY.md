# Security Policy

## Supported Versions

We actively maintain and support the following versions:

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |

## Security Best Practices

### Configuration Security

1. **Never commit sensitive data**:
   - Connection strings with credentials
   - API keys or tokens
   - Passwords or secrets
   - Use `.env` files (not committed) or environment variables for sensitive configuration

2. **Use environment variables** for configuration:
   ```bash
   # Development
   export Phoenix__Server=localhost
   
   # Production (use container service names)
   export Phoenix__Server=opdb-docker
   ```

3. **Configuration file precedence** (highest to lowest):
   - Environment variables
   - `appsettings.{Environment}.json`
   - `appsettings.json`

### Connection Security

1. **ODBC Connection Strings**:
   - Do not include credentials in connection strings if not required
   - Use environment variables for connection strings in production
   - Example: `Driver={Phoenix ODBC Driver};Host=opdb-docker;Port=8765`

2. **Network Security**:
   - Use Docker networks for container-to-container communication
   - Avoid exposing Phoenix Query Server (port 8765) or HBase REST API (port 8080) to public networks
   - Use firewall rules to restrict access to these services

3. **Production Deployment**:
   - Use container networking (`obdb-net`) for internal communication
   - Only expose necessary ports (8099 for API, 8100 for GUI)
   - Do not expose Phoenix Query Server or HBase REST API directly to the internet

### File Security

1. **Configuration files**:
   - `odbcinst.ini` and `odbc.ini` are committed to the repository with standard configurations
   - These files contain driver paths that work for the Docker container setup
   - If you need custom configurations, edit these files directly (but be aware they may be overwritten on updates)

2. **Build artifacts**:
   - `ODBC/` directory contains driver binaries and should not be committed
   - `target/` and `data/` directories contain build artifacts and runtime data
   - All build artifacts are ignored by `.gitignore`

### Docker Security

1. **Image Security**:
   - Use specific image tags instead of `latest` in production
   - Regularly update base images for security patches
   - Example: `cloudera/opdb-docker:6.0.0` instead of `cloudera/opdb-docker:latest`

2. **Container Security**:
   - Run containers with non-root user when possible
   - Use read-only volumes where appropriate
   - Limit container capabilities

3. **Network Security**:
   - Use Docker bridge networks for internal communication
   - Do not use `host` networking mode in production

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email the maintainers directly with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

3. We will:
   - Acknowledge receipt within 48 hours
   - Provide a timeline for addressing the issue
   - Keep you informed of progress
   - Credit you in the security advisory (if desired)

## Security Checklist

Before deploying to production:

- [ ] All sensitive configuration is in environment variables
- [ ] No credentials or secrets are committed to git
- [ ] Docker images use specific tags (not `latest`)
- [ ] Network access is restricted (firewall rules)
- [ ] Only necessary ports are exposed
- [ ] Container networking is configured correctly
- [ ] `.env` files are not committed (in `.gitignore`)
- [ ] ODBC configuration files are not committed
- [ ] Build artifacts are not committed

## Additional Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [.NET Security Best Practices](https://docs.microsoft.com/en-us/dotnet/standard/security/)

