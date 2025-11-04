# Build stage - Use x86_64 platform for ODBC driver compatibility
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file and restore dependencies
COPY ["PhoenixDotNet.csproj", "./"]
RUN dotnet restore "PhoenixDotNet.csproj"

# Copy everything else and build
COPY . .
RUN dotnet build "PhoenixDotNet.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "PhoenixDotNet.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage - Use x86_64 platform for ODBC driver compatibility
FROM --platform=linux/amd64 mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Install unixODBC and unixODBC-dev for ODBC support
# Also install rpm2cpio and cpio to extract RPM files
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    unixodbc \
    unixodbc-dev \
    rpm2cpio \
    cpio \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create directory for ODBC drivers
RUN mkdir -p /usr/lib/x86_64-linux-gnu/odbc

# Create directory for ODBC configuration
RUN mkdir -p /etc

# Install Phoenix ODBC driver from RPM file
# Extract the Hortonworks Phoenix ODBC driver RPM
COPY ODBC/1.0.8.1011/Linux/HortonworksPhoenix-64bit-1.0.8.1011-1.rpm /tmp/phoenix-odbc.rpm
COPY install_odbc.sh /tmp/install_odbc.sh
RUN chmod +x /tmp/install_odbc.sh && \
    /tmp/install_odbc.sh && \
    rm -f /tmp/install_odbc.sh

# Copy ODBC configuration files
# The Dockerfile expects odbcinst.ini in the project root
# Users should copy odbcinst.ini.example to odbcinst.ini before building:
#   cp odbcinst.ini.example odbcinst.ini
COPY odbcinst.ini /etc/odbcinst.ini

# Set LD_LIBRARY_PATH to include ODBC driver directory
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/odbc:${LD_LIBRARY_PATH}

# Copy published application
COPY --from=publish /app/publish .

# Copy appsettings.json if it exists (or use environment variables)
COPY appsettings.json .

# Set entry point
ENTRYPOINT ["dotnet", "PhoenixDotNet.dll"]
