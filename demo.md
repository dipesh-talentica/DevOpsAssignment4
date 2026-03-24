# Secure API Platform Demo Guide

This document provides step-by-step instructions to demonstrate the Secure API Platform to the customer. It covers the core requirements from the PRD: API Gateway routing, Custom Lua plugins, JWT Authentication, Rate Limiting, and IP Whitelisting.

---

## Pre-requisites
Ensure you are in the root directory of the project and your terminal is ready.

```bash
# Forward the Kong proxy port to your local machine (run in a separate terminal)
kubectl port-forward svc/kong-kong-proxy 8000:80
```
*Explain to the customer: "We are spinning up the FastAPI microservice and the Kong API Gateway. Kong is running in DB-less mode using a declarative configuration."*

---

## 1. Authentication Bypass & Custom Lua Plugin
**Goal:** Show that public endpoints can be accessed without a token, and demonstrate the custom Lua plugin injecting headers.

**Command:**
```bash
curl -i http://localhost:8000/health
```

**What to highlight in the output:**
- **`HTTP/1.1 200 OK`**: The request succeeded without authentication.
- **`X-Kong-Intercepted: true`**: Point this out! This proves the custom Lua plugin is actively intercepting and modifying the response at the gateway level.

---

## 2. JWT Authentication Flow
**Goal:** Prove that protected endpoints reject unauthorized traffic, and demonstrate the login flow to obtain and use a JWT.

### Step 2a: Attempt to access a protected route without a token
**Command:**
```bash
curl -i http://localhost:8000/users
```
**What to highlight:**
- **`HTTP/1.1 401 Unauthorized`**: Kong blocks the request at the edge. The traffic never even reaches the backend microservice.

### Step 2b: Authenticate and get a JWT
**Command:**
```bash
curl -s -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}'
```
**What to highlight:**
- The backend successfully verified the credentials against the local **SQLite database** and returned a signed JWT.

### Step 2c: Access the protected route with the JWT
**Command:**
```bash
# Export the token to a variable for ease of use
export TOKEN=$(curl -s -X POST http://localhost:8000/login -H "Content-Type: application/json" -d '{"username":"admin","password":"password123"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

# Make the authenticated request
curl -i http://localhost:8000/users -H "Authorization: Bearer $TOKEN"
```
**What to highlight:**
- **`HTTP/1.1 200 OK`**: Kong successfully validated the JWT signature and routed the request to the backend.
- `{"users":["admin"]}`: The backend responded correctly.

---

## 3. Rate Limiting
**Goal:** Demonstrate the IP-based rate-limiting policy (configured to 10 requests per minute).

**Command:**
```bash
# Run a loop to hit the API 12 times rapidly
for i in {1..12}; do curl -s -o /dev/null -w "Request $i: %{http_code}\n" http://localhost:8000/health; done
```

**What to highlight:**
- Requests 1 through 10 will return `200` (OK).
- Requests 11 and 12 will return `429` (Too Many Requests).
- Explain that Kong tracks this per IP natively.

---

## 4. IP Whitelisting
**Goal:** Show how Kong restricts access based on CIDR blocks.

*Explain to the customer: "Currently, our declarative config (`kong.yaml`) allows `0.0.0.0/0` so we could run the previous tests. I will now change it to block my local IP to prove the firewall works."*

**Action:**
1. Open `kong.yaml` in your editor.
2. Under `ip-restriction`, change `0.0.0.0/0` to a dummy CIDR like `192.168.1.1/32`.
3. Sync the config into the running Kong container:

**Command:**
```bash
# Update the ConfigMap with the new kong.yaml
kubectl create configmap kong-declarative-config --from-file=kong.yml=kong.yaml -o yaml --dry-run=client | kubectl apply -f -

# Restart the Kong pod to pick up the new configuration
kubectl delete pod -l app.kubernetes.io/name=kong
```

**Test the restriction:**
```bash
curl -i http://localhost:8000/health
```
**What to highlight:**
- **`HTTP/1.1 403 Forbidden`**: Kong immediately drops the traffic at the gateway layer.

---

## 5. Teardown
```bash
docker-compose down
```
*Wrap up the demo by discussing the architecture diagrams and the CrowdSec DDoS protection strategy outlined in the README.*