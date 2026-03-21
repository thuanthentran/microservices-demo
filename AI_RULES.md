# AI Coding Rules

Guidelines and standards for AI coding assistants (including GitHub Copilot, Claude, and other AI tools) working on the Hipster Shop codebase.

## Core Principles

### 1. Code Quality First

- **Never prioritize speed over correctness**
- Generate complete, production-ready code
- Always include error handling
- Add meaningful logging statements
- Write testable, maintainable code

### 2. Architecture Alignment

- Respect the microservices architecture
- Follow existing service patterns
- Use established communication protocols (gRPC)
- Maintain service boundaries
- Don't create unnecessary coupling

### 3. Language Consistency

- Generate code in the service's primary language
- Follow language-specific idioms and conventions
- Use appropriate frameworks and libraries
- Respect existing dependency choices
- Avoid mixing paradigms unnecessarily

## Code Structure Expectations

### Organization

- **Single Responsibility Principle**: Each function/method has one clear purpose
- **Separation of Concerns**: Handlers, business logic, and data access layers
- **DRY (Don't Repeat Yourself)**: Extract common patterns into reusable functions
- **Interface-based Design**: Define contracts for testability

### Project Layout

```
src/service-name/
├── main.go                 # Entry point
├── handlers.go             # Request handlers
├── services/
│   └── business_logic.go   # Core business logic
├── models/
│   └── data_models.go      # Data structures
├── proto/
│   └── demo.proto          # Service definition
└── tests/
    └── service_test.go     # Unit tests
```

### Naming Conventions

Follow language-specific conventions:

**Go**: `CamelCase` (exported), `camelCase` (unexported)
- `func GetProduct(id string)`
- `type ProductService struct`
- Use short variable names in small scopes

**Python**: `snake_case` for functions, `PascalCase` for classes
- `def get_product(product_id):`
- `class ProductService:`
- Use descriptive variable names

**JavaScript**: `camelCase` for functions/variables, `PascalCase` for classes
- `function getProduct(id)`
- `class ProductService`
- Use `const` by default, `let` for loop variables

**C#**: `PascalCase` for public members, `camelCase` for private
- `public Product GetProduct(string id)`
- `private void ValidateInput()`

**Java**: `camelCase` for methods/variables, `PascalCase` for classes
- `public Product getProduct(String id)`
- `public class ProductService`

## Patterns to Follow

### 1. Error Handling

**Go**:
```go
func (s *Service) GetProduct(ctx context.Context, id string) (*Product, error) {
    if id == "" {
        return nil, errors.New("product id required")
    }
    
    product, err := s.db.GetProduct(id)
    if err != nil {
        return nil, errors.Wrap(err, "failed to fetch product")
    }
    
    return product, nil
}
```

**Python**:
```python
def get_product(product_id: str) -> Optional[Product]:
    if not product_id:
        raise ValueError("product_id cannot be empty")
    
    try:
        product = database.query_product(product_id)
        return product
    except DatabaseError as e:
        logger.error(f"Database error: {e}", exc_info=True)
        raise
```

**Node.js**:
```javascript
async function getProduct(productId) {
    if (!productId) {
        throw new Error('Product ID is required');
    }
    
    try {
        const product = await database.getProduct(productId);
        return product;
    } catch (error) {
        logger.error({ error, productId }, 'Failed to fetch product');
        throw error;
    }
}
```

### 2. Logging

**Always include**:
- What operation is being performed
- Context (user ID, request ID, resource ID)
- Error details with stack traces
- Performance metrics for slow operations

**Go**:
```go
log := log.WithFields(logrus.Fields{
    "product_id": id,
    "request_id": ctx.Value("request_id"),
})

log.Info("Fetching product from database")

if err != nil {
    log.WithError(err).Error("Failed to fetch product")
    return nil, err
}

log.Debug("Product fetched successfully")
```

**Python**:
```python
import logging

logger = logging.getLogger(__name__)

def get_product(product_id: str):
    logger.info(f"Fetching product {product_id}")
    
    try:
        product = fetch_product(product_id)
        logger.debug(f"Found product: {product.name}")
        return product
    except Exception as e:
        logger.error(f"Error fetching product: {e}", exc_info=True)
        raise
```

### 3. Input Validation

**Always validate**:
- Empty/null values
- Type correctness
- Range constraints
- Format validity

**Go**:
```go
func (s *Service) ProcessOrder(ctx context.Context, req *OrderRequest) error {
    // Validate user ID
    if req.UserId == "" {
        return errors.New("user_id is required")
    }
    
    // Validate items
    if len(req.Items) == 0 {
        return errors.New("order must contain at least one item")
    }
    
    // Validate item quantities
    for _, item := range req.Items {
        if item.Quantity <= 0 {
            return errors.New("item quantity must be positive")
        }
    }
    
    // Proceed with processing
    return s.process(ctx, req)
}
```

**Python**:
```python
def process_order(user_id: str, items: List[Dict]) -> Order:
    # Validate inputs
    if not user_id:
        raise ValueError("user_id is required")
    
    if not items:
        raise ValueError("items list cannot be empty")
    
    # Validate items
    for item in items:
        if item.get('quantity', 0) <= 0:
            raise ValueError("item quantity must be positive")
        if not item.get('product_id'):
            raise ValueError("product_id is required for each item")
    
    # Process order
    return _process_order(user_id, items)
```

### 4. Interface Design

Create interfaces for dependencies to enable testing:

**Go**:
```go
// Define interface
type ProductRepository interface {
    GetProduct(ctx context.Context, id string) (*Product, error)
}

// Service depends on interface
type ProductService struct {
    repo ProductRepository
}

// Easy to mock in tests
type MockRepository struct {
    GetProductFunc func(ctx context.Context, id string) (*Product, error)
}

func (m *MockRepository) GetProduct(ctx context.Context, id string) (*Product, error) {
    return m.GetProductFunc(ctx, id)
}
```

**Python**:
```python
from abc import ABC, abstractmethod
from typing import Optional

class ProductRepository(ABC):
    @abstractmethod
    def get_product(self, product_id: str) -> Optional[Product]:
        pass

class ProductService:
    def __init__(self, repository: ProductRepository):
        self._repository = repository
    
    def get_product(self, product_id: str) -> Optional[Product]:
        return self._repository.get_product(product_id)

# For testing
class MockRepository(ProductRepository):
    def get_product(self, product_id: str) -> Optional[Product]:
        return Product(id=product_id, name="Test")
```

### 5. gRPC Implementation

**Service Definition**:
```protobuf
service ProductCatalogService {
    rpc GetProduct(GetProductRequest) returns (Product) {}
    rpc ListProducts(Empty) returns (ListProductsResponse) {}
    rpc SearchProducts(SearchProductsRequest) returns (SearchProductsResponse) {}
}

message Product {
    string id = 1;
    string name = 2;
    string description = 3;
    Money price_usd = 4;
    repeated string categories = 5;
}
```

**Go Implementation**:
```go
type server struct {
    pb.UnimplementedProductCatalogServiceServer
    service ProductService
}

func (s *server) GetProduct(ctx context.Context, req *pb.GetProductRequest) (*pb.Product, error) {
    if req.Id == "" {
        return nil, status.Error(codes.InvalidArgument, "product id required")
    }
    
    product, err := s.service.GetProduct(ctx, req.Id)
    if err != nil {
        return nil, status.Error(codes.Internal, "failed to get product")
    }
    
    return toProto(product), nil
}
```

## Anti-Patterns to Avoid

### ❌ Don't:

1. **Hardcode configuration**
   ```go
   // BAD
   const PAYMENT_SERVICE = "192.168.1.100:50051"
   
   // GOOD
   paymentService := os.Getenv("PAYMENT_SERVICE_ADDR")
   ```

2. **Create circular dependencies**
   ```go
   // BAD: ServiceA imports ServiceB, ServiceB imports ServiceA
   
   // GOOD: Use pub/sub or message queue for decoupling
   ```

3. **Mix concerns in handlers**
   ```go
   // BAD: Business logic mixed with HTTP
   func (h *Handler) HandleOrder(w http.ResponseWriter, r *http.Request) {
       // Parse input
       // Validate order
       // Calculate taxes
       // Call payment service
       // Update database
       // Send email
       // Return response
   }
   
   // GOOD: Separate layers
   // handler -> service -> repository
   ```

4. **Ignore context cancellation**
   ```go
   // BAD
   database.Query("SELECT * FROM products")
   
   // GOOD: Respect context deadlines
   ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
   defer cancel()
   database.QueryContext(ctx, "SELECT * FROM products")
   ```

5. **Log sensitive data**
   ```go
   // BAD
   log.Printf("Processing payment: %+v", creditCard)
   
   // GOOD
   log.Printf("Processing payment for user: %s", userID)
   ```

6. **Skip tests**
   ```go
   // BAD: No tests at all
   
   // GOOD: Test critical paths
   func TestGetProduct_ValidID(t *testing.T) { ... }
   func TestGetProduct_EmptyID(t *testing.T) { ... }
   func TestGetProduct_NotFound(t *testing.T) { ... }
   ```

7. **Catch and ignore errors**
   ```go
   // BAD
   _, _ = database.Query("...")
   
   // GOOD
   rows, err := database.Query("...")
   if err != nil {
       return fmt.Errorf("query failed: %w", err)
   }
   ```

8. **Create tight coupling to external services**
   ```go
   // BAD: Direct dependency on concrete implementation
   service := NewPaymentService()
   
   // GOOD: Inject interface
   service := NewCheckoutService(paymentService PaymentService)
   ```

## Code Quality Standards

### Complexity Limits

| Metric | Limit | Notes |
|--------|-------|-------|
| Cyclomatic complexity | < 10 | Break down complex functions |
| Function length | < 50 lines | Refactor if larger |
| Method/function params | < 5 | Use structs for many params |
| Nesting depth | < 4 | Early returns reduce nesting |
| File size | < 500 lines | Split large files by concern |

### Test Coverage

- **Business logic**: > 85%
- **API handlers**: > 80%
- **Infrastructure**: > 60%
- **Critical paths**: 100%

Example test structure:

```go
// Table-driven tests (Go)
func TestGetProduct(t *testing.T) {
    tests := []struct {
        name      string
        productID string
        expectErr bool
        expected  *Product
    }{
        {"valid product", "prod-123", false, &Product{ID: "prod-123"}},
        {"not found", "invalid", true, nil},
        {"empty id", "", true, nil},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            product, err := service.GetProduct(tt.productID)
            
            if (err != nil) != tt.expectErr {
                t.Errorf("got error=%v, want=%v", err != nil, tt.expectErr)
            }
            
            if !reflect.DeepEqual(product, tt.expected) {
                t.Errorf("got %v, want %v", product, tt.expected)
            }
        })
    }
}
```

## Documentation Standards

### Code Comments

**What to comment**:
- **Why** decisions were made
- **What** non-obvious logic does
- **Links** to external documentation
- **Edge cases** and gotchas

**What NOT to comment**:
- Obvious code: `x = 5; // assign 5 to x` ❌
- Code that duplicates function name
- TODO comments without assignee

**Good comment example**:
```go
// Apply exponential backoff to handle temporary service failures.
// Maximum 3 retries with jitter to prevent thundering herd.
// See: https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
func getProductWithRetry(id string) (*Product, error) {
    var product *Product
    var lastErr error
    
    for attempt := 1; attempt <= 3; attempt++ {
        product, err := getProduct(id)
        if err == nil {
            return product, nil
        }
        
        lastErr = err
        
        // Exponential backoff with jitter
        waitTime := time.Duration(math.Pow(2, float64(attempt))) * time.Second
        jitter := time.Duration(rand.Int63n(int64(time.Second)))
        time.Sleep(waitTime + jitter)
    }
    
    return nil, lastErr
}
```

### Function Documentation

Every public function should have a docstring:

**Go**:
```go
// GetProduct retrieves a product by ID from the catalog.
//
// Returns ErrNotFound if the product doesn't exist.
// Returns ErrInvalidID if the ID is empty.
func (s *Service) GetProduct(ctx context.Context, id string) (*Product, error) {
    // ...
}
```

**Python**:
```python
def get_product(product_id: str) -> Optional[Product]:
    """
    Retrieve a product from the catalog.
    
    Args:
        product_id: Unique product identifier
        
    Returns:
        Product object if found, None otherwise
        
    Raises:
        ValueError: If product_id is empty
        DatabaseError: If database query fails
    """
```

**JavaScript**:
```javascript
/**
 * Retrieve a product by ID.
 * 
 * @param {string} productId - The product identifier
 * @returns {Promise<Product>} The product object
 * @throws {Error} If product not found
 */
async function getProduct(productId) {
    // ...
}
```

## Specific Service Rules

### Frontend Service (Go)

- Use `context.Context` for all requests
- Validate path parameters and query strings
- Return appropriate HTTP status codes
- Implement CSRF protection for state-changing operations
- Use templates for HTML rendering (not string concatenation)

### Cart Service (C#)

- Use async/await for all I/O operations
- Implement proper IDisposable pattern
- Use dependency injection for all services
- Add XML documentation for public APIs
- Use entity framework or similar ORM

### Payment Service (Node.js)

- NEVER log credit card data or sensitive payment info
- Validate card format before processing
- Implement idempotency with request IDs
- Use proper error codes for payment failures
- Implement rate limiting for payment attempts

### Email Service (Python)

- Use structured logging for email dispatch
- Template all emails (don't inline HTML)
- Implement retry logic with exponential backoff
- Track delivery status
- Don't block on email sending

### Database Layers

- Use parameterized queries (prevent SQL injection)
- Implement connection pooling
- Add query timeouts
- Log slow queries
- Use transactions for multi-step operations

## Performance Guidelines

### Optimization Rules

1. **Profile before optimizing**: Always measure bottlenecks
2. **Prefer correctness**: Don't sacrifice correctness for marginal gains
3. **Use caching wisely**: Cache expensive operations, verify cache coherency
4. **Batch operations**: Reduce round-trips (N+1 problem)
5. **Implement pagination**: Never return all records

### Example: Avoiding N+1 Problem

```go
// BAD: N+1 queries
products, err := catalog.GetProducts()
for _, product := range products {
    reviews, err := catalog.GetReviews(product.ID)  // Query per product
    // ...
}

// GOOD: Fetch related data upfront or use joins
products, err := catalog.GetProductsWithReviews()
```

## Security Guidelines

### Input Validation

```go
// Always validate untrusted input
func handleCreateProduct(w http.ResponseWriter, r *http.Request) {
    var req CreateProductRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }
    
    // Validate fields
    if req.Name == "" || len(req.Name) > 255 {
        http.Error(w, "invalid product name", http.StatusBadRequest)
        return
    }
    
    if req.Price < 0 {
        http.Error(w, "price must be non-negative", http.StatusBadRequest)
        return
    }
    
    // Process valid request
}
```

### Secrets Management

```go
// BAD
const PAYMENT_KEY = "sk_test_123456789"

// GOOD
paymentKey := os.Getenv("PAYMENT_API_KEY")
if paymentKey == "" {
    log.Fatal("PAYMENT_API_KEY environment variable not set")
}
```

### TLS/HTTPS

```go
// BAD: Insecure connection
conn, _ := grpc.Dial("payment-service:50051")

// GOOD: Using TLS (in production)
creds, _ := credentials.NewClientTLSFromFile("cert.pem", "")
conn, _ := grpc.Dial("payment-service:50051", grpc.WithTransportCredentials(creds))
```

## When to Alert an Engineer

AI should escalate to human engineers for:

1. **Architectural decisions**: New service design, major refactoring
2. **Security concerns**: Auth, encryption, secret handling
3. **Performance-critical code**: Optimization beyond standard practices
4. **Breaking changes**: API modifications, proto changes
5. **Complex business logic**: Multi-service orchestration
6. **DevOps/Infrastructure**: Kubernetes, Terraform, deployment

## Summary

**Key Takeaways**:

✓ Write production-ready code  
✓ Follow language conventions  
✓ Handle errors properly  
✓ Validate all inputs  
✓ Log meaningfully  
✓ Test critical paths  
✓ Document functions  
✓ Respect architecture  
✓ Never log secrets  
✓ Ask for help on complex decisions  

---

**Last Updated**: March 2026  
**For questions**: See [CONTRIBUTING.md](CONTRIBUTING.md)
