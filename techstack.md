# Tech Stack Documentation

This document outlines the technologies, frameworks, and tools used to build the Secure API Platform.

## 1. Backend Microservice
* **Language:** Python 3.9
* **Framework:** FastAPI - Chosen for its high performance, ease of use, and native asynchronous support.
* **Server:** Uvicorn - ASGI web server implementation for Python.
* **Database:** SQLite - A lightweight, file-based database used locally to store user credentials.

## 2. API Gateway & Traffic Management
* **API Gateway:** Kong API Gateway (OSS) - Deployed in DB-less mode using a declarative configuration for routing and policy enforcement.
* **Custom Logic:** Lua - Used to develop custom Kong plugins (e.g., custom request/response header injection).

## 3. Security & Authentication
* **Authentication:** JWT (JSON Web Tokens) - Generated via `PyJWT` in the backend and validated at the edge using the Kong JWT plugin.
* **Password Hashing:** `bcrypt` (via `passlib`) - Used for securely hashing user passwords before storing them in the database.
* **DDoS Protection:** CrowdSec - An open-source, collaborative IPS that parses Kong logs to detect and block malicious IP behaviors dynamically.

## 4. Containerization & Orchestration
* **Containerization:** Docker - Used to package the FastAPI application into a lightweight, deployable image.
* **Orchestration:** Kubernetes - The core platform hosting the Kong API Gateway, CrowdSec bouncers, and the backend microservices.

## 5. Infrastructure as Code (IaC)
* **Deployment:** Helm - Used for the declarative deployment of the microservice, Kong configurations, and Kubernetes resources using parameterized charts.
* **Infrastructure Provisioning:** Terraform - Utilized for base Kubernetes cluster provisioning, networking, and namespace configurations.