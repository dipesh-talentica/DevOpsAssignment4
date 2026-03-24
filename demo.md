# Secure API Platform Demo Guide

This document provides step-by-step instructions to demonstrate the Secure API Platform to the customer. It covers the core requirements from the PRD: API Gateway routing, Custom Lua plugins, JWT Authentication, Rate Limiting, IP Whitelisting, and DDoS Protection via CrowdSec.

---

## 🚀 Pro Tip: 1-Click Automated Demo
For a seamless experience, you can run the automated script which performs steps 1-4 automatically:
```bash
chmod +x demo.sh
./demo.sh
```
*(If you prefer to run it manually step-by-step, follow the instructions below!)*

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
- **`X-Kong-Intercepted: true`**: Point this out! This proves the custom Lua plugin (`handler.lua`) is actively intercepting and modifying the response at the gateway level.
- Kong's declarative config (`kong.yaml`) separates `/health`, `/login`, `/verify` as `public-routes` — no JWT plugin attached.

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
- The `/users` route is defined under `protected-routes` in `kong.yaml` with the JWT plugin applied locally.

### Step 2b: Authenticate and get a JWT
**Command:**
```bash
curl -s -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}'
```
**What to highlight:**
- The backend successfully verified the credentials against hashed passwords (bcrypt) in the local **SQLite database** and returned a signed JWT.
- The JWT uses `iss` claim set to the username, which Kong uses for consumer matching via `jwt_secrets`.

### Step 2c: Access the protected route with the JWT
**Command:**
```bash
# Export the token to a variable for ease of use
export TOKEN=$(curl -s -X POST http://localhost:8000/login -H "Content-Type: application/json" -d '{"username":"admin","password":"password123"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)

# Make the authenticated request
curl -i http://localhost:8000/users -H "Authorization: Bearer $TOKEN"
```
**What to highlight:**
- **`HTTP/1.1 200 OK`**: Kong successfully validated the JWT signature using the shared secret configured in `jwt_secrets` and routed the request to the backend.
- **`X-Kong-Intercepted: true`**: The custom Lua plugin still runs on protected routes too.
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
- Requests 11 and 12 will return **`429`** (Too Many Requests).
- This is a global plugin in `kong.yaml` — Kong tracks this per IP natively with `policy: local`.

---

## 4. DDoS Protection via CrowdSec
**Goal:** Demonstrate that CrowdSec is deployed alongside Kong and can ban malicious IPs.

*Explain to the customer: "CrowdSec is an open-source IPS deployed in our cluster. It parses Kong logs to detect anomalies and the Kong Bouncer blocks flagged IPs at the gateway layer."*

### Step 4a: Simulate an IP ban
**Command:**
```bash
# Add a simulated ban for a malicious IP
kubectl exec -it deploy/crowdsec-lapi -- cscli decisions add --ip 192.168.1.100 --duration 1h --reason "Simulated DDoS Attack"
```

### Step 4b: Verify the ban is active
**Command:**
```bash
kubectl exec -it deploy/crowdsec-lapi -- cscli decisions list
```

**What to highlight:**
- The decision list shows `192.168.1.100` is banned for 1 hour with reason "Simulated DDoS Attack".
- In a real scenario, CrowdSec's log analyzers would automatically detect brute-force or scanning patterns from Kong logs and add bans without manual intervention.
- The Kong Bouncer checks every incoming request's IP against CrowdSec's Local API (LAPI) and blocks flagged IPs immediately (403 Forbidden or connection drop).

---

## 5. IP Whitelisting
**Goal:** Show how Kong restricts access based on CIDR blocks.

*Explain to the customer: "Currently, our declarative config (`kong.yaml`) allows `0.0.0.0/0` so we could run the previous tests. I will now change it to block my local IP to prove the firewall works."*

### Step 5a: Update the config
1. Open `kong/kong.yaml` in your editor.
2. Under `ip-restriction`, change `0.0.0.0/0` to a dummy CIDR like `192.168.1.1/32`.

### Step 5b: Apply the updated config to the cluster
**Command:**
```bash
# Update the ConfigMap with the new kong.yaml
kubectl create configmap kong-declarative-config --from-file=kong.yml=kong/kong.yaml -o yaml --dry-run=client | kubectl apply -f -

# Restart the Kong pod to pick up the new configuration
kubectl delete pod -l app.kubernetes.io/name=kong
```

*Wait a few seconds for the pod to restart, then re-establish port forwarding:*
```bash
kubectl port-forward svc/kong-kong-proxy 8000:80
```

### Step 5c: Test the restriction
**Command:**
```bash
curl -i http://localhost:8000/health
```

**What to highlight:**
- **`HTTP/1.1 403 Forbidden`**: Kong immediately drops the traffic at the gateway layer because our IP is not in the allowed CIDR.
- This is a global plugin — every route is protected.

### Step 5d: Revert the config (cleanup)
Change `192.168.1.1/32` back to `0.0.0.0/0` in `kong/kong.yaml` and re-apply:
```bash
kubectl create configmap kong-declarative-config --from-file=kong.yml=kong/kong.yaml -o yaml --dry-run=client | kubectl apply -f -
kubectl delete pod -l app.kubernetes.io/name=kong
```

---

## Summary
| Feature | Route | Expected Result |
|---|---|---|
| Public Access + Lua Plugin | `GET /health` | `200 OK` + `X-Kong-Intercepted: true` |
| JWT Rejection | `GET /users` (no token) | `401 Unauthorized` |
| JWT Success | `GET /users` (with token) | `200 OK` |
| Rate Limiting | 12× `GET /health` | First 10 → `200`, last 2 → `429` |
| DDoS Protection | CrowdSec decision list | Banned IP visible in LAPI |
| IP Whitelisting | `GET /health` (blocked CIDR) | `403 Forbidden` |

*Wrap up the demo by discussing the architecture diagrams and the CrowdSec DDoS protection strategy outlined in the README.*
