# Security Guidelines

Security best practices and standards for the Hipster Shop microservices platform.

## Table of Contents

1. [Overview](#overview)
2. [Secrets Management](#secrets-management)
3. [Environment Variable Guidelines](#environment-variable-guidelines)
4. [Authentication & Authorization](#authentication--authorization)
5. [Data Protection](#data-protection)
6. [Network Security](#network-security)
7. [Dependency Management](#dependency-management)
8. [Code Security](#code-security)
9. [API Security](#api-security)
10. [Incident Response](#incident-response)

## Overview

Security is a shared responsibility across all layers:

```
┌─────────────────────────────────────────┐
│         Application Code                 │  Input validation, error handling
├─────────────────────────────────────────┤
│         API Layer                       │  Auth, rate limiting, CORS
├─────────────────────────────────────────┤
│         Service Layer                   │  Business logic, transactions
├─────────────────────────────────────────┤
│         Infrastructure                  │  K8s, TLS, firewalls
├─────────────────────────────────────────┤
│         Cloud Provider                  │  IAM, compliance, monitoring
└─────────────────────────────────────────┘
```

## Secrets Management

### Rule #1: Never Commit Secrets

**What NOT to commit**:
- Database passwords
- API keys
- JWT secrets
- Private certificates
- OAuth credentials
- SSH keys
- Credit card data

**Bad** ❌:
```go
const PAYMENT_API_KEY = "sk_test_123456789abcdef"  // WRONG!

password := "admin123"  // WRONG!

config := struct {
    DBPassword string
}{
    DBPassword: "postgres_pass_123",  // WRONG!
}
```

**Good** ✅:
```go
paymentAPIKey := os.Getenv("PAYMENT_API_KEY")
if paymentAPIKey == "" {
    log.Fatal("PAYMENT_API_KEY environment variable required")
}
```

### Git Security

**Add to .gitignore**:
```
# Secrets and credentials
.env
.env.local
.env.*.local
.secrets/
secrets.yaml
config.local.yml

# API keys and credentials
**/credentials.json
**/service-account-key.json
**/*.pem
**/*.key

# IDE secrets
.vscode/settings.json
.idea/misc.xml

# Build artifacts with embedded secrets
build/
dist/
*.jar
*.zip
```

**Remove accidentally committed secrets**:
```bash
# Remove from git history (use with caution)
git filter-branch --tree-filter 'rm -f secrets.yaml' HEAD

# Or use git-filter-repo
git filter-repo --invert-paths --path secrets.yaml

# Notify team and rotate credentials
```

### Secrets Storage

**Local Development**:
```bash
# Create local .env file (git-ignored)
cat > .env.local << EOF
GOOGLE_CLOUD_PROJECT=my-project
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
DATABASE_PASSWORD=dev_password_only
EOF

# Load in shell
set -a
source .env.local
set +a
```

**Docker Compose** (Development only):
```yaml
services:
    frontend:
        environment:
            - LOG_LEVEL=debug
        env_file:
            - .env.local  # Not committed to git
        # DON'T use this in production:
        # - DATABASE_PASSWORD=mysecret  # WRONG!
```

**Kubernetes Secrets**:
```yaml
apiVersion: v1
kind: Secret
metadata:
    name: app-secrets
    namespace: production
type: Opaque
data:
    # Base64 encoded (not encryption, just obfuscation)
    PAYMENT_API_KEY: c2tfdGVzdF8xMjM0NTY3ODlhYmNkZWY=
    DATABASE_PASSWORD: cG9zdGdyZXNfcGFzc3dvcmQ=
    JWT_SECRET: anN0X3NlY3JldF9rZXk=
```

**Google Cloud Secret Manager** (Recommended):
```bash
# Create secret
gcloud secrets create payment-api-key --data-file=- << EOF
sk_test_123456789abcdef
EOF

# Rotate secret
gcloud secrets versions add payment-api-key --data-file=- << EOF
sk_test_987654321zyxwvu
EOF

# Access secret in application
curl "https://secretmanager.googleapis.com/v1/projects/PROJECT_ID/secrets/payment-api-key/versions/latest:access"
```

## Environment Variable Guidelines

### Naming Conventions

**Pattern**: `SERVICE_NAME_SETTING_NAME`

```bash
# Frontend service
FRONTEND_LOG_LEVEL=info
FRONTEND_SESSION_TIMEOUT=3600

# Payment service
PAYMENT_API_KEY=sk_test_...
PAYMENT_WEBHOOK_SECRET=whsec_...
PAYMENT_TIMEOUT_MS=5000

# Database
DATABASE_HOST=db.internal
DATABASE_PORT=5432
DATABASE_NAME=hipstershop
DATABASE_USER=app
DATABASE_PASSWORD=<secret>
DATABASE_POOL_SIZE=20

# Google Cloud
GOOGLE_CLOUD_PROJECT=my-project
GOOGLE_APPLICATION_CREDENTIALS=/var/secrets/gcp/key.json

# Security
SECRET_KEY=<secret>
JWT_SECRET=<secret>
HMAC_KEY=<secret>

# Features
FEATURE_AI_RECOMMENDATIONS=true
FEATURE_PAYMENT_GOOGLE_PAY=false
```

### Environment Variable Types

```bash
# Strings (default)
DATABASE_HOST=postgres.internal

# Numbers
DATABASE_PORT=5432
CACHE_TTL=300

# Booleans
ENABLE_TRACING=true
DEBUG_MODE=false

# JSON (for complex config)
SERVICE_CONFIG='{"timeout":5000,"retries":3}'

# Lists (comma-separated)
ALLOWED_ORIGINS=https://example.com,https://app.example.com
```

### Safe Defaults

```go
// Always provide safe defaults
logLevel := os.Getenv("LOG_LEVEL")
if logLevel == "" {
    logLevel = "info"  // Safe default
}

// Validate against whitelist
validLevels := map[string]bool{
    "debug": true,
    "info": true,
    "warn": true,
    "error": true,
}
if !validLevels[logLevel] {
    log.Fatalf("Invalid LOG_LEVEL: %s", logLevel)
}
```

## Authentication & Authorization

### Service-to-Service Authentication

**mTLS (mutual TLS)**:

```go
// Client configuration
creds, err := credentials.NewClientTLSFromFile(
    "client-cert.pem",
    "client-key.pem",
    "ca-cert.pem",
)
if err != nil {
    log.Fatal(err)
}

conn, err := grpc.Dial(
    "payment-service:50051",
    grpc.WithTransportCredentials(creds),
)
```

**Google Cloud Service Account**:

```go
// Load service account credentials
ctx := context.Background()
credentials, err := google.FindDefaultCredentials(ctx)
if err != nil {
    log.Fatal(err)
}

// Use for gRPC interceptor
callCreds := credentials.TokenSource
```

### User Authentication

**JWT (JSON Web Token)**:

```go
// Typical flow:
// 1. User logs in with email/password
// 2. Server validates and issues JWT token
// 3. Client includes token in Authorization header

// Validation middleware
func authMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        authHeader := r.Header.Get("Authorization")
        if authHeader == "" {
            http.Error(w, "missing authorization", http.StatusUnauthorized)
            return
        }
        
        // Extract token from "Bearer <token>"
        parts := strings.Split(authHeader, " ")
        if len(parts) != 2 || parts[0] != "Bearer" {
            http.Error(w, "invalid authorization header", http.StatusUnauthorized)
            return
        }
        
        token := parts[1]
        claims, err := validateToken(token)
        if err != nil {
            http.Error(w, "invalid token", http.StatusUnauthorized)
            return
        }
        
        // Store claims in context
        ctx := context.WithValue(r.Context(), "user_id", claims.UserID)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func validateToken(token string) (*Claims, error) {
    // Parse and validate JWT signature
    claims := &Claims{}
    parsedToken, err := jwt.ParseWithClaims(token, claims, func(token *jwt.Token) (interface{}, error) {
        // Verify signing method
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, errors.New("unexpected signing method")
        }
        return []byte(os.Getenv("JWT_SECRET")), nil
    })
    
    if err != nil || !parsedToken.Valid {
        return nil, errors.New("invalid token")
    }
    
    // Check expiration
    if claims.ExpiresAt.Before(time.Now()) {
        return nil, errors.New("token expired")
    }
    
    return claims, nil
}
```

### RBAC (Role-Based Access Control)

```go
type Role string

const (
    RoleAdmin    Role = "admin"
    RoleManager  Role = "manager"
    RoleUser     Role = "user"
    RoleGuest    Role = "guest"
)

// Authorization middleware
func requireRole(requiredRole Role) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            claims, ok := r.Context().Value("claims").(*Claims)
            if !ok {
                http.Error(w, "unauthorized", http.StatusUnauthorized)
                return
            }
            
            hasRole := false
            for _, role := range claims.Roles {
                if role == string(requiredRole) {
                    hasRole = true
                    break
                }
            }
            
            if !hasRole {
                http.Error(w, "forbidden", http.StatusForbidden)
                return
            }
            
            next.ServeHTTP(w, r)
        })
    }
}

// Usage
router.HandleFunc("/admin/users", 
    requireRole(RoleAdmin)(deleteUserHandler)).Methods("DELETE")
```

## Data Protection

### In Transit (TLS/HTTPS)

**Kubernetes Ingress with HTTPS**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
    name: frontend
spec:
    tls:
    - hosts:
      - example.com
      secretName: tls-secret
    rules:
    - host: example.com
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: frontend
              port:
                number: 8080
```

**gRPC with TLS**:
```go
// Server
creds, err := credentials.NewServerTLSFromFile("server-cert.pem", "server-key.pem")
if err != nil {
    log.Fatal(err)
}

server := grpc.NewServer(grpc.Creds(creds))

// Client
creds, err := credentials.NewClientTLSFromFile(
    "ca-cert.pem",
    "payment-service",
)
if err != nil {
    log.Fatal(err)
}

conn, err := grpc.Dial(
    "payment-service:50051",
    grpc.WithTransportCredentials(creds),
)
```

### At Rest (Database Encryption)

```bash
# PostgreSQL encryption (pgcrypto extension)
CREATE EXTENSION pgcrypto;

-- Encrypt sensitive data
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    ssn BYTEA NOT NULL,  -- Encrypted
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Encrypt on insert
INSERT INTO users (email, password_hash, ssn) VALUES
    ('user@example.com', crypt('password', gen_salt('bf')), 
     pgp_sym_encrypt('123-45-6789', 'encryption_key'));

-- Decrypt on select
SELECT email, pgp_sym_decrypt(ssn, 'encryption_key') as ssn FROM users;
```

### Sensitive Data Exclusion from Logs

**Don't log**:
- Passwords/API keys
- Credit card numbers
- Social security numbers
- Personal health information
- Authentication tokens

```go
// Bad ❌
log.Printf("User logged in with password: %s", password)

// Good ✅
log.Printf("User logged in successfully")

// Bad ❌
log.Printf("Processing payment: %+v", creditCard)  // Dumps all fields

// Good ✅
log.Printf("Processing payment for user: %s, last4: %s", 
    userID, 
    creditCard.Number[len(creditCard.Number)-4:])
```

## Network Security

### Firewall Rules

```yaml
# Kubernetes NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
    name: frontend-policy
    namespace: production
spec:
    podSelector:
        matchLabels:
            app: frontend
    policyTypes:
    - Ingress
    - Egress
    ingress:
    - from:
      - podSelector:
          matchLabels:
            app: nginx-ingress
      ports:
      - protocol: TCP
        port: 8080
    egress:
    - to:
      - podSelector:
          matchLabels:
            app: productcatalog
      ports:
      - protocol: TCP
        port: 3550
    - to:
      - podSelector:
          matchLabels:
            app: cart
      ports:
      - protocol: TCP
        port: 7070
    # Allow DNS
    - to:
      - namespaceSelector: {}
      ports:
      - protocol: UDP
        port: 53
```

### CORS (Cross-Origin Resource Sharing)

```go
// Configure CORS appropriately
func corsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Only allow specific origins
        allowedOrigins := map[string]bool{
            "https://example.com": true,
            "https://app.example.com": true,
        }
        
        origin := r.Header.Get("Origin")
        if allowedOrigins[origin] {
            w.Header().Set("Access-Control-Allow-Origin", origin)
            w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE")
            w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
            w.Header().Set("Access-Control-Max-Age", "3600")
        }
        
        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }
        
        next.ServeHTTP(w, r)
    })
}
```

## Dependency Management

### Vulnerability Scanning

```bash
# Go
go list -json -m all | nancy sleuth

# Python
pip install safety
safety check

# Node.js
npm audit
npm audit fix  # Auto-fix

# Docker images
trivy image frontend:latest
```

### Lock Files

Always commit lock files for reproducible builds:

```bash
# Go
go.mod
go.sum

# Python
requirements.txt  # (from pip freeze)
pip.lock          # (or poetry.lock, pipenv.lock)

# Node.js
package-lock.json
```

### Update Policy

- **Security patches**: Apply immediately
- **Minor updates**: Apply within 1 week
- **Major updates**: Plan release before applying

```bash
# Check for updates
npm outdated
go list -u -m all
pip list --outdated

# Update common libraries
npm update              # Within allowed versions
go get -u ./...        # Update all deps
pip install --upgrade package-name
```

## Code Security

### Input Validation

```go
// NEVER trust user input
func handleCreateProduct(w http.ResponseWriter, r *http.Request) {
    // Decode request
    var req CreateProductRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "invalid request", http.StatusBadRequest)
        return
    }
    
    // Validate fields
    if req.Name == "" {
        http.Error(w, "product name required", http.StatusBadRequest)
        return
    }
    
    // Validate length
    if len(req.Name) > 255 {
        http.Error(w, "product name too long", http.StatusBadRequest)
        return
    }
    
    // Validate format
    if req.Price < 0 {
        http.Error(w, "price must be non-negative", http.StatusBadRequest)
        return
    }
    
    // Sanitize input for database
    req.Description = sanitizeHTML(req.Description)
    
    // Process
    product := s.createProduct(req)
}

func sanitizeHTML(input string) string {
    // Remove potentially dangerous HTML
    p := bluemonday.StrictPolicy()
    return p.Sanitize(input)
}
```

### SQL Injection Prevention

```go
// WRONG - vulnerable to SQL injection ❌
query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email)
db.Query(query)

// CORRECT - use parameterized queries ✅
query := "SELECT * FROM users WHERE email = $1"
db.QueryRow(query, email)

// gRPC - safer by default (uses binary protocol)
productReq := &pb.GetProductRequest{ProductId: productID}
```

## API Security

### Rate Limiting

```go
import "golang.org/x/time/rate"

// Per-IP rate limiting
var limiters = make(map[string]*rate.Limiter)

func rateLimitMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        ip := getClientIP(r)
        
        if limiter, exists := limiters[ip]; exists {
            if !limiter.Allow() {
                http.Error(w, "rate limited", http.StatusTooManyRequests)
                return
            }
        } else {
            // 10 requests per second
            limiter := rate.NewLimiter(10, 100)
            limiters[ip] = limiter
            if !limiter.Allow() {
                http.Error(w, "rate limited", http.StatusTooManyRequests)
                return
            }
        }
        
        next.ServeHTTP(w, r)
    })
}
```

### Request Signing

Verify request integrity with HMAC:

```go
// Client: Sign request
func signRequest(body []byte, secret string) string {
    h := hmac.New(sha256.New, []byte(secret))
    h.Write(body)
    return hex.EncodeToString(h.Sum(nil))
}

