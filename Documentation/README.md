# PhoenixDotNet Documentation Index

Welcome to the PhoenixDotNet documentation. This directory contains comprehensive guides and reference materials for using the Phoenix .NET REST API application.

## Getting Started

**New to PhoenixDotNet?** Start here:

- **[DEVELOPMENT_HANDBOOK.md](./DEVELOPMENT_HANDBOOK.md)** - **START HERE**: Comprehensive handoff guide for development teams with component descriptions, architecture diagrams, and project structure glossary
- **[QUICKSTART.md](./QUICKSTART.md)** - Quick start guide with deployment options and basic examples
- **[README_REST_API.md](./README_REST_API.md)** - Complete REST API reference with endpoint documentation and examples

## Core Documentation

### Setup and Deployment

- **[DOCKER.md](./DOCKER.md)** - Docker deployment guide
  - Container setup and configuration
  - Docker Compose usage
  - Container networking and troubleshooting
- **[SETUP.md](./SETUP.md)** - Docker build setup and ODBC configuration
  - ODBC configuration files setup
  - Docker build requirements
  - Configuration customization
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Production deployment guide
  - Version pinning recommendations
  - Environment-specific configurations
  - Security considerations
  - Scaling and monitoring

- **[QUICKSTART.md](./QUICKSTART.md)** - Quick start guide
  - Prerequisites checklist
  - Container deployment (recommended)
  - Local development setup
  - Basic usage examples

### API Reference

- **[README_REST_API.md](./README_REST_API.md)** - REST API documentation
  - Complete API endpoint reference
  - Request/response examples
  - Authentication and error handling
  - API usage patterns and best practices

### Features and Operations

- **[README_TABLES.md](./README_TABLES.md)** - Table operations guide
  - Creating and managing tables
  - Table schema and metadata
  - Data operations (INSERT, UPDATE, DELETE)
  - Table best practices

- **[README_VIEWS.md](./README_VIEWS.md)** - Phoenix views documentation
  - Creating and using views
  - View examples (active_users_view, user_summary_view)
  - Querying views with filters
  - View best practices

- **[HBASE_VS_PHOENIX_TABLES.md](./HBASE_VS_PHOENIX_TABLES.md)** - **Technical Deep Dive**: Native HBase vs Phoenix tables
  - Comprehensive comparison of table types
  - Binary encoding mechanisms explained
  - Storage format details
  - Limitations and constraints
  - When to use which approach
  - Phoenix views on HBase tables
  - Troubleshooting guide

### HBase Integration

- **[HBASE_API_TEST.md](./HBASE_API_TEST.md)** - HBase API testing guide
  - HBase REST API integration
  - Testing HBase endpoints
  - Table creation via HBase API
  - Schema and metadata operations

### Troubleshooting and Setup

- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Comprehensive troubleshooting guide
  - Common issues and solutions
  - Connection problems
  - Protocol errors (JSON/Protobuf)
  - Initialization issues
  - Debugging tips and verification steps

- **[PHOENIX_ODBC_SETUP.md](./PHOENIX_ODBC_SETUP.md)** - Phoenix ODBC driver setup guide
  - ODBC driver installation
  - Configuration files (odbcinst.ini, odbc.ini)
  - Connection string formats
  - Platform-specific instructions (Linux, macOS, Windows)

- **[ODBC_IMPLEMENTATION.md](./ODBC_IMPLEMENTATION.md)** - ODBC implementation details
  - How ODBC is used in the application
  - ODBC as primary connection method with REST API fallback
  - Configuration and testing
  - Troubleshooting ODBC connections

### Testing and Examples

- **[TESTING_GUIDE.md](./TESTING_GUIDE.md)** - Comprehensive testing guide
  - Test scripts glossary
  - Running tests
  - Understanding test results
  - Troubleshooting test failures

### Development Teams

- **[DEVELOPMENT_HANDBOOK.md](./DEVELOPMENT_HANDBOOK.md)** - Complete handoff guide
  - Component descriptions
  - Architecture diagrams
  - Project structure glossary
  - Development workflow
  - Configuration guide
  - API reference
  - Testing guide
  - Troubleshooting
  - Examples and use cases

- **[ONBOARDING_CHECKLIST.md](./ONBOARDING_CHECKLIST.md)** - Step-by-step onboarding guide for new developers
  - Pre-flight checklist
  - Day 1 tasks
  - Week 1 deep dive
  - Success criteria

- **[CODE_STYLE_GUIDELINES.md](./CODE_STYLE_GUIDELINES.md)** - Coding standards and best practices
  - Naming conventions
  - Code formatting
  - XML documentation standards
  - Error handling patterns
  - Testing standards

