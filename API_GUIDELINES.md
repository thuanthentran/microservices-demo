# API Guidelines

Design standards and best practices for gRPC and REST APIs in the Hipster Shop microservices.

## Table of Contents

1. [gRPC API Design](#grpc-api-design)
2. [Protocol Buffers](#protocol-buffers)
3. [Service Design](#service-design)
4. [Error Handling](#error-handling)
5. [Naming Conventions](#naming-conventions)
6. [Versioning](#versioning)
7. [Documentation](#documentation)
8. [REST API (if applicable)](#rest-api-if-applicable)

## gRPC API Design

### Core Principles

- **Simplicity**: APIs should be simple and intuitive
- **Consistency**: Similar operations use similar patterns
- **Idempotency**: Operations should be safe to retry
- **Backward Compatibility**: Never break existing clients
- **Clear Contracts**: Use Protocol Buffers as the single source of truth

### Service Structure

```protobuf
syntax = "proto3";

package hipstershop;

// Descriptive service names with "Service" suffix
service ProductCatalogService {
    // List operations
    rpc ListProducts(Empty) returns (ListProductsResponse) {}
    
    // Get single item
    rpc GetProduct(GetProductRequest) returns (Product) {}
    
    // Create operations
    rpc CreateProduct(CreateProductRequest) returns (Product) {}
    
    // Update operations
    rpc UpdateProduct(UpdateProductRequest) returns (Product) {}
    
    // Delete operations
    rpc DeleteProduct(DeleteProductRequest) returns (Empty) {}
    
    // Search/filter operations
    rpc SearchProducts(SearchProductsRequest) returns (SearchProductsResponse) {}
}
```

### RPC Naming Conventions

| Operation | Pattern | Example |
|-----------|---------|---------|
| **Retrieve single resource** | `Get<Resource>` | `GetProduct` |
| **List/search multiple** | `List<Resource>s` or `Search<Resource>s` | `ListProducts`, `SearchProducts` |
| **Create** | `Create<Resource>` | `CreateOrder` |
| **Update** | `Update<Resource>` | `UpdateCart` |
| **Delete** | `Delete<Resource>` | `DeleteOrder` |
| **Execute action** | `<Action><Resource>` | `ChargePayment`, `ShipOrder` |
| **Check status** | `<CheckVerifyValidate><What>` | `IsAvailable`, `ValidateAddress` |

### Request/Response Pattern

**Standard Pattern**:
```protobuf
// Request message (always suffixed with "Request")
message GetProductRequest {
    string product_id = 1;
}

// Response message (use resource type or "Response" suffix)
message Product {
    string id = 1;
    string name = 2;
    string description = 3;
    Money price = 4;
}

// For list operations
message ListProductsResponse {
    repeated Product products = 1;
    string next_page_token = 2;  // For pagination
}
```

**Pagination Pattern**:
```protobuf
// For large result sets, use page tokens
message ListProductsRequest {
    int32 page_size = 1;        // Max items to return
    string page_token = 2;      // Token from previous response
}

message ListProductsResponse {
    repeated Product products = 1;
    string next_page_token = 2;  // Empty if last page
}
```

**Filtering/Searching**:
```protobuf
message SearchProductsRequest {
    string query = 1;              // Search term
    int32 max_results = 2;         // Limit results
    repeated string categories = 3; // Filter by category
}

message SearchProductsResponse {
    repeated Product results = 1;
    int32 total_count = 2;         // Total matches available
}
```

## Protocol Buffers

### Message Design

**Field Numbering**:
```protobuf
message Product {
    string id = 1;              // Required fields first
    string name = 2;
    
    string description = 3;     // Optional fields
    string image_url = 4;
    
    // Repeated fields
    repeated string categories = 5;
    repeated Review reviews = 6;
    
    // Nested messages for complex data
    Money price = 7;
    
    // Don't use field 10-19 for future growth
    // Leave for internal fields or future use
}
```

**Field Naming**:
- Use `snake_case` for all field names
- Use `singular` for single values: `product_id`
- Use `repeated` for arrays: `repeated string tags`
- Use `_id` suffix for identifiers: `user_id`, `product_id`
- Use `_count` suffix for counters: `item_count`
- Use `_at` suffix for timestamps: `created_at`, `updated_at`

**Required vs Optional**:
```protobuf
// Proto3: All fields are technically optional
// But document intent via comments

message Order {
    string order_id = 1;              // Required: unique identifier
    string user_id = 2;               // Required: who owns this
    
    string description = 3;           // Optional: additional info
    repeated OrderItem items = 4;     // Optional: may be empty initially
    
    int64 created_at_ms = 5;         // Required: timestamp
    int64 updated_at_ms = 6;         // Required: timestamp
}
```

**Money Representation**:
```protobuf
// Use standard Money message for currency operations
message Money {
    string currency_code = 1;  // ISO 4217 code: "USD", "EUR", etc.
    int64 units = 2;            // Whole units
    int32 nanos = 3;            // Sub-units (nanoseconds precision)
}

// Example: $19.99
// units: 19
// nanos: 990000000
```

**Timestamps**:
```protobuf
// Use well-known types for common patterns
syntax = "proto3";

import "google/protobuf/timestamp.proto";

message Order {
    string order_id = 1;
    google.protobuf.Timestamp created_at = 2;
    google.protobuf.Timestamp updated_at = 3;
}
```

**Enums**:
```protobuf
enum OrderStatus {
    ORDER_STATUS_UNSPECIFIED = 0;  // Always include UNSPECIFIED
    ORDER_STATUS_PENDING = 1;
    ORDER_STATUS_CONFIRMED = 2;
    ORDER_STATUS_SHIPPED = 3;
    ORDER_STATUS_DELIVERED = 4;
    ORDER_STATUS_CANCELLED = 5;
}

message Order {
    string order_id = 1;
    OrderStatus status = 2;
}
```

### Message Examples

**Good Message Design**:
```protobuf
message Product {
    // Unique identifier
    string product_id = 1;
    
    // Required displayable information
    string name = 2;
    string description = 3;
    
    // Pricing
    Money price = 4;
    
    // Categorization
    repeated string category_ids = 5;
    
    // Media
    string image_url = 6;
    repeated string review_image_urls = 7;
    
    // Availability
    bool in_stock = 8;
    int32 quantity_available = 9;
    
    // Metadata
    int64 created_at_ms = 10;
    int64 updated_at_ms = 11;
}
```

**Bad Message Design** ❌:
```protobuf
message Product {
    string id = 1;
    string name = 2;
    string desc = 3;                    // Inconsistent naming
    string img = 4;                     // Abbreviated
    float price = 5;                    // Should use Money type
    string categories = 6;              // Should be repeated string
    string inStock = 7;                 // Should be bool
    double created = 8;                 // Should be Timestamp
    
    string extra_field_1 = 9;           // Vague naming
    string TMP_unused = 10;             // Hidden debt
}
```

## Service Design

### Request Context

Always include relevant context:

```protobuf
// Pattern: Include context in request, not headers
service CartService {
    rpc AddItem(AddItemRequest) returns (Empty) {}
}

message AddItemRequest {
    string user_id = 1;         // Who is doing this?
    CartItem item = 2;          // What are they adding?
    
    // Optional context
    string request_id = 3;      // For tracing
    int64 timestamp_ms = 4;     // Client timestamp
}
```

**Why include context in requests**:
- Language-agnostic (not tied to gRPC metadata)
- Easier to test and log
- Works with all gRPC transports
- Explicit and self-documenting

### Request Validation

Always validate on the server side:

```protobuf
message CreateOrderRequest {
    string user_id = 1;                      // Validated: not empty
    repeated OrderItem items = 2;            // Validated: not empty
    Address shipping_address = 3;            // Validated: all required fields
    CreditCard payment_method = 4;           // Validated: format checked
}
```

**Validation in code**:
```go
func (s *Server) CreateOrder(ctx context.Context, req *pb.CreateOrderRequest) (*pb.Order, error) {
    // Validate required fields
    if req.UserId == "" {
        return nil, status.Error(codes.InvalidArgument, "user_id is required")
    }
    
    if len(req.Items) == 0 {
        return nil, status.Error(codes.InvalidArgument, "at least one item is required")
    }
    
    // Validate each item
    for i, item := range req.Items {
        if item.ProductId == "" {
            return nil, status.Errorf(codes.InvalidArgument, "items[%d].product_id is required", i)
        }
        if item.Quantity <= 0 {
            return nil, status.Errorf(codes.InvalidArgument, "items[%d].quantity must be positive", i)
        }
    }
    
    // Proceed with valid request
    order, err := s.service.CreateOrder(ctx, req)
    if err != nil {
        return nil, status.Error(codes.Internal, "failed to create order")
    }
    
    return order, nil
}
```

## Error Handling

### gRPC Status Codes

Use appropriate gRPC error codes:

| Code | Use Case | Example |
|------|----------|---------|
| `OK` (0) | Success | Request completed |
| `CANCELLED` (1) | Client cancelled | User aborted operation |
| `UNKNOWN` (2) | Unknown error | Unexpected server failure |
| `INVALID_ARGUMENT` (3) | Bad input | Empty required field |
| `DEADLINE_EXCEEDED` (4) | Timeout | Operation took too long |
| `NOT_FOUND` (5) | Resource missing | Product doesn't exist |
| `ALREADY_EXISTS` (6) | Duplicate resource | User already exists |
| `PERMISSION_DENIED` (7) | Unauthorized | User lacks permission |
| `RESOURCE_EXHAUSTED` (8) | Out of resources | Rate limit exceeded |
| `FAILED_PRECONDITION` (9) | Invalid state | Can't process incomplete order |
| `ABORTED` (10) | Transaction conflict | Concurrent modification |
| `OUT_OF_RANGE` (11) | Out of bounds | Invalid array index |
| `UNIMPLEMENTED` (12) | Not implemented | Feature not available |
| `INTERNAL` (13) | Server error | Unexpected server bug |
| `UNAVAILABLE` (14) | Unavailable | Service down |
| `DATA_LOSS` (15) | Data loss | Unrecoverable data loss |

### Error Response Pattern

```protobuf
// Error details (additional context)
message ProductError {
    string error_code = 1;          // Machine-readable code
    string message = 2;             // Human-readable message
    map<string, string> details = 3; // Additional context
}
```

**Go Implementation**:
```go
func (s *Server) GetProduct(ctx context.Context, req *pb.GetProductRequest) (*pb.Product, error) {
    product, err := s.repo.GetProduct(ctx, req.ProductId)
    
    if err == ErrNotFound {
        // Use NOT_FOUND status
        return nil, status.Error(codes.NotFound, "product not found")
    }
    
    if err == ErrInvalidID {
        // Use INVALID_ARGUMENT for client error
        return nil, status.Error(codes.InvalidArgument, "invalid product id format")
    }
    
    if err != nil {
        // Use INTERNAL for unexpected errors
        log.WithError(err).Error("unexpected error fetching product")
        return nil, status.Error(codes.Internal, "failed to fetch product")
    }
    
    return toProto(product), nil
}
```

### Error Handling Pattern

```protobuf
// For operations where partial failure is possible
message CheckoutResponse {
    OrderStatus status = 1;           // SUCCESS, PARTIALLY_FAILED, FAILED
    Order order = 2;                  // If successful
    repeated CheckoutError errors = 3; // Detailed error info
}

message CheckoutError {
    string service_name = 1;  // Which service failed?
    string error_message = 2; // What went wrong?
    int32 code = 3;           // Error code
}
```

## Naming Conventions

### General Rules

- **lowercase**: Package and field names
- **snake_case**: Field, message, enum names
- **camelCase**: Service and RPC method names
- **SCREAMING_SNAKE_CASE**: Enum values

### Examples

```protobuf
// Package: lowercase, dot-separated by domain
package hipstershop;

// Service: PascalCase with "Service" suffix
service ProductCatalogService {}

// RPC: camelCase (matches Go convention)
rpc listProducts(Empty) returns (ListProductsResponse) {}

// Message: PascalCase, descriptive, suffixed appropriately
message GetProductRequest {}
message ListProductsResponse {}
message Product {}

// Fields: snake_case
message Product {
    string product_id = 1;
    string product_name = 2;
    bool is_available = 3;
    int32 item_count = 4;
}

// Enums: SCREAMING_SNAKE_CASE with PREFIX
enum OrderStatus {
    ORDER_STATUS_UNSPECIFIED = 0;
    ORDER_STATUS_PENDING = 1;
    ORDER_STATUS_COMPLETED = 2;
}
```

## Versioning

### API Versioning Strategy

**Preferred Approach**: Avoid versioning, use backward-compatible changes

**Making Backward-Compatible Changes**:
```protobuf
// Original
message Product {
    string id = 1;
    string name = 2;
    Money price = 3;
}

// Adding optional field is safe
message Product {
    string id = 1;
    string name = 2;
    Money price = 3;
    string description = 4;  // New optional field, clients can ignore
}

// Adding enum value is safe (at the end)
enum OrderStatus {
    ORDER_STATUS_UNSPECIFIED = 0;
    ORDER_STATUS_PENDING = 1;
    ORDER_STATUS_COMPLETED = 2;
    ORDER_STATUS_PROCESSING = 3;  // New value, clients have existing default
}
```

**Breaking Changes** (When versioning is needed):

```protobuf
// Create new service version
service ProductCatalogServiceV2 {
    rpc getProduct(GetProductRequestV2) returns (ProductV2) {}
}

message ProductV2 {
    string id = 1;
    string name = 2;
    // Changed from Money to PricingInfo
    PricingInfo pricing = 3;
}
```

**Deprecation Pattern**:
```protobuf
message Product {
    string id = 1;
    string name = 2;
    Money price = 3 [deprecated = true];  // Old field
    PricingInfo pricing = 4;               // New field
}
```

## Documentation

### Proto Documentation

Every public API element should be documented:

```protobuf
// ProductCatalogService provides product lookup and search operations.
// All operations return products in USD pricing. Currency conversion
// is handled by the separate CurrencyService.
service ProductCatalogService {
    // GetProduct retrieves a single product by ID.
    //
    // Errors:
    //   NOT_FOUND: Product with given ID does not exist
    //   INVALID_ARGUMENT: Product ID is empty
    rpc GetProduct(GetProductRequest) returns (Product) {
        option (google.api.http) = {
            get: "/v1/products/{product_id}"
        };
    }
    
    // ListProducts returns all available products.
    //
    // Uses pagination to limit response size.
    // If page_token is empty, starts from beginning.
    rpc ListProducts(ListProductsRequest) returns (ListProductsResponse) {}
}

// GetProductRequest uniquely identifies a product.
message GetProductRequest {
    // Required. The unique product identifier.
    // Must not be empty.
    string product_id = 1;
}

// Product represents a merchandise item in the catalog.
message Product {
    // Unique product identifier.
    string id = 1;
    
    // Human-readable product name.
    // Length must be between 1 and 255 characters.
    string name = 2;
    
    // Detailed product description.
    string description = 3;
    
    // Product image URL.
    string picture = 4;
    
    // Current price in USD.
    Money price_usd = 5;
    
    // Product categories for browsing/filtering.
    // Examples: "clothing", "kitchen", "books"
    repeated string categories = 6;
}
```

## REST API (if applicable)

While Hipster Shop primarily uses gRPC, REST APIs may be needed for:
- Web browsers (via gRPC-JSON transcoding)
- Third-party integrations
- Public APIs

### gRPC-JSON Transcoding

Enable REST access automatically:

```protobuf
syntax = "proto3";

import "google/api/annotations.proto";

service ProductCatalogService {
    rpc GetProduct(GetProductRequest) returns (Product) {
        option (google.api.http) = {
            get: "/v1/products/{product_id}"
        };
    }
    
    rpc ListProducts(ListProductsRequest) returns (ListProductsResponse) {
        option (google.api.http) = {
            get: "/v1/products"
        };
    }
    
    rpc CreateProduct(CreateProductRequest) returns (Product) {
        option (google.api.http) = {
            post: "/v1/products"
            body: "*"
        };
    }
    
    rpc UpdateProduct(UpdateProductRequest) returns (Product) {
        option (google.api.http) = {
            patch: "/v1/products/{product_id}"
            body: "*"
        };
    }
    
    rpc DeleteProduct(DeleteProductRequest) returns (Empty) {
        option (google.api.http) = {
            delete: "/v1/products/{product_id}"
        };
    }
}
```

### REST URL Structure

```
GET    /v1/products              # List products
GET    /v1/products/{product_id} # Get product
POST   /v1/products              # Create product
PATCH  /v1/products/{product_id} # Update product
DELETE /v1/products/{product_id} # Delete product

GET    /v1/products?category=clothing  # Filter by category
GET    /v1/products?q=search_term      # Search
GET    /v1/products?page_size=10&page_token=abc123  # Pagination
```

### REST Response Format

```json
{
    "product_id": "OLJEKWC",
    "name": "Vintage Typewriter",
    "description": "A charming vintage typewriter with character",
    "picture": "https://example.com/images/vintage-typewriter.jpg",
    "price_usd": {
        "currency_code": "USD",
        "units": 79,
        "nanos": 990000000
    },
    "categories": ["tech", "vintage"]
}
```

### REST Error Responses

```json
{
    "error": {
        "code": 404,
        "message": "Product not found",
        "status": "NOT_FOUND",
        "details": [
            {
                "type": "type.googleapis.com/hipstershop.ProductError",
                "error_code": "PRODUCT_NOT_FOUND",
                "missing_product_id": "INVALID123"
            }
        ]
    }
}
```

---

**Last Updated**: March 2026  
**Reference**: [Google API Design Guide](https://cloud.google.com/apis/design)
