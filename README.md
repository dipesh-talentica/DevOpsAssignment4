# DevOpsAssignment4
Secure API Platform using Kong on Kubernetes

## High-Level Architecture Overview
The platform leverages a microservices-based architecture orchestrated on Kubernetes. It exposes a single FastAPI user service through a self-managed Kong API Gateway operating in DB-less mode.
- **Client**: Initiates HTTP requests to the API gateway.
- **Kong API Gateway**: Acts as the single entry point, handling routing, rate limiting, IP whitelisting, and JWT validation.
- **User Service**: A containerized FastAPI Python application storing user data securely in a local SQLite database.

## API Request Flow (Client → Kong → Microservice)
1. A client sends an HTTP request to Kong.
2. Kong applies global plugins (e.g., IP Restriction, Rate Limiting).
3. If the request matches a protected route (e.g., `/users`), Kong triggers the JWT plugin to validate the token.
4. For bypassing routes (`/health`, `/login`, `/verify`), Kong skips JWT validation.
5. Kong's custom Lua plugin injects the `X-Kong-Intercepted` header.
6. The request is proxied to the downstream User Service.
7. The User Service processes the request (interacting with SQLite if needed) and returns a response.

## JWT Authentication Flow
1. **Login**: Client sends a POST request with credentials to `/login`.
2. **Token Generation**: The User Service validates credentials against hashed passwords in SQLite and generates a JWT signed with a secret (`my_secret_key`), embedding the username in the `iss` claim.
3. **Accessing Protected Endpoints**: Client sends a GET request to `/users` with the JWT in the `Authorization: Bearer <token>` header.
4. **Gateway Validation**: Kong intercepts the request, verifies the JWT signature using externally configured secrets (`jwt_secrets`), and permits or denies the request.

## Authentication Bypass Strategy
Kong's declarative configuration (`kong.yaml`) separates routing paths. 
- A specific route named `protected-routes` is created for `/users` with the JWT plugin applied locally to this route.
- A separate route `public-routes` manages `/health`, `/login`, and `/verify` without any authentication plugins attached.

## Testing Steps
### 1. Rate Limiting
- Run a loop to hit `/health` more than 10 times in a minute.
  ```bash
  for i in {1..12}; do curl -i http://<KONG_IP>:8000/health; done
  ```
- Expect the 11th request to return `HTTP 429 Too Many Requests`.

### 2. IP Whitelisting
- Modify the `ip-restriction` plugin block in `kong.yaml` to allow only a specific dummy CIDR (e.g., `192.168.1.1/32`).
- Apply the config and attempt to hit `/health` from your current IP.
- Expect an `HTTP 403 Forbidden` response.

### 3. DDoS Protection Testing (CrowdSec)
- Intentionally trigger CrowdSec by simulating an attack (e.g., using Nikto or rapidly scanning the gateway).
- Monitor CrowdSec alerts to see the IP being banned.
- Try accessing the API again; the connection should be dropped or blocked by the Kong Bouncer.

## DDoS Protection Mechanism: CrowdSec
**Chosen Solution**: CrowdSec (integrated with Kong)

**Reason for Choosing**: CrowdSec is an open-source, modern, and collaborative IPS. It is highly suitable for Kubernetes and lightweight compared to traditional WAFs like ModSecurity. By parsing Kong logs, it can identify and remediate malicious behaviors dynamically without heavy overhead.

**Integration with Kong and Kubernetes**:
1. Deploy the CrowdSec Helm chart into the Kubernetes cluster, configuring it to ingest logs from the Kong API Gateway pods.
2. Deploy the CrowdSec Kong Bouncer alongside Kong. The bouncer interacts with CrowdSec's Local API (LAPI) to check incoming IPs.
3. If an IP is flagged as malicious by CrowdSec, the Kong bouncer intercepts the request and blocks it immediately.

**Basic Protection Behavior**:
When an attacker performs a brute-force attack or port scan, CrowdSec's log analyzers detect the anomaly based on defined scenarios. The attacker's IP is added to the blocklist. Any subsequent requests from that IP reaching Kong are immediately rejected by the bouncer (usually returning a 403 Forbidden or dropping the connection), mitigating the DDoS attempt effectively.