- **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)** - Cheat sheet for common operations
  - Quick start commands
  - API endpoints reference
  - Docker commands
  - Common SQL queries
  - Troubleshooting commands

- **[COMMON_TASKS.md](./COMMON_TASKS.md)** - Step-by-step guides for common tasks
  - Adding API endpoints
  - Adding client methods
  - Modifying configuration
  - Adding logging
  - Handling errors

- **[CONTRIBUTING.md](./CONTRIBUTING.md)** - Contribution guidelines
  - Development workflow
  - Code review process
  - Testing requirements
  - Documentation requirements


## Documentation by Use Case

### I want to...

**Get started quickly:**
1. Read [QUICKSTART.md](./QUICKSTART.md)
2. Deploy with Docker: [DOCKER.md](./DOCKER.md)

**Use the REST API:**
1. API Reference: [README_REST_API.md](./README_REST_API.md)
2. Examples and patterns included

**Work with tables:**
1. Table operations: [README_TABLES.md](./README_TABLES.md)
2. Views: [README_VIEWS.md](./README_VIEWS.md)
3. **Technical deep dive**: [HBASE_VS_PHOENIX_TABLES.md](./HBASE_VS_PHOENIX_TABLES.md) - Native HBase vs Phoenix tables, encoding, and limitations

**Integrate with HBase:**
1. HBase API guide: [HBASE_API_TEST.md](./HBASE_API_TEST.md)

**Fix problems:**
1. Troubleshooting: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
2. Setup guide: [SETUP.md](./SETUP.md)
3. ODBC setup: [PHOENIX_ODBC_SETUP.md](./PHOENIX_ODBC_SETUP.md)
4. ODBC implementation: [ODBC_IMPLEMENTATION.md](./ODBC_IMPLEMENTATION.md)

**Deploy to production:**
1. Setup guide: [SETUP.md](./SETUP.md)
2. Deployment guide: [DEPLOYMENT.md](./DEPLOYMENT.md)
3. Security guide: [SECURITY.md](./SECURITY.md)
4. Docker guide: [DOCKER.md](./DOCKER.md)

## Quick Links

- **Main README**: [../README.md](../README.md) - Project overview and main documentation
- **API Endpoints**: See [README_REST_API.md](./README_REST_API.md) for complete endpoint list
- **SQL Search GUI**: Access at http://localhost:8100 (when running)
- **REST API**: Access at http://localhost:8099/api/phoenix/* (when running)

## Documentation Structure

```
Documentation/
├── README.md                      # This index file
├── DEVELOPMENT_HANDBOOK.md        # Complete handoff guide for development teams
├── QUICKSTART.md                  # Quick start guide
├── DOCKER.md                      # Docker deployment
├── README_REST_API.md             # REST API reference
├── README_TABLES.md               # Table operations
├── README_VIEWS.md                # Phoenix views
├── HBASE_VS_PHOENIX_TABLES.md     # Technical deep dive: Native HBase vs Phoenix tables
├── HBASE_API_TEST.md              # HBase API testing
├── TROUBLESHOOTING.md             # Troubleshooting guide
├── PHOENIX_ODBC_SETUP.md          # ODBC driver setup
├── ODBC_IMPLEMENTATION.md         # ODBC implementation details
├── TESTING_GUIDE.md               # Comprehensive testing guide
├── ONBOARDING_CHECKLIST.md        # Onboarding checklist for new developers
├── CODE_STYLE_GUIDELINES.md       # Coding standards and best practices
├── QUICK_REFERENCE.md             # Quick reference cheat sheet
├── COMMON_TASKS.md                # Common tasks step-by-step guide
├── CONTRIBUTING.md                # Contribution guidelines
├── FINAL_WORKING_EXAMPLE.md       # Complete working example (HBase + Phoenix views)
├── HBASE_API_GUIDE.md             # HBase API integration guide
├── HBASE_REST_SETUP.md            # HBase REST API setup guide
├── QUERY_EXAMPLES.md              # Query examples and patterns
├── ODBC_INSTALLATION.md           # ODBC driver installation guide
├── ODBC_STATUS.md                 # ODBC status and verification
├── SETUP.md                       # Docker build setup and ODBC configuration
├── DEPLOYMENT.md                  # Production deployment guide
└── SECURITY.md                    # Security policy and best practices
```

## Contributing

Found an issue or want to improve the documentation? 

- Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues
- Submit issues or pull requests to improve documentation

---

**Note**: This documentation is for PhoenixDotNet - a .NET REST API application for Apache Phoenix. For Apache Phoenix itself, see the [official Phoenix documentation](https://phoenix.apache.org/).
