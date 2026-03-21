# Microservices Demo - Hipster Shop

A comprehensive microservices reference application demonstrating modern distributed systems architecture, containerization, and cloud-native development patterns. Built on Google Cloud Platform with multiple language implementations and advanced observability features.

## Overview

**Hipster Shop** is an e-commerce platform showcasing best practices for building, deploying, and operating microservices at scale. This project serves as both a learning resource and a production-ready reference implementation.

### Key Characteristics

- **12+ microservices** in Go, Python, Node.js, and Java
- **gRPC** for efficient inter-service communication
- **Protocol Buffers** for service contracts
- **OpenTelemetry** for distributed tracing and observability
- **Containerized** with Docker and Kubernetes
- **Infrastructure as Code** using Terraform
- **AI-powered** features with Google Gemini integration
- **Load testing** capabilities with Locust

## Quick Features

- 🛒 Full e-commerce shopping experience
- 🌍 Multi-currency support with real-time conversion
- 📦 Intelligent shipping cost calculation
- ✉️ Order confirmation email service
- 🎯 Context-based ad serving
- 💳 Payment processing with card validation
- 🤖 AI-powered shopping assistant with room analysis
- 📊 Distributed tracing and performance monitoring
- 🔍 Product catalog with full-text search
- 💬 Product recommendations engine

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────────┐
│                   Frontend (Go)                         │
│                  Port 8080 (HTTP)                       │
└──────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌──────────────┐ ┌─────────────────┐ ┌──────────────┐
│   Product    │ │      Cart       │ │  Currency    │
│  Catalog     │ │    Service      │ │  Service     │
│  (Go:3550)   │ │    (C#:7070)    │ │  (Node:7000) │
└──────────────┘ └─────────────────┘ └──────────────┘
        │                 │                 │
        └─────────────────┼─────────────────┘
                          │
                    ┌─────▼─────┐
                    │  Checkout  │
                    │   (Go)     │
                    └────┬──────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
    Payment           Shipping          Email
    (Node:50051)   (Go:50051)      (Python:50051)
```

## Tech Stack

### Core Technologies

| Component | Technology | Version |
|-----------|-----------|---------|
| **Service Communication** | gRPC | 1.79+ |
| **Serialization** | Protocol Buffers | v3 |
| **Frontend** | Go | 1.25+ |
| **Backend Languages** | Go, Python, Node.js, Java | Multiple |
| **Containerization** | Docker | Latest |
| **Orchestration** | Kubernetes | K8s-compatible |
| **Infrastructure** | Terraform | 1.0+ |
| **Observability** | OpenTelemetry | Latest |
| **Tracing Backend** | Google Cloud Trace | GCP |
| **Database** | PostgreSQL/AlloyDB | Latest |
| **AI Framework** | LangChain + Google Gemini | Latest |

### Service-Specific Stack

| Service | Language | Port | Key Framework |
|---------|----------|------|-------|
| Frontend | Go | 8080 | Gorilla Mux |
| Product Catalog | Go | 3550 | gRPC Server |
| Cart Service | C# / .NET | 7070 | ASP.NET Core |
| Payment | Node.js | 50051 | @grpc/grpc-js |
| Shipping | Go | 50051 | gRPC Server |
| Email | Python | 50051 | gRPC + Jinja2 |
| Currency | Node.js | 7000 | @grpc/grpc-js |
| Ad Service | Java | 9555 | Spring Boot / Gradle |
| Recommendation | Python | 50053 | gRPC + Scikit |
| Checkout | Go | 5050 | gRPC Orchestrator |
| Load Generator | Python | N/A | Locust |
| Shopping Assistant | Python | 5000 | Flask + LangChain |

## Installation & Setup

### Prerequisites

- Docker & Docker Compose (or Kubernetes)
- Go 1.25+
- Python 3.9+
- Node.js 16+
- Java 21+
- Terraform 1.0+ (for infrastructure)
- GCP Account (for cloud services)

### Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
   cd microservices-demo
   ```

2. **Set environment variables** (if using GCP services)
   ```bash
   export GOOGLE_CLOUD_PROJECT="your-project-id"
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
   ```

3. **Build and run services**
   
   **Option A: Local Development**
   ```bash
   # Each service builds independently
   cd src/frontend
   go build -o frontend
   ```

   **Option B: Docker**
   ```bash
   # Build all services
   docker-compose build
   
   # Run all services
   docker-compose up -d
   ```

   **Option C: Kubernetes**
   ```bash
   # Deploy to K8s cluster
   kubectl apply -f k8s/
   ```

4. **Access the application**
   - Frontend: `http://localhost:8080`
   - Load Generator UI: `http://localhost:8089`

### Service Build Commands

```bash
# Frontend (Go)
cd src/frontend && go build

# Product Catalog (Go)
cd src/productcatalogservice && go build

# Cart Service (C#)
cd src/cartservice && dotnet build

# Payment Service (Node.js)
cd src/paymentservice && npm install && npm start

# Shipping Service (Go)
cd src/shippingservice && go build

# Email Service (Python)
cd src/emailservice && pip install -r requirements.txt && python email_server.py

# Currency Service (Node.js)
cd src/currencyservice && npm install && npm start

# Ad Service (Java)
cd src/adservice && ./gradlew installDist

# Recommendation Service (Python)
cd src/recommendationservice && pip install -r requirements.txt && python recommendation_server.py

# Checkout Service (Go)
cd src/checkoutservice && go build

# Load Generator (Python)
cd src/loadgenerator && pip install -r requirements.txt && locust -f locustfile.py
```

## Project Structure

```
microservices-demo/
├── src/
│   ├── frontend/                   # Web UI (Go)
│   ├── productcatalogservice/      # Product data (Go)
│   ├── cartservice/                # Cart management (C#)
│   ├── paymentservice/             # Payment processing (Node.js)
│   ├── shippingservice/            # Shipping service (Go)
│   ├── emailservice/               # Email notifications (Python)
│   ├── currencyservice/            # Currency conversion (Node.js)
│   ├── adservice/                  # Ad serving (Java)
│   ├── recommendationservice/      # Recommendations (Python)
│   ├── checkoutservice/            # Order orchestration (Go)
│   ├── shoppingassistantservice/  # AI assistant (Python)
│   └── loadgenerator/              # Load testing (Python)
├── terraform_ci/                   # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/                    # Terraform modules
├── k8s/                            # Kubernetes manifests (if exists)
├── docs/                           # Documentation
└── [Documentation files created by this setup]
```

## Usage Guide

### Running a Single Service

Each service can run independently after building:

```bash
# Terminal 1: Start Frontend
cd src/frontend && go run main.go

# Terminal 2: Start Product Catalog
cd src/productcatalogservice && go run product_catalog.go

# Terminal 3: Start Cart Service
cd src/cartservice && dotnet run

# ... and so on for other services
```

### Running All Services

**Docker Compose (Recommended for local dev)**
```bash
docker-compose up -d
```

**Kubernetes**
```bash
kubectl apply -f k8s/
kubectl port-forward svc/frontend 8080:8080
```

### Load Testing

```bash
cd src/loadgenerator
pip install -r requirements.txt
locust -f locustfile.py -u 100 -r 10 -t 10m --host=http://localhost:8080
```

Access the Locust UI at `http://localhost:8089`

### Monitoring & Observability

Services emit traces to Google Cloud Trace. View traces:

```bash
gcloud trace list
gcloud trace describe <trace-id>
```

## Configuration

### Environment Variables

Key environment variables for cloud services:

```bash
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=/path/to/creds.json
PORT=8080                          # Service port
LOG_LEVEL=info                     # Logging level
EXTRA_LATENCY=                     # Artificial latency (ms)
TLS_CERT_PATH=                     # TLS certificate
DISABLE_TRACING=false              # Disable OpenTelemetry
```

### Service-Specific Configuration

Refer to individual service READMEs in each `src/*/README.md`

## Features by Service

### Frontend
- Product browsing and filtering
- Shopping cart management
- Checkout flow
- Multi-currency support
- Ad display integration
- Session management

### Product Catalog
- Product listing with pagination
- Full-text search
- Product details and pricing
- Category filtering
- Inventory management

### Cart Service
- Add/remove items
- Update quantities
- Cart persistence
- Multi-user sessions

### Checkout
- Order orchestration
- Service transaction coordination
- Order confirmation
- Address validation

### Payment Service
- Credit card validation
- Payment processing
- Transaction logging
- Idempotency handling

### Shipping Service
- Shipping cost quotes
- Address-based calculations
- Order tracking
- Shipment creation

### Email Service
- Order confirmation templates
- Email dispatch
- Template rendering
- Delivery logging

### Currency Service
- Real-time currency conversion
- Multi-currency support (USD, EUR, JPY, GBP, CAD, TRY)
- Rate caching

### Ad Service
- Context-based ad serving
- Default ad fallback
- Category matching

### Recommendation Engine
- Product recommendations
- Collaborative filtering
- Personalized suggestions

### AI Shopping Assistant
- Room image analysis with Gemini Vision
- Vector-based product search
- AI-powered recommendations
- RAG pipeline

## Development Workflow

1. **Make code changes** in `src/service-name/`
2. **Build the service**
3. **Run local tests**
4. **Build Docker image** (if containerizing)
5. **Push to registry** (for deployment)
6. **Update deployment manifests** (K8s YAML)
7. **Deploy** to cluster

## Troubleshooting

### Service fails to start
- Check port availability: `lsof -i :PORT`
- Verify environment variables: `env | grep GOOGLE`
- Check logs: `docker logs <service-name>`

### gRPC connection errors
- Verify service is running on expected port
- Check firewall rules
- Review DNS resolution

### Performance issues
- Monitor traces in Cloud Trace
- Check service logs
- Review resource utilization
- Run load tests to identify bottlenecks

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Code standards
- Branching strategy
- Pull request process
- Testing requirements

## Development Guide

Detailed setup and development instructions in [DEV_GUIDE.md](DEV_GUIDE.md)

## Architecture Details

For deep technical architecture, see [ARCHITECTURE.md](ARCHITECTURE.md)

## Security

Security best practices and guidelines in [SECURITY.md](SECURITY.md)

## Deployment

Deployment procedures and strategies in [DEPLOYMENT.md](DEPLOYMENT.md)

## API Guidelines

gRPC and REST API design guidelines in [API_GUIDELINES.md](API_GUIDELINES.md)

## AI Coding Rules

Guidelines for AI coding assistants in [AI_RULES.md](AI_RULES.md)

## License

Apache License 2.0 - See each service's Dockerfile for original copyright

## References

- [Google Cloud Platform Microservices Demo](https://github.com/GoogleCloudPlatform/microservices-demo)
- [gRPC Documentation](https://grpc.io/docs/)
- [Protocol Buffers](https://developers.google.com/protocol-buffers)
- [OpenTelemetry](https://opentelemetry.io/)
- [Terraform](https://www.terraform.io/)

## Support & Feedback

For issues, questions, or feedback:
1. Check existing documentation
2. Review service-specific READMEs
3. Consult troubleshooting guides
4. Open an issue with detailed context

---

**Last Updated**: March 2026  
**Project Status**: Production-Ready Reference Implementation