// Server: Verify signature
func verifySignature(body []byte, signature, secret string) bool {
    expected := signRequest(body, secret)
    return hmac.Equal([]byte(signature), []byte(expected))
}
```

## Incident Response

### Security Incident Checklist

1. **Immediate Response**
   - [ ] Identify the breach
   - [ ] Stop ongoing attack/access
   - [ ] Document timeline
   - [ ] Notify security team

2. **Investigation**
   - [ ] Determine scope (what was accessed)
   - [ ] Analyze logs and traces
   - [ ] Identify affected systems/users
   - [ ] Preserve evidence

3. **Containment**
   - [ ] Disable compromised accounts
   - [ ] Rotate credentials
   - [ ] Patch vulnerabilities
   - [ ] Update firewall rules

4. **Recovery**
   - [ ] Restore from clean backups
   - [ ] Verify system integrity
   - [ ] Restart services
   - [ ] Monitor for repeat incidents

5. **Communication**
   - [ ] Notify affected users
   - [ ] Update status page
   - [ ] Document lessons learned
   - [ ] Update security policies

### Security Scanning Tools

```bash
# Code scanning
- SonarQube (code quality)
- Checkmarx (SAST)
- Veracode (SAST)

# Dependency scanning
- Snyk (dependencies)
- OWASP Dependency-Check

# Container scanning
- Trivy (images)
- Anchore (images)
- Grype (vulnerabilities)

# Penetration testing
- OWASP ZAP (web apps)
- Burp Suite (web apps)
```

---

**Last Updated**: March 2026  
**Report Security Issues**: Do NOT open public issues. Contact security@example.com
