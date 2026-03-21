# Contributing Guidelines

Welcome to the Hipster Shop microservices project! This document provides guidelines for contributing code, documentation, and improvements to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Workflow](#development-workflow)
4. [Coding Standards](#coding-standards)
5. [Naming Conventions](#naming-conventions)
6. [Git Workflow](#git-workflow)
7. [Pull Request Process](#pull-request-process)
8. [Code Review Expectations](#code-review-expectations)
9. [Testing Requirements](#testing-requirements)
10. [Documentation Standards](#documentation-standards)

## Code of Conduct

We are committed to providing a welcoming and inclusive environment. All contributors must:
- Be respectful and professional
- Welcome feedback and criticism constructively
- Focus on code quality and project goals
- Respect intellectual property and licenses

## Getting Started

### Prerequisites
- Git installed and configured
- Docker and Docker Compose
- Language-specific tools:
  - Go 1.25+ 
  - Python 3.9+
  - Node.js 16+
  - Java 21+ (for ad-service)
  - .NET 7.0+ (for cart-service)

### Setup Development Environment

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/microservices-demo.git
   cd microservices-demo
   git remote add upstream https://github.com/GoogleCloudPlatform/microservices-demo.git
   ```

2. **Create feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Install dependencies** (see [DEV_GUIDE.md](DEV_GUIDE.md))

4. **Set up pre-commit hooks** (recommended)
   ```bash
   # Install pre-commit framework
   pip install pre-commit
   
   # Set up hooks (create .pre-commit-config.yaml)
   pre-commit install
   ```

## Development Workflow

### 1. Identify Your Assignment

- Pick an issue from the GitHub Issues board
- Check existing pull requests to avoid duplication
- Comment on the issue to claim it
- Discuss approach before major implementation

### 2. Create Feature Branch

```bash
git checkout -b feature/issue-123-brief-description

# Branch naming conventions:
# feature/  - New features
# bugfix/   - Bug fixes
# docs/     - Documentation updates
# refactor/ - Code refactoring
# test/     - Test additions
```

### 3. Code Implementation

Follow the coding standards and guidelines below.

### 4. Local Testing

```bash
# Run tests for modified service
cd src/service-name
npm test        # Node.js
go test ./...   # Go
python -m pytest  # Python
dotnet test     # C#
mvn test        # Java
```

### 5. Commit Changes

See [Git Workflow](#git-workflow) section.

### 6. Push and Create Pull Request

```bash
git push origin feature/issue-123-brief-description
# Then create PR on GitHub
```

## Coding Standards

### General Principles

- **Readability**: Code should be self-documenting
- **Simplicity**: Prefer simple solutions over clever ones
- **DRY**: Don't Repeat Yourself - extract common patterns
- **SOLID**: Apply SOLID principles where applicable
- **Performance**: Measure before optimizing
- **Security**: Validate all inputs, never trust user data

### Language-Specific Standards

#### Go
```go
// Naming: CamelCase for exported, camelCase for unexported
package services

import (
    "fmt"
    "log"
    
    "github.com/sirupsen/logrus"
)

// Use interfaces for abstraction
type ProductService interface {
    GetProduct(ctx context.Context, id string) (*Product, error)
}

// Error handling: always check errors
func GetProduct(id string) (*Product, error) {
    if id == "" {
        return nil, errors.New("product id required")
    }
    // Implementation
}

// Logging: use logrus
log := logrus.WithField("product_id", id)
log.Info("Fetching product")

// gRPC: use proper context handling
func (s *Server) GetProduct(ctx context.Context, req *pb.GetProductRequest) (*pb.Product, error) {
    // Use context for cancellation/timeout
    return s.service.GetProduct(ctx, req.Id)
}
```

**Go Standards**:
- Follow [Effective Go](https://golang.org/doc/effective_go)
- Use `gofmt` for formatting
- Run `golint` and `go vet` before commit
- Keep functions focused and testable
- Use table-driven tests
- Handle errors explicitly

#### Python
```python
"""Module docstring explaining purpose."""

import logging
from typing import Optional, List
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class Product:
    """Product data model."""
    id: str
    name: str
    price: float
    
    def validate(self) -> bool:
        """Validate product data."""
        return bool(self.id and self.name and self.price > 0)

def get_product(product_id: str) -> Optional[Product]:
    """
    Fetch product by ID.
    
    Args:
        product_id: Unique product identifier
        
    Returns:
        Product instance or None if not found
        
    Raises:
        ValueError: If product_id is empty
    """
    if not product_id:
        raise ValueError("product_id must not be empty")
    
    logger.info(f"Fetching product: {product_id}")
    # Implementation
```

**Python Standards**:
- Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/)
- Use type hints for all functions
- Add docstrings (Google style)
- Use `black` for formatting
- Use `pylint` for linting
- Use `mypy` for type checking
- Keep functions under 50 lines

#### Node.js
```javascript
/**
 * Product service module.
 * @module services/productService
 */

const logger = require('./logger');

/**
 * Fetch product by ID.
 * @param {string} productId - Product identifier
 * @param {Object} options - Fetch options
 * @returns {Promise<Product>} Product data
 * @throws {Error} If product not found
 */
async function getProduct(productId, options = {}) {
    if (!productId) {
        throw new Error('productId is required');
    }
    
    logger.info({ productId }, 'Fetching product');
    
    try {
        const product = await database.query('SELECT * FROM products WHERE id = ?', [productId]);
        return product || null;
    } catch (error) {
        logger.error({ error, productId }, 'Failed to fetch product');
        throw error;
    }
}

module.exports = {
    getProduct
};
```

**Node.js Standards**:
- Follow [Google Node.js Style Guide](https://google.github.io/styleguide/tsconfig.json)
- Use async/await (not callbacks)
- Add JSDoc comments for public APIs
- Use ES6 modules
- Run `eslint` for linting
- Use `prettier` for formatting

#### C#
```csharp
using System;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace CartService.Services
{
    /// <summary>
    /// Service for managing shopping carts.
    /// </summary>
    public interface ICartService
    {
        /// <summary>
        /// Get user's shopping cart.
        /// </summary>
        Task<Cart> GetCartAsync(string userId);
    }

    /// <summary>
    /// Implementation of cart service.
    /// </summary>
    public class CartService : ICartService
    {
        private readonly ILogger<CartService> _logger;

        public CartService(ILogger<CartService> logger)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<Cart> GetCartAsync(string userId)
        {
            if (string.IsNullOrEmpty(userId))
            {
                throw new ArgumentException("User ID is required", nameof(userId));
            }

            _logger.LogInformation("Fetching cart for user: {UserId}", userId);
            
            try
            {
                // Implementation
                return new Cart { UserId = userId };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching cart for user: {UserId}", userId);
                throw;
            }
        }
    }
}
```

**C# Standards**:
- Follow [Microsoft C# Coding Conventions](https://docs.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions)
- Use PascalCase for class names and methods
- Use camelCase for parameters and local variables
- Use dependency injection
- Add XML documentation comments
- Use nullable reference types
- Run StyleCopAnalyzers

#### Java
```java
package com.example.ads;

import java.util.logging.Logger;

/**
 * Service for serving advertisements.
 */
public class AdService {
    private static final Logger LOGGER = Logger.getLogger(AdService.class.getName());
    
    /**
     * Get advertisements for given context.
     *
     * @param contextKeys the context for ad selection
     * @return list of relevant ads
     * @throws IllegalArgumentException if contextKeys is null
     */
    public List<Ad> getAds(List<String> contextKeys) {
        if (contextKeys == null) {
            throw new IllegalArgumentException("contextKeys cannot be null");
        }
        
        LOGGER.info("Fetching ads for context: " + contextKeys);
        
        try {
            // Implementation
            return Collections.emptyList();
        } catch (Exception e) {
            LOGGER.severe("Error fetching ads: " + e.getMessage());
            throw e;
        }
    }
}
```

**Java Standards**:
- Follow [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
- Use PascalCase for classes, camelCase for methods
- Add JavaDoc for public methods
- Use dependency injection
- Run Checkstyle for linting

### Cross-Language Standards

**Error Handling**:
- Never silently ignore errors
- Log errors with context (service name, request ID, user ID)
- Return meaningful error messages
- Use specific error types when possible

**Logging**:
- Use structured logging (key-value pairs)
- Log at appropriate levels:
  - DEBUG: Development troubleshooting
  - INFO: Important events (service start, requests)
  - WARN: Recoverable issues
  - ERROR: Unrecoverable failures
- Include context: user_id, request_id, trace_id
- Never log sensitive data (passwords, credit cards, PII)

**Comments**:
- Comment WHY, not WHAT
- Use // for single-line, /** */ for documentation
- Keep comments up-to-date with code

**Configuration**:
- Use environment variables, not hardcoded values
- Document all configuration options
- Provide sensible defaults
- Fail loudly on missing required config

## Naming Conventions

### Variables
```
userCart        (camelCase for local variables)
USER_ID_HEADER  (UPPER_CASE for constants)
product_id      (snake_case for proto fields)
```

### Functions
```
getProductById()          (Verb first, camelCase)
calculateShippingCost()   (Clear intent)
isValidEmail()            (Boolean predicates)
```

### Classes/Types
```
ProductService      (PascalCase, noun)
CartItem            (Descriptive, PascalCase)
PaymentRequest      (Clear purpose)
```

### Files/Modules
```
product_service.py     (lowercase_snake_case for Python)
product_service.go     (lowercase for Go packages)
ProductService.cs      (PascalCase for C#)
ProductService.java    (PascalCase for Java)
productService.js      (camelCase for JavaScript)
```

### Proto Files
```protobuf
// Package naming (lowercase, domain-based)
package hipstershop;

// Message naming (PascalCase)
message ProductCatalogRequest {}

// Service naming (PascalCase + Service suffix)
service ProductCatalogService {}

// RPC method naming (camelCase)
rpc listProducts(Empty) returns (ListProductsResponse) {}

// Field naming (snake_case)
string product_id = 1;
repeated string category_ids = 2;
```

## Git Workflow

### Commit Messages

**Format**:
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Examples**:
```
feat(product-catalog): implement full-text search

Add full-text search capability to product catalog service.
Search supports product names and descriptions.

Closes #123

---

fix(cart): resolve race condition in add-item

Use atomic operation to prevent duplicate items
when multiple requests arrive simultaneously.

Fixes #456

---

docs(readme): add deployment instructions

Added step-by-step guide for deploying to Kubernetes.
Includes troubleshooting section.

---

refactor(payment): extract card validation logic

Extract card validation into separate module for
reusability and testability.

BREAKING CHANGE: none

---

test(checkout): add integration tests

Added end-to-end integration tests for checkout flow
covering happy path and error scenarios.
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting (no logic changes)
- `refactor`: Code restructuring
- `perf`: Performance improvement
- `test`: Test additions/modifications
- `chore`: Build, CI, dependencies

**Scope**: Service or component affected (optional)

**Subject**:
- Imperative mood ("add" not "added")
- No period at end
- Under 50 characters

**Body**:
- Explain WHAT and WHY, not HOW
- Wrap at 72 characters
- Reference related issues

### Branch Strategy

**Main Branches**:
- `main`: Production-ready code
- `develop`: Integration branch (if used)

**Feature Branches**:
```bash
git checkout -b feature/issue-#-brief-description
```

**Pull from upstream**:
```bash
git fetch upstream
git rebase upstream/main
```

**Squash commits before merge** (if needed):
```bash
git rebase -i HEAD~3  # Squash last 3 commits
```

## Pull Request Process

### Before Submitting

1. **Update from upstream**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests locally**
   ```bash
   cd src/service-name
   # Run language-specific tests
   ```

3. **Run linters**
   ```bash
   # Go
   go fmt ./...
   go vet ./...
   
   # Python
   black .
   pylint *.py
   mypy .
   
   # Node.js
   prettier --write .
   eslint .
   
   # C#
   dotnet format
   ```

4. **Run security checks**
   ```bash
   # Scan for vulnerable dependencies
   # Check for hardcoded secrets
   # Validate service communication (TLS in prod)
   ```

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Breaking change
- [ ] Documentation update

## Related Issues
Closes #123

## Testing
- [ ] Tested locally
- [ ] Added unit tests
- [ ] Added integration tests
- [ ] Manual testing steps provided

## Checklist
- [ ] Code follows style guidelines
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests pass
- [ ] Dependencies verified

## Screenshots (if applicable)
[Add screenshots for UI changes]

## Additional Context
[Any additional information]
```

### PR Review Guidelines

**Reviewers look for**:
- Code quality and adherence to standards
- Test coverage (aim for >80%)
- Documentation completeness
- Security considerations
- Performance implications
- Backward compatibility
- Clear commit history

**Approval Criteria**:
- At least 2 approving reviews
- All CI checks passing
- No conflicts with main
- Security review (if sensitive)

## Code Review Expectations

### For Authors

- **Write clear**, well-documented code
- **Ask specific questions** about feedback
- **Respond promptly** to review comments
- **Request re-review** after addressing feedback
- **Be open** to suggestions
- **Explain** your reasoning when disagreeing

### For Reviewers

- **Review promptly** (within 24 hours ideally)
- **Be respectful and constructive**
- **Request changes** (don't demand)
- **Approve explicitly** with comment
- **Suggest improvements**, don't just criticize
- **Test locally** if possible
- **Check security implications**

### Common Review Comments

**Approve with suggestions**:
> Looks good! Minor suggestion: consider using a constant for the magic number 1000.

**Request changes**:
> This introduces a race condition. We need to add locking around the shared state.

**Question logic**:
> Can you explain why we're iterating twice here? There might be a more efficient approach.

## Testing Requirements

### Unit Tests

**Coverage Target**: >80% for modified code

**Example (Go)**:
```go
func TestGetProduct(t *testing.T) {
    tests := []struct {
        name    string
        id      string
        wantErr bool
    }{
        {"valid id", "prod-123", false},
        {"empty id", "", true},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            _, err := GetProduct(tt.id)
            if (err != nil) != tt.wantErr {
                t.Errorf("GetProduct() error = %v", err)
            }
        })
    }
}
```

### Integration Tests

Test service interactions
```go
func TestCheckoutFlow(t *testing.T) {
    // Setup services
    productSvc := setupProductService()
    paymentSvc := setupPaymentService()
    
    // Execute checkout
    order, err := checkout(productSvc, paymentSvc)
    
    // Verify
    assert.NoError(t, err)
    assert.NotNil(t, order)
}
```

### Load Testing

Use Locust for distributed load testing
```python
# In locustfile.py
class UserBehavior(HttpUser):
    @task
    def browse_products(self):
        self.client.get("/products")
```

## Documentation Standards

### Code Documentation

- **Classes/Functions**: Public API must have docs
- **Modules**: Add module-level documentation
- **Complex Logic**: Explain non-obvious code
- **Parameters**: Document all parameters and return values

### Project Documentation

**README.md**:
- Project overview
- Quick start guide
- Feature summary
- Contributing guidelines link

**ARCHITECTURE.md**:
- System design
- Component descriptions
- Data flows
- Deployment architecture

**SERVICE_README.md** (per service):
- Service purpose
- API documentation
- Build instructions
- Configuration options

### Comments vs Documentation

**Use comments for**:
- Why a decision was made
- Non-obvious algorithms
- Edge cases and gotchas
- Links to external references

**Use documentation for**:
- API usage
- Installation steps
- Architecture overview
- Configuration options

## Security Considerations

### Code Review Checklist

- [ ] Input validation on all endpoints
- [ ] No hardcoded credentials
- [ ] Sensitive data not logged
- [ ] SQL injection prevention (prepared statements)
- [ ] CORS headers appropriate
- [ ] TLS for sensitive data
- [ ] Secrets in env vars, not code
- [ ] Dependencies reviewed for known CVEs

### Reporting Security Issues

**Do NOT open public issues for security vulnerabilities**

Report to security team:
```
security@example.com

Include:
- Service affected
- Vulnerability type
- Steps to reproduce
- Potential impact
- Suggested fix
```

## Performance Guidelines

### Profiling

**Go**:
```go
import _ "net/http/pprof"

// Access profiles at http://localhost:6060/debug/pprof/
```

**Python**:
```python
import cProfile
cProfile.run('function_name()')
```

### Benchmarking

**Go**:
```go
func BenchmarkGetProduct(b *testing.B) {
    for i := 0; i < b.N; i++ {
        GetProduct("prod-123")
    }
}
```

**Python**:
```python
import timeit
timeit.timeit('get_product("prod-123")', number=1000)
```

## Troubleshooting Contributions

### Issue: CI Fails

1. Run tests locally: `cd src/service && npm test`
2. Check lint output: `eslint .`
3. Review CI logs on GitHub
4. Ask for help in PR comments

### Issue: Merge Conflicts

```bash
git fetch upstream
git rebase upstream/main
# Resolve conflicts
git add .
git rebase --continue
git push origin feature-branch -f
```

### Issue: Slow Code Review

- Ask questions in PR comments
- Mention @reviewers for priority
- Join development team chat/Slack
- Discuss in project meetings

## Contact & Questions

- Issues: GitHub Issues
- Discussions: GitHub Discussions
- Email: dev-team@example.com
- Slack: #microservices-demo channel

---

Thank you for contributing to Hipster Shop! Your improvements help make this project better for everyone.

**Last Updated**: March 2026
