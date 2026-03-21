# Developer Guide

Complete guide for setting up, developing, and testing the Hipster Shop microservices locally.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Development Environment Setup](#development-environment-setup)
3. [Running Services Locally](#running-services-locally)
4. [Service Development](#service-development)
5. [Testing](#testing)
6. [Debugging](#debugging)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements
- OS: Linux, macOS, or Windows (with WSL2 recommended)
- RAM: 8GB minimum (16GB recommended for all services)
- Disk: 20GB available space
- Network: Internet connection for dependency downloads

### Required Tools

#### Core Tools
- **Git**: [https://git-scm.com/](https://git-scm.com/)
- **Docker**: [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop) (20.10+)
- **Docker Compose**: Included with Docker Desktop

#### Language-Specific Tools

**Go**:
```bash
# Install Go 1.25+
curl -L https://go.dev/dl/go1.25.0.linux-amd64.tar.gz | tar xz -C /usr/local
export PATH=$PATH:/usr/local/go/bin

# Verify
go version
```

**Python**:
```bash
# Install Python 3.9+
# macOS: brew install python@3.11
# Ubuntu: sudo apt-get install python3.11 python3.11-venv

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# or
venv\Scripts\activate  # Windows
```

**Node.js**:
```bash
# Install Node.js 16+ (recommend using nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 18
nvm use 18
```

**Java**:
```bash
# Install JDK 21
# macOS: brew install openjdk@21
# Ubuntu: sudo apt-get install openjdk-21-jdk

# Verify
java -version
```

**.NET**:
```bash
# Install .NET 7.0+ SDK
# Download from https://dotnet.microsoft.com/download
# Or macOS: brew install dotnet

# Verify
dotnet --version
```

#### Development Tools (Recommended)

| Tool | Purpose | Installation |
|------|---------|--------------|
| **make** | Task automation | `sudo apt-get install make` |
| **protoc** | Proto compilation | See [Proto Compiler](#proto-compiler-setup) |
| **golangci-lint** | Go linting | `brew install golangci-lint` |
| **black** | Python formatter | `pip install black` |
| **prettier** | JS/Node formatter | `npm install -g prettier` |
| **kubectl** | K8s management | [Install guide](https://kubernetes.io/docs/tasks/tools/) |

### Proto Compiler Setup

**macOS**:
```bash
brew install protobuf
protoc --version
```

**Ubuntu**:
```bash
sudo apt-get install protobuf-compiler
protoc --version
```

**Install gRPC plugins**:
```bash
# Go
go install github.com/grpc/grpc-go/cmd/protoc-gen-go-grpc@latest

# Node.js
npm install -g grpc-tools

# Python
pip install grpcio-tools
```

## Development Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
cd microservices-demo
```

### 2. Install Dependencies (All Services)

**Go Services**:
```bash
cd src/frontend && go mod download
cd ../productcatalogservice && go mod download
cd ../checkoutservice && go mod download
cd ../shippingservice && go mod download
```

**Python Services**:
```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install all Python requirements
cd src/emailservice && pip install -r requirements.txt
cd ../recommendationservice && pip install -r requirements.txt
cd ../loadgenerator && pip install -r requirements.txt
cd ../shoppingassistantservice && pip install -r requirements.txt
```

**Node.js Services**:
```bash
cd src/paymentservice && npm install
cd ../currencyservice && npm install
```

**Java Services**:
```bash
cd src/adservice
chmod +x gradlew
./gradlew dependencies
```

**.NET Services**:
```bash
cd src/cartservice
dotnet restore
```

### 3. Set Up Environment Variables

Create `.env` file in project root:

```bash
# Google Cloud (optional, for cloud services)
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json

# Service Ports
FRONTEND_PORT=8080
PRODUCT_CATALOG_PORT=3550
CART_SERVICE_PORT=7070
PAYMENT_SERVICE_PORT=50051
SHIPPING_SERVICE_PORT=50051
EMAIL_SERVICE_PORT=50051
CURRENCY_SERVICE_PORT=7000
AD_SERVICE_PORT=9555
RECOMMENDATION_SERVICE_PORT=50053
CHECKOUT_SERVICE_PORT=5050
SHOPPING_ASSISTANT_PORT=5000

# Logging
LOG_LEVEL=info
DISABLE_TRACING=true  # Set to true for local development

# Feature Flags
ENABLE_PROFILING=false
EXTRA_LATENCY=      # Leave empty or set to milliseconds (e.g., 100)
```

### 4. Verify Installation

```bash
# Check all tools
go version
python --version
node --version
java -version
dotnet --version

# Check Docker
docker --version
docker ps  # Verify Docker daemon is running
```

## Running Services Locally

### Option A: Docker Compose (Easiest)

**Build all services**:
```bash
docker-compose build
```

**Start all services**:
```bash
docker-compose up -d
```

**View logs**:
```bash
docker-compose logs -f  # All services
docker-compose logs -f frontend  # Specific service
```

**Stop services**:
```bash
docker-compose down
```

**Access application**:
- Frontend: http://localhost:8080
- Load Generator: http://localhost:8089

### Option B: Individual Service Development

Start services in separate terminals:

**Terminal 1 - Frontend**:
```bash
cd src/frontend
go run main.go
# Listens on :8080
```

**Terminal 2 - Product Catalog**:
```bash
cd src/productcatalogservice
go run product_catalog.go main.go
# Listens on :3550
```

**Terminal 3 - Cart Service**:
```bash
cd src/cartservice
dotnet run
# Listens on :7070
```

**Terminal 4 - Currency Service**:
```bash
cd src/currencyservice
npm start
# Listens on :7000
```

**Terminal 5 - Payment Service**:
```bash
cd src/paymentservice
npm start
# Listens on :50051
```

**Continue with remaining services as needed...**

### Service Port Mapping

| Service | Language | Port | Startup Command |
|---------|----------|------|-----------------|
| Frontend | Go | 8080 | `go run main.go` |
| Product Catalog | Go | 3550 | `go run product_catalog.go main.go` |
| Cart | C# | 7070 | `dotnet run` |
| Payment | Node.js | 50051 | `npm start` |
| Shipping | Go | 50051 | `go run main.go` |
| Email | Python | 50051 | `python email_server.py` |
| Currency | Node.js | 7000 | `npm start` |
| Ad Service | Java | 9555 | `./gradlew run` |
| Recommendation | Python | 50053 | `python recommendation_server.py` |
| Checkout | Go | 5050 | `go run main.go` |
| Load Generator | Python | 8089 | `locust -f locustfile.py` |
| Shopping Assistant | Python | 5000 | `python shoppingassistantservice.py` |

## Service Development

### Adding a New Service

1. **Create directory structure**:
```bash
mkdir -p src/newservice
cd src/newservice
```

2. **Create service scaffold** (choose language):

**Go**:
```go
// main.go
package main

import (
    "fmt"
    "log"
    "net"
    
    "google.golang.org/grpc"
    "google.golang.org/grpc/reflection"
    pb "github.com/GoogleCloudPlatform/microservices-demo/pb"
)

func main() {
    lis, err := net.Listen("tcp", ":5000")
    if err != nil {
        log.Fatalf("failed to listen: %v", err)
    }
    
    s := grpc.NewServer()
    pb.RegisterNewServiceServer(s, &server{})
    reflection.Register(s)
    
    if err := s.Serve(lis); err != nil {
        log.Fatalf("failed to serve: %v", err)
    }
}

type server struct{}

// Implement service methods
```

**Python**:
```python
# server.py
from concurrent import futures
import grpc
from demo_pb2_grpc import NewServiceServicer, add_NewServiceServicer_to_server
import demo_pb2

class NewService(NewServiceServicer):
    def MethodName(self, request, context):
        # Implementation
        return demo_pb2.Response()

def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    add_NewServiceServicer_to_server(NewService(), server)
    server.add_insecure_port('[::]:5000')
    server.start()
    server.wait_for_termination()

if __name__ == '__main__':
    serve()
```

**Node.js**:
```javascript
// index.js
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');

const packageDef = protoLoader.loadSync('proto/demo.proto', {});
const grpcObject = grpc.loadPackageDefinition(packageDef);

const server = new grpc.Server();

function methodName(call, callback) {
    // Implementation
    callback(null, {});
}

server.addService(grpcObject.NewService.service, { methodName });
server.bindAsync('0.0.0.0:5000', grpc.ServerCredentials.createInsecure(), () => {
    server.start();
    console.log('Server running on port 5000');
});
```

3. **Define Proto**:
```protobuf
// proto/demo.proto
syntax = "proto3";

package hipstershop;

service NewService {
    rpc MethodName(Request) returns (Response) {}
}

message Request {
    string id = 1;
}

message Response {
    string result = 1;
}
```

4. **Add to docker-compose.yaml**:
```yaml
newservice:
    build: ./src/newservice
    ports:
        - "5000:5000"
    environment:
        - LOG_LEVEL=info
    depends_on:
        - # List dependencies
```

### Modifying Existing Services

1. **Create feature branch**:
```bash
git checkout -b feature/service-improvement
```

2. **Make changes** in `src/service-name/`

3. **Test locally** (see [Testing](#testing) section)

4. **Commit and push**:
```bash
git add src/service-name/
git commit -m "feat(service): description"
git push origin feature/service-improvement
```

## Testing

### Unit Tests

**Go**:
```bash
cd src/service-name
go test ./...
go test -v ./...  # Verbose
go test -cover ./...  # Coverage
```

**Python**:
```bash
cd src/service-name
# Ensure pytest installed
pip install pytest pytest-cov

# Run tests
pytest
pytest -v  # Verbose
pytest --cov=.  # With coverage
```

**Node.js**:
```bash
cd src/service-name
npm test
npm test -- --coverage
```

**C#**:
```bash
cd src/cartservice/tests
dotnet test
dotnet test /p:CollectCoverage=true
```

**Java**:
```bash
cd src/adservice
./gradlew test
```

### Integration Tests

Test service-to-service communication:

```bash
# Build all services
docker-compose build

# Run services
docker-compose up -d

# Run integration tests (example)
cd src/loadgenerator
pip install -r requirements.txt
locust -f locustfile.py -u 10 -r 5 --headless -t 1m --host=http://localhost:8080

# Check logs for errors
docker-compose logs
```

### Load Testing

**Start load generator UI**:
```bash
cd src/loadgenerator
pip install -r requirements.txt
locust -f locustfile.py --host=http://localhost:8080
# Access UI at http://localhost:8089
```

**Run non-interactive load test**:
```bash
locust -f locustfile.py \
    --host=http://localhost:8080 \
    -u 100 \
    -r 10 \
    -t 10m \
    --headless
```

### Test Coverage Goals

- Frontend: > 70%
- Business Logic Services: > 85%
- API/Protocol: > 90%
- Infrastructure: >= 50%

## Debugging

### View Service Logs

**Docker Compose**:
```bash
docker-compose logs service-name
docker-compose logs -f service-name  # Follow logs
docker-compose logs --tail=100 service-name  # Last 100 lines
```

**Local Process**:
```bash
# Enable debug logging
LOG_LEVEL=debug go run main.go
```

### Debug Language-Specific

**Go Debugging**:
```bash
# Install delve debugger
go install github.com/go-delve/delve/cmd/dlv@latest

# Run with debugger
dlv debug ./main.go
# At dlv prompt: break main.main, continue, next, print <var>
```

**Python Debugging**:
```bash
# Add to code
import pdb; pdb.set_trace()

# Or use debugger directly
python -m pdb script.py
```

**Node.js Debugging**:
```bash
# Use built-in inspector
node --inspect index.js

# Access DevTools at chrome://inspect
# Or use VS Code debugger with launch config
```

**C# Debugging**:
```bash
# Use VS Code with C# extension
# F5 to launch debugger

# Or use dotnet CLI
dotnet run --debug
```

### Profiling

**Go Profile**:
```bash
# Add pprof endpoint in main
import _ "net/http/pprof"

# Profile endpoint: http://localhost:6060/debug/pprof/
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30
```

**Python Profile**:
```python
import cProfile
import pstats

profiler = cProfile.Profile()
profiler.enable()

# Code to profile

profiler.disable()
stats = pstats.Stats(profiler)
stats.sort_stats('cumulative')
stats.print_stats(20)  # Top 20
```

### gRPC Debugging

**Install grpcurl**:
```bash
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
```

**List services**:
```bash
grpcurl -plaintext localhost:3550 list
# Output:
# grpc.reflection.v1alpha.ServerReflection
# hipstershop.ProductCatalogService
```

**Call service**:
```bash
grpcurl -plaintext \
    -d '{}' \
    localhost:3550 \
    hipstershop.ProductCatalogService/ListProducts
```

### Network Debugging

**Check service ports**:
```bash
# macOS/Linux
lsof -i :8080  # Frontend
lsof -i :3550  # Product Catalog

# Windows (PowerShell)
netstat -ano | findstr :8080
```

**Check service connectivity**:
```bash
# From within container
docker-compose exec frontend curl http://productcatalogservice:3550

# Or use grpcurl
grpcurl -plaintext productcatalogservice:3550 list
```

## Troubleshooting

### Issue: Port Already in Use

**Problem**: `bind: address already in use`

**Solution**:
```bash
# Find process using port
lsof -i :8080  # macOS/Linux
netstat -ano | findstr :8080  # Windows

# Kill process
kill -9 <PID>  # macOS/Linux
taskkill /PID <PID> /F  # Windows

# Or change port
PORT=8081 go run main.go
```

### Issue: gRPC Connection Refused

**Problem**: `connection refused` when services try to communicate

**Solution**:
```bash
# Verify service is running
docker-compose ps

# Check service logs
docker-compose logs service-name

# Verify port is listening
lsof -i :3550

# Check firewall
sudo ufw status  # Ubuntu

# Try with explicit localhost
grpcurl -plaintext localhost:3550 list
```

### Issue: Docker Compose Build Fails

**Problem**: Build error for specific service

**Solution**:
```bash
# Check specific service logs
docker-compose build --no-cache service-name

# Check Dockerfile
cat src/service-name/Dockerfile

# Test locally
cd src/service-name
# Build using language tools directly
go build
npm install
python -m pip install -r requirements.txt
```

### Issue: Out of Memory

**Problem**: Docker/services crash due to memory

**Solution**:
```bash
# Increase Docker memory limit in Docker Desktop settings
# Or update docker-compose.yaml:
services:
    frontend:
        mem_limit: 512m
        memswap_limit: 1g

# Check memory usage
docker stats

# Reduce services running simultaneously
docker-compose up servicea serviceb  # Only specific services
```

### Issue: Protocol Buffer Compilation Error

**Problem**: `protoc: not found` or proto generation fails

**Solution**:
```bash
# Install protoc
brew install protobuf  # macOS
sudo apt-get install protobuf-compiler  # Ubuntu

# Install gRPC plugins
go install github.com/grpc/grpc-go/cmd/protoc-gen-go-grpc@latest
go install github.com/grpc/grpc-go/cmd/protoc-gen-go@latest

# Regenerate protos
cd src/service-name
./genproto.sh  # If available

# Manual generation
protoc --go_out=. --go-grpc_out=. proto/demo.proto
```

### Issue: Service Crashes on Start

**Problem**: Docker container exits immediately

**Solution**:
```bash
# Check exit code
docker-compose ps

# View logs
docker-compose logs service-name

# Run with interactive terminal
docker-compose run -it service-name /bin/sh  # Linux/macOS
docker-compose run -it service-name powershell  # Windows

# Test locally (outside Docker)
cd src/service-name
go run main.go  # And check error output
```

### Issue: Slow Service Startup

**Problem**: Services take long time to start

**Solution**:
```bash
# Check dependency startup order
docker-compose logs

# Add health checks to docker-compose.yaml
services:
    frontend:
        healthcheck:
            test: ["CMD", "curl", "-f", "http://localhost:8080"]
            interval: 10s
            timeout: 5s
            retries: 5

# Increase startup timeout
docker-compose up --wait
```

## Best Practices for Development

### Code Organization
- Keep services focused and modular
- Separate concerns (handlers, business logic, data access)
- Use interfaces for testability
- Export only what's necessary

### Error Handling
- Always check errors
- Provide context in error messages
- Log errors with full trace
- Return appropriate error codes

### Performance
- Profile before optimizing
- Monitor resource usage
- Test with realistic data sizes
- Consider caching strategies

### Security
- Never commit secrets
- Use environment variables for config
- Validate all inputs
- Scan dependencies for vulnerabilities

### Observability
- Add meaningful logs
- Use trace IDs for request tracking
- Monitor key metrics
- Set up alerts for anomalies

---

**Last Updated**: March 2026  
**For issues or questions**: See [CONTRIBUTING.md](CONTRIBUTING.md)
