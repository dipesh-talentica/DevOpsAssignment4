#!/bin/bash

echo "======================================================"
echo " Secure API Platform Demo"
echo "======================================================"
echo ""

echo "▶ Starting Port Forwarding for Kong Gateway (Background)..."
kubectl port-forward svc/kong-kong-proxy 8000:80 > /dev/null 2>&1 &
PF_PID=$!
sleep 3
echo -e "Port forwarding established!\n"

echo "▶ 1. Testing Public Route (/health) - Bypasses Auth & Injects Custom Header"
echo "------------------------------------------------------"
curl -i http://localhost:8000/health
echo -e "\n\n"
sleep 3

echo "▶ 2a. Testing Protected Route (/users) WITHOUT Token - Should be blocked (401)"
echo "------------------------------------------------------"
curl -i http://localhost:8000/users
echo -e "\n\n"
sleep 3

echo "▶ 2b. Logging in to get JWT Token..."
echo "------------------------------------------------------"
TOKEN=$(curl -s -X POST http://localhost:8000/login -H "Content-Type: application/json" -d '{"username":"admin","password":"password123"}' | grep -o '"token":"[^"]*' | cut -d'"' -f4)
echo "Token successfully received: $TOKEN"
echo -e "\n"
sleep 2

echo "▶ 2c. Testing Protected Route (/users) WITH Token - Should succeed (200)"
echo "------------------------------------------------------"
curl -i http://localhost:8000/users -H "Authorization: Bearer $TOKEN"
echo -e "\n\n"
sleep 3

echo "▶ 3. Testing Rate Limiting (10 req/min) on /health"
echo "------------------------------------------------------"
echo "Sending 12 rapid requests. The last two should return 429 (Too Many Requests)..."
for i in {1..12}; do 
  curl -s -o /dev/null -w "Request $i: %{http_code}\n" http://localhost:8000/health
done
echo -e "\n\n"
sleep 3

echo "▶ 4. Testing DDoS Protection via CrowdSec"
echo "------------------------------------------------------"
echo "Adding a simulated IP ban for 192.168.1.100..."
kubectl exec -it deploy/crowdsec-lapi -- cscli decisions add --ip 192.168.1.100 --duration 1h --reason "Simulated DDoS Attack" > /dev/null
kubectl exec -it deploy/crowdsec-lapi -- cscli decisions list
echo -e "\n\n"

echo "▶ Cleaning up port-forwarding..."
kill $PF_PID > /dev/null 2>&1
echo "🎉 Demo Completed Successfully!"