# Architecture Documentation

## System Design Overview

Hipster Shop is a distributed e-commerce system built using a **microservices architecture** with **synchronous communication via gRPC** and **asynchronous patterns** where applicable. The system prioritizes separation of concerns, independent deployability, and observability.

## High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Client Layer                                    │
│                    (Web Browser / Mobile App)                           │
└─────────────────────────────┬───────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    API Gateway / Frontend                               │
│                  Go HTTP Server (Port 8080)                             │
│  - Route requests to appropriate services                               │
│  - Session management & authentication                                  │
│  - HTML template rendering                                             │
│  - Currency & ad service integration                                    │
└──┬──────────────────────────────────────────────────────────────────────┘
   │
   └─────────────────────────────────────────────────────────────────┐
                                                                      │
         ┌────────────────────────────────────────────────────┐      │
         │                                                    │      │
         ▼                                                    ▼      ▼
    ┌─────────────┐  ┌──────────────┐  ┌──────────┐  ┌─────────────────┐
    │  Product    │  │    Cart      │  │Currency  │  │ Recommendation  │
    │  Catalog    │  │   Service    │  │ Service  │  │   Service       │
    │ (Go:3550)   │  │  (C#:7070)   │  │(Node:7k) │  │ (Python:50053)  │
    └─────────────┘  └──────────────┘  └──────────┘  └─────────────────┘
         │                     │              │              │
         └─────────────────────┴──────────────┴──────────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   Checkout Service   │
                    │     (Go:5050)        │
                    │   Orchestrator       │
                    └────────┬─────────────┘
                             │
           ┌─────────────────┼──────────────────┐
           │                 │                  │
           ▼                 ▼                  ▼
    ┌─────────────┐  ┌────────────┐   ┌──────────────┐
    │  Payment    │  │ Shipping   │   │    Email     │
    │  Service    │  │ Service    │   │   Service    │
    │(Node:50051) │  │(Go:50051)  │   │(Python:50051)│
    └─────────────┘  └────────────┘   └──────────────┘
           │                │                │
           └────────────────┴────────────────┘
                    │
    ┌───────────────┴──────────────┐
    │                              │
    ▼                              ▼
┌──────────────┐          ┌──────────────┐
│     Ad       │          │  Shopping    │
│   Service    │          │  Assistant   │
│ (Java:9555)  │          │ (Python:5000)│
└──────────────┘          └──────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                    Infrastructure Layer                                 │
│  - Service Registry / Discovery                                         │
│  - Load Balancing                                                       │
│  - Distributed Tracing (OpenTelemetry → Cloud Trace)                   │
│  - Logging & Monitoring                                                 │
│  - Container Orchestration (Kubernetes)                                 │
└─────────────────────────────────────────────────────────────────────────┘
```

## Component Breakdown

### 1. Frontend Service (Go HTTP)

**Role**: Web application gateway and user interface server

**Responsibilities**:
- Serve HTML/CSS/JS frontend
- Route HTTP requests to appropriate gRPC services
- Manage user sessions and cookies
- Handle validation and error responses
- Integrate multiple services into coherent user experience

**Key Interactions**:
```
Frontend HTTP → gRPC clients → (ProductCatalog, Cart, Currency, 
                                 Recommendation, Checkout, Shipping, 
                                 Ad, ShoppingAssistant)
```

**Technology Stack**:
- Framework: Gorilla Mux (HTTP router)
- Client: gRPC with insecure connections (local dev)
- Profiling: Google Cloud Profiler
- Tracing: OpenTelemetry OTLP
- Logging: Logrus

**State Management**:
- Session IDs stored in cookies
- Ephemeral state (no persistence required)

---

### 2. Product Catalog Service (Go gRPC)

**Role**: Central product data repository

**Responsibilities**:
- Maintain product database
- Provide product search and filtering
- Return product details with pricing
- Support dynamic catalog updates

**Key Operations**:
```protobuf
service ProductCatalogService {
    rpc ListProducts(Empty) returns (ListProductsResponse) {}
    rpc GetProduct(GetProductRequest) returns (Product) {}
    rpc SearchProducts(SearchProductsRequest) returns (SearchProductsResponse) {}
}
```

**Data Model**:
```
Product:
  - id (string): Unique identifier
  - name (string): Display name
  - description (string): Full description
  - picture (string): Image URL
  - price_usd (Money): USD pricing
  - categories (repeated string): Category tags
```

**Data Source**:
- Loads from `products.json` at startup
- Supports dynamic reloading via signal handlers
- Can integrate with PostgreSQL via AlloyDB

**Intentional Demo Features**:
- Catalog reload bug (intentional bug for debugging demonstration)
- Configurable latency injection via `EXTRA_LATENCY` env var

---

### 3. Cart Service (C# / .NET gRPC)

**Role**: Shopping cart state management

**Responsibilities**:
- Store user cart items per session
- Manage cart modifications (add/remove/empty)
- Ensure cart consistency
- Support multi-user concurrent access

**Key Operations**:
```protobuf
service CartService {
    rpc AddItem(AddItemRequest) returns (Empty) {}
    rpc GetCart(GetCartRequest) returns (Cart) {}
    rpc EmptyCart(EmptyCartRequest) returns (Empty) {}
}
```

**Data Model**:
```
Cart:
  - user_id (string): Session/user identifier
  - items[] (CartItem): Array of cart items

CartItem:
  - product_id (string): Reference to product
  - quantity (int32): Number of units
```

**Storage Strategy**:
- In-memory HashTable (development)
- Optional Redis backend (production)
- Cart tied to user_id (session-based)

**Concurrency**:
- Thread-safe operations via locks
- Non-persistent storage (ephemeral)

---

### 4. Checkout Service (Go gRPC Orchestrator)

**Role**: Order processing orchestrator

**Responsibilities**:
- Coordinate multi-service checkout workflow
- Validate inventory and pricing
- Process payments
- Generate shipping orders
- Send confirmations

**Workflow**:
```
1. Validate cart items with ProductCatalog
2. Fetch cart from CartService
3. Verify prices and apply currency conversion
4. Calculate shipping with ShippingService
5. Process payment with PaymentService
6. Create shipment with ShippingService
7. Send order confirmation with EmailService
8. Clear cart with CartService
```

**Distributed Transaction Pattern**:
- Implements SAGA pattern (orchestrator version)
- Forward-only flow (no compensating transactions)
- Idempotency via request IDs

**Error Handling**:
- Partial failure detection
- Logging of failed operations
- Error reporting to frontend

---

### 5. Payment Service (Node.js gRPC)

**Role**: Payment processing gateway

**Responsibilities**:
- Validate credit cards
- Process card charges
- Generate transaction IDs
- Log payment transactions

**Key Operations**:
```protobuf
service PaymentService {
    rpc Charge(ChargeRequest) returns (ChargeResponse) {}
}
```

**Data Model**:
```
ChargeRequest:
  - amount (Money): Transaction amount
  - credit_card (CreditCardInfo): Card details

ChargeResponse:
  - transaction_id (string): Unique transaction ID
  - success (bool): Payment status
```

**Features**:
- Card validation using `simple-card-validator` library
- UUID-based transaction IDs
- Simulated processing (demo purposes)

**Security Notes**:
- Never logs sensitive card data
- In-memory processing only
- Validates card format before processing

---

### 6. Shipping Service (Go gRPC)

**Role**: Shipping cost calculation and order fulfillment

**Responsibilities**:
- Calculate shipping costs based on address and items
- Generate tracking numbers
- Validate shipping addresses

**Key Operations**:
```protobuf
service ShippingService {
    rpc GetQuote(GetQuoteRequest) returns (GetQuoteResponse) {}
    rpc ShipOrder(ShipOrderRequest) returns (ShipOrderResponse) {}
}
```

**Quote Calculation Algorithm**:
```
- Base rate: $5.99 (USD)
- Per-item cost: $0.20 × quantity
- Address validation: Domestic vs. international
- Example: 5 items = $5.99 + (0.20 × 5) = $6.99
```

**Tracking ID Generation**:
- Format: `SHIP-{timestamp}-{random}`
- Uniqueness guaranteed per order

**Integrated Tests**:
- Unit tests in `shipping_test.go`
- QuoteService interface tests
- Address validation tests

---

### 7. Email Service (Python gRPC)

**Role**: Order confirmation notification

**Responsibilities**:
- Generate order confirmation emails
- Render HTML templates
- Send email notifications
- Log email delivery

**Key Operations**:
```protobuf
service EmailService {
    rpc SendOrderConfirmation(OrderConfirmationRequest) returns (Empty) {}
}
```

**Template Engine**:
- Jinja2 HTML templates
- Dynamic data binding
- Order line item rendering

**Email Delivery**:
- Google Cloud Mail Client (placeholder)
- SMTP support (configurable)
- Async delivery pattern

**Templates**:
- `confirmation.html`: Order confirmation template
- Dynamic order details rendering
- Invoice information inclusion

---

### 8. Currency Service (Node.js gRPC)

**Role**: Multi-currency support and conversion

**Responsibilities**:
- Maintain exchange rates
- Perform currency conversions
- List supported currencies
- Cache conversion results

**Key Operations**:
```protobuf
service CurrencyService {
    rpc GetSupportedCurrencies(Empty) returns (GetSupportedCurrenciesResponse) {}
    rpc Convert(ConvertRequest) returns (Money) {}
}
```

**Supported Currencies**:
- USD (US Dollar) - base currency
- EUR (Euro)
- CAD (Canadian Dollar)
- JPY (Japanese Yen)
- GBP (British Pound)
- TRY (Turkish Lira)

**Data Source**:
- Configuration from `data/currency_conversion.json`
- Static rates (for predictable demo)
- Can integrate with real-time exchange APIs

**Conversion Algorithm**:
```
amount_in_new_currency = amount_in_usd × (conversion_rate)
```

---

### 9. Ad Service (Java gRPC)

**Role**: Advertisement serving

**Responsibilities**:
- Serve relevant ads based on context
- Provide fallback ads
- Generate ad impressions

**Key Operations**:
```protobuf
service AdService {
    rpc GetAds(AdRequest) returns (AdResponse) {}
}
```

**Context Matching**:
- Category-based ad matching
- Keyword-based targeting
- Context-aware filtering

**Default Behavior**:
- Serves random ads if no context provided
- Fallback ad always available
- Rate limiting built-in

**Stack**:
- Java 21
- Gradle build system
- Protocol Buffers compilation
- Log4j logging

---

### 10. Recommendation Service (Python gRPC)

**Role**: Product recommendations engine

**Responsibilities**:
- Generate personalized product recommendations
- Filter out already-viewed products
- Provide collaborative filtering

**Key Operations**:
```protobuf
service RecommendationService {
    rpc ListRecommendations(ListRecommendationsRequest) 
        returns (ListRecommendationsResponse) {}
}
```

**Algorithm**:
```
1. Get all products from ProductCatalog
2. Filter out products already viewed by user
3. Return random sample (typically 5 products)
4. Implement smarter collaborative filtering in production
```

**Recommendation Pipeline**:
- Fetch product list dynamically
- Application-level filtering (Python)
- Random selection (can be ML-based)

**Scalability Considerations**:
- Caching recommendation results
- Batch recommendation generation
- ML model integration points

---

### 11. Shopping Assistant Service (Python REST/gRPC)

**Role**: AI-powered product recommendation with vision

**Responsibilities**:
- Analyze room images using Gemini Vision API
- Generate product recommendations based on room context
- Integrate vector database for semantic search
- Implement RAG (Retrieval-Augmented Generation) pipeline

**Architecture**:
```
Client (room image)
    ↓
Flask REST API
    ↓
Google Gemini 1.5-flash (vision analysis)
    ↓
Room description extraction
    ↓
LangChain RAG Pipeline
    ↓
Vector embedding generation
    ↓
AlloyDB Vector Search
    ↓
Product matching
    ↓
AI-curated recommendations
```

**Key Features**:
- Vision model integration
- Vector database querying
- Context-aware recommendations
- Multi-turn conversation support

**Technology**:
- Flask (REST API framework)
- LangChain (AI orchestration)
- Google Generative AI (Gemini models)
- AlloyDB with pgvector extension
- Vector embeddings for semantic search

---

### 12. Load Generator (Python Locust)

**Role**: Load testing and stress testing

**Responsibilities**:
- Simulate realistic user behavior
- Generate load on system
- Identify performance bottlenecks
- Collect performance metrics

**Simulated User Flows**:
```
1. Browse homepage
2. Set currency preference
3. View product details
4. Add items to cart
5. View cart
6. Execute checkout with payment
7. View order confirmation
8. Clear cart
9. Logout/repeat
```

**Test Data**:
- Faker-generated realistic addresses and emails
- Predefined product IDs
- Randomized quantities and currencies
- Realistic inter-request delays

**Distributed Load Testing**:
- Multi-worker capability
- Scalable load generation
- Real-time metrics UI

---

## Data Flow Diagrams

### Checkout Flow

```
USER REQUEST: CheckoutRequest
    │
    ▼
Frontend Service
    │
    ├─→ [ProductCatalog] Verify products exist
    │   └─→ Get product prices
    │
    ├─→ [Cart] Get cart items
    │   └─→ Validate item availability
    │
    ├─→ [Currency] Convert prices if needed
    │   └─→ Total price calculation
    │
    ├─→ [Shipping] Get shipping quote
    │   └─→ Calculate delivery cost
    │
    ├─→ [Payment] Process card payment
    │   └─→ Charge card (transaction ID generated)
    │
    ├─→ [Shipping] Create shipment
    │   └─→ Generate tracking number
    │
    ├─→ [Email] Send order confirmation
    │   └─→ Confirmation email delivered
    │
    ├─→ [Cart] Empty user's cart
    │   └─→ Cart cleared
    │
    └─→ Response: Order ID + Tracking Info
```

### Product Discovery Flow

```
USER: Browse products
    │
    ▼
Frontend (HTTP)
    │
    ├─→ [ProductCatalog] List all products
    │   └─→ Return paginated product list
    │
    ├─→ [Currency] Get conversion rates
    │   └─→ Display prices in user's currency
    │
    ├─→ [Recommendation] Get personalized recommendations
    │   └─→ Filter + return 5 products
    │
    ├─→ [Ad] Get relevant ads
    │   └─→ Return ad for context
    │
    ├─→ [Cart] Get current cart state
    │   └─→ Display cart summary
    │
    └─→ Response: Rendered product page (HTML)
```

### Payment Processing Flow

```
Payment Request
    │
    ▼
Payment Service
    │
    ├─ Validate credit card
    │   └─→ Check format, expiration, checksum
    │
    ├─ Generate transaction ID
    │   └─→ UUID-based unique identifier
    │
    ├─ Simulate charge
    │   └─→ Random success/failure
    │
    └─→ Response: Transaction ID + Status
```

## Communication Patterns

### Synchronous Communication (gRPC)

**When Used**: Time-sensitive operations requiring immediate response
- Frontend → Service queries
- Checkout orchestration
- Product lookups
- Payment processing

**Advantages**:
- Strong contracts via Protocol Buffers
- Type-safe communication
- Built-in request/response validation
- Efficient binary protocol

**Consistency**: Request-response (bidirectional)

```
Client Request
    ↓
Server processes
    ↓
Response sent
    ↓
Acknowledgment received
```

### Asynchronous Patterns (via events)

**When Used**: Background operations, notifications
- Email sending
- Tracing events
- Logging

**Implementation**: Event emission through OpenTelemetry spans

## Design Patterns

### 1. Service Orchestrator Pattern
**Implemented by**: CheckoutService
- Coordinates multiple services
- Manages workflow state
- Handles errors and retries
- Returns aggregate response

### 2. Strangler Pattern
**Applied to**: Legacy system migration
- ShoppingAssistant wraps product search
- Gradual addition of AI features
- Backward compatibility maintained

### 3. Circuit Breaker (implicit)
**When applicable**: In production K8s deployments
- Service mesh (Istio) provides circuit breaking
- Local implementations could add retry logic
- Graceful degradation on service failures

### 4. Caching
**Implemented at**: Frontend service
- Session caching
- Product cache (CDN)
- Currency rates cache
- Ad response cache

### 5. Bulkhead Pattern
**Infrastructure-level**: Via container resource limits
- Each service in isolated container
- Resource quotas prevent cascade failures
- Independent scaling possible

## Scalability Considerations

### Horizontal Scaling
- Services independently deployable
- Load balancers distribute traffic
- Kubernetes handles auto-scaling
- Database clustering via AlloyDB

### Vertical Scaling
- Resource limits per container
- Increase CPU/memory as needed
- Language-specific optimizations possible

### Database Scaling
- PostgreSQL replication
- Read replicas for queries
- Write-through for transactions
- Vector database (AlloyDB) for embeddings

### Caching Strategy
- Frontend service caching
- gRPC response caching
- CDN for static assets
- Distributed cache (Redis optional)

## Security Architecture

### Network Level
- gRPC with TLS (in production)
- Service mesh for mTLS
- Network policies restrict traffic
- Firewall rules per subnet

### Application Level
- Input validation on all endpoints
- Secret management via GCP Secret Manager
- No hardcoded credentials
- Environment-based configuration

### Data Protection
- Encryption in transit (TLS)
- Encryption at rest (database)
- Sensitive data exclusion from logs
- PII handling compliance

## Observability Architecture

### Three Pillars

#### 1. Metrics
- Service-level: Request count, latency, error rate
- System-level: CPU, memory, disk usage
- Business metrics: Conversion rate, avg order value
- Collector: Prometheus compatible exporters

#### 2. Logging
- Structured logging via Logrus/Python logging
- Centralized storage: Cloud Logging
- Log levels: DEBUG, INFO, WARN, ERROR
- Correlation IDs across services

#### 3. Tracing
- OpenTelemetry instrumentation
- Trace exporter: OTLP gRPC to Cloud Trace
- End-to-end request tracing
- Span relationships show service calls

### Distributed Tracing Flow

```
User Request
    │
    ▼ [Trace context generated]
Frontend (root span)
    │
    ├─→ ProductCatalog (child span)
    ├─→ Cart (child span)
    ├─→ Currency (child span)
    └─→ Recommendation (child span)
        │
        └─→ ProductCatalog (grandchild span)
    │
    ▼ [Trace aggregated in Cloud Trace]
Trace dashboard shows:
- Total latency
- Service bottlenecks
- Failure points
- Resource usage
```

## Deployment Architecture

### Development Environment
- Docker Compose orchestration
- Local gRPC connections (insecure)
- Minimal infrastructure
- SQLite/in-memory databases

### Staging Environment
- Kubernetes cluster
- Service mesh (Istio)
- Cloud SQL (PostgreSQL)
- GCP-integrated logging/tracing

### Production Environment
- Multi-zone Kubernetes cluster
- High availability services
- Database replication
- CDN for static content
- WAF for frontend
- Load balancing per service

## Fault Tolerance

### Service Failures
- Frontend → Graceful error pages
- Payment → Transaction logged (retry-safe)
- Shipping → Fallback pricing
- Email → Queue for retry

### Database Failures
- Read replicas for failover
- Transaction journals for recovery
- Distributed transactions via SAGA pattern
- Data consistency checks

### Network Failures
- Exponential backoff retries
- Circuit breaker patterns
- Graceful degradation
- Request timeout safeguards

---

## Summary

The Hipster Shop architecture demonstrates:

✓ **Loose Coupling**: Services communicate via gRPC contracts  
✓ **High Cohesion**: Each service has single responsibility  
✓ **Observability**: End-to-end distributed tracing  
✓ **Scalability**: Independent scaling per service  
✓ **Reliability**: Multi-level fault tolerance  
✓ **Flexibility**: Multiple language implementations  
✓ **Maintainability**: Clear service boundaries  
✓ **Testability**: Mock gRPC services for testing  

This architecture scales from development (Docker Compose) to production (Kubernetes with service mesh) without fundamental changes.
