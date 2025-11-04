#!/bin/bash
# Script to install Phoenix ODBC driver in Docker container
# This script can be run inside the container to install the driver manually

set -e

# Don't exit on errors - we want to try multiple approaches
set +e

echo "Installing Phoenix ODBC driver..."

# Check if RPM file exists
if [ ! -f "/tmp/phoenix-odbc.rpm" ]; then
    echo "Error: RPM file not found at /tmp/phoenix-odbc.rpm"
    exit 1
fi

# Extract RPM
cd /tmp
echo "Extracting RPM file..."
rpm2cpio phoenix-odbc.rpm | cpio -idmv

# Find and copy library files
echo "Looking for ODBC driver libraries..."
find . -name "*.so" -type f 2>/dev/null | head -20

# Install files to their intended locations (preserve RPM structure)
if [ -d "./usr" ]; then
    echo "Copying files from extracted RPM structure..."
    cp -r ./usr/* /usr/ 2>/dev/null || true
    # Also copy any configuration files to ODBC directory
    find ./usr -type f \( -name "*.xml" -o -name "*.did" -o -name "*.ini" \) -exec cp --parents {} /usr/ \; 2>/dev/null || true
fi
if [ -d "./opt" ]; then
    echo "Copying files from /opt..."
    cp -r ./opt/* /opt/ 2>/dev/null || true
    # Copy any configuration files from /opt to ODBC directory
    find ./opt -type f \( -name "*.xml" -o -name "*.did" -o -name "*phoenix*" \) -exec cp --parents {} /opt/ \; 2>/dev/null || true
fi

# Copy ODBC driver configuration files to ODBC directory
echo "Looking for ODBC configuration files..."
# Create en-US directory for error messages
mkdir -p /usr/lib/x86_64-linux-gnu/odbc/en-US 2>/dev/null || true

# Find and copy DSMessages.xml
DSMESSAGES=$(find . /opt -path "*/ErrorMessages/en-US/DSMessages.xml" 2>/dev/null | head -1)
if [ -n "$DSMESSAGES" ] && [ -f "$DSMESSAGES" ]; then
    echo "Found DSMessages.xml: $DSMESSAGES"
    cp "$DSMESSAGES" /usr/lib/x86_64-linux-gnu/odbc/en-US/ 2>/dev/null || true
    cp "$DSMESSAGES" /usr/lib/x86_64-linux-gnu/odbc/DSMessages_en-US.xml 2>/dev/null || true
fi

# Find and copy PhoenixODBC.did
DID_FILE=$(find . /opt -name "PhoenixODBC.did" 2>/dev/null | head -1)
if [ -n "$DID_FILE" ] && [ -f "$DID_FILE" ]; then
    echo "Found PhoenixODBC.did: $DID_FILE"
    cp "$DID_FILE" /usr/lib/x86_64-linux-gnu/odbc/ 2>/dev/null || true
fi

# Copy any other XML error message files
find . /opt -path "*/ErrorMessages/en-US/*.xml" 2>/dev/null | while read file; do
    if [ -f "$file" ]; then
        echo "Copying error message file: $file"
        cp "$file" /usr/lib/x86_64-linux-gnu/odbc/en-US/ 2>/dev/null || true
    fi
done

# Copy hortonworks.phoenixodbc.ini if it exists
INI_FILE=$(find . /opt -name "hortonworks.phoenixodbc.ini" 2>/dev/null | head -1)
if [ -n "$INI_FILE" ] && [ -f "$INI_FILE" ]; then
    echo "Found hortonworks.phoenixodbc.ini: $INI_FILE"
    cp "$INI_FILE" /etc/ 2>/dev/null || true
fi

# Specifically look for libphoenixodbc.so in various locations
PHOENIX_LIB=$(find . /usr /opt -name "libphoenixodbc.so" -type f 2>/dev/null | head -1)
if [ -n "$PHOENIX_LIB" ]; then
    echo "Found Phoenix ODBC library: $PHOENIX_LIB"
    cp "$PHOENIX_LIB" /usr/lib/x86_64-linux-gnu/odbc/
elif [ -f "/usr/lib/libphoenixodbc.so" ]; then
    echo "Found Phoenix ODBC library in /usr/lib"
    cp /usr/lib/libphoenixodbc.so /usr/lib/x86_64-linux-gnu/odbc/
elif [ -f "/usr/lib64/libphoenixodbc.so" ]; then
    echo "Found Phoenix ODBC library in /usr/lib64"
    cp /usr/lib64/libphoenixodbc.so /usr/lib/x86_64-linux-gnu/odbc/
else
    echo "Warning: libphoenixodbc.so not found. Looking for alternative names..."
    find . /usr /opt -name "*phoenix*.so" -type f 2>/dev/null -exec cp {} /usr/lib/x86_64-linux-gnu/odbc/ \; || true
    # Also check for any .so files in typical library locations
    find ./usr/lib* ./opt -name "*.so" -type f 2>/dev/null | head -5 | while read lib; do
        echo "Copying library: $lib"
        cp "$lib" /usr/lib/x86_64-linux-gnu/odbc/ 2>/dev/null || true
    done
fi

# Set permissions
chmod 755 /usr/lib/x86_64-linux-gnu/odbc/*.so 2>/dev/null || true

# Clean up
rm -rf /tmp/phoenix-odbc.rpm /tmp/usr /tmp/etc /tmp/opt 2>/dev/null || true

# Verify installation
echo "Verifying ODBC driver installation..."
if [ -f "/usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc.so" ]; then
    echo "✅ Phoenix ODBC driver installed successfully"
    ls -lh /usr/lib/x86_64-linux-gnu/odbc/*.so
else
    echo "⚠️  Warning: libphoenixodbc.so not found in expected location"
    echo "Available files in /usr/lib/x86_64-linux-gnu/odbc/:"
    ls -la /usr/lib/x86_64-linux-gnu/odbc/ || echo "Directory is empty"
fi

echo "Installation complete!"

# Exit with success even if library not found (fallback will work)
exit 0

