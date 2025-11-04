# Contributing to PhoenixDotNet

Thank you for your interest in contributing to PhoenixDotNet! This guide will help you get started.

## Getting Started

1. **Read the Documentation**
   - Start with `Documentation/DEVELOPMENT_HANDBOOK.md`
   - Review `Documentation/ONBOARDING_CHECKLIST.md`
   - Familiarize yourself with `Documentation/CODE_STYLE_GUIDELINES.md`

2. **Set Up Your Environment**
   - Follow the setup instructions in `Documentation/QUICKSTART.md`
   - Complete the onboarding checklist

3. **Understand the Codebase**
   - Review existing code patterns
   - Understand the architecture
   - Review test scripts

## Development Workflow

### 1. Create a Branch

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Or create a bugfix branch
git checkout -b fix/your-bugfix-name
```

### 2. Make Your Changes

- Follow code style guidelines
- Write XML documentation for public APIs
- Add error handling
- Add logging where appropriate
- Write tests for your changes

### 3. Test Your Changes

```bash
# Run all tests
cd tests && ./run_all_tests.sh

# Test your specific changes
# Use Swagger UI: http://localhost:8099/swagger
# Use SQL GUI: http://localhost:8100
# Use curl commands
```

### 4. Commit Your Changes

Follow the commit message format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Examples:**
```
feat(api): Add version endpoint

Add GET /api/phoenix/version endpoint to return application version.

Fixes #123
```

```
fix(client): Handle null response in ExecuteQueryAsync

Add null check for Avatica response to prevent NullReferenceException.

Closes #456
```

### 5. Create a Pull Request

- Write a clear description of your changes
- Reference related issues
- Include screenshots if applicable
- Request review from team members

## Code Style

- Follow `Documentation/CODE_STYLE_GUIDELINES.md`
- Use XML documentation comments for all public APIs
- Follow existing code patterns
- Keep code simple and readable

## Testing Requirements

- Write tests for new features
- Ensure all existing tests pass
- Test error scenarios
- Test edge cases

## Documentation Requirements

- Update relevant documentation for new features
- Add XML documentation for new public APIs
- Update examples if needed
- Update README if applicable

## Review Process

1. Code is reviewed by at least one team member
2. All tests must pass
3. Code must follow style guidelines
4. Documentation must be updated
5. No compiler warnings
6. No security issues

## Types of Contributions

### Bug Fixes

- Fix bugs in existing functionality
- Add tests to prevent regression
- Update documentation if needed

### New Features

- Add new API endpoints
- Add new client methods
- Add new functionality
- Include comprehensive tests
- Update documentation

### Documentation

- Fix typos
- Improve clarity
- Add missing information
- Update examples

### Code Improvements

- Refactor code for clarity
- Improve error handling
- Optimize performance
- Improve code structure

## Questions?

If you have questions:

- Check the documentation first
- Review existing code for patterns
- Ask in team communication channels
- Create an issue for discussion

## Thank You!

Your contributions help make PhoenixDotNet better for everyone. We appreciate your time and effort!

