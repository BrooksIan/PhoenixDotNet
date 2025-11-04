# Setup Instructions

## Quick Setup for Docker Builds

The ODBC configuration files (`odbcinst.ini` and `odbc.ini`) are included in the repository and ready to use. No setup is required before building Docker images.

### Optional: Customize Configuration

If you need to customize the ODBC configuration for your environment:

1. **Edit `odbcinst.ini`** if you need to change the driver path or driver name
2. **Edit `odbc.ini`** if you want to use DSN connections (optional)

### Verify Configuration (Optional)

Check that `odbcinst.ini` has the correct driver path:

```bash
cat odbcinst.ini
```

The driver path should match where the Phoenix ODBC driver is installed:
- Default: `/usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc_sb64.so`

### Step 3: Build Docker Image

Now you can build the Docker image:

```bash
docker-compose build
# or
docker build -t phoenix-dotnet-app .
```

## Configuration Files

The `Dockerfile` copies `odbcinst.ini` to `/etc/odbcinst.ini` in the container. This file:
- Registers the Phoenix ODBC driver with unixODBC
- Is required for ODBC connections to work
- Contains driver paths specific to the Docker container setup

The files are committed to the repository with standard configurations that work for most setups.

## Alternative: Local Development Without Docker

If you're running locally (not using Docker), you can:

1. **Install ODBC driver** on your local machine
2. **Configure `/etc/odbcinst.ini`** (or `~/.odbcinst.ini` on macOS) directly
3. **Use the example file as a template** for your local configuration

For more details, see:
- [ODBC_INSTALLATION.md](./ODBC_INSTALLATION.md)
- [PHOENIX_ODBC_SETUP.md](./PHOENIX_ODBC_SETUP.md)

## Optional: DSN Configuration

The `odbc.ini` file is included in the repository. If you want to use DSN connections (optional - DSN-less connections work fine), you can edit `odbc.ini` with your connection details.

## Troubleshooting

### Error: "odbcinst.ini not found" during Docker build

**Solution**: The `odbcinst.ini` file should be in the repository. If it's missing, restore it from git or copy from the example:

```bash
git checkout odbcinst.ini
# or
cp odbcinst.ini.example odbcinst.ini
```

### Error: "Driver not found" at runtime

**Solution**: Check that the driver path in `odbcinst.ini` matches where the driver is actually installed in the container.

### For More Help

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for more troubleshooting steps.

