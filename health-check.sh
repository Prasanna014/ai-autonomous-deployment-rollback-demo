#!/bin/bash

##############################################################################
# Health Check Script - Verify application is running correctly
##############################################################################

APP_PORT=${APP_PORT:-8080}
MAX_RETRIES=${MAX_RETRIES:-5}
RETRY_INTERVAL=${RETRY_INTERVAL:-2}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Health Check Verification"
echo "=========================================="
echo "Target: http://localhost:${APP_PORT}"
echo ""

for attempt in $(seq 1 $MAX_RETRIES); do
    echo -n "Attempt ${attempt}/${MAX_RETRIES}: "
    
    if response=$(curl -s -w "\n%{http_code}" http://localhost:${APP_PORT}/health 2>/dev/null); then
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')
        
        if [ "$http_code" == "200" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            echo "Response:"
            echo "$body" | jq . 2>/dev/null || echo "$body"
            echo ""
            echo -e "${GREEN}Health check successful!${NC}"
            exit 0
        else
            echo -e "${YELLOW}HTTP ${http_code}${NC}"
        fi
    else
        echo -e "${RED}✗ FAIL${NC}"
    fi
    
    if [ $attempt -lt $MAX_RETRIES ]; then
        echo "Waiting ${RETRY_INTERVAL}s before retry..."
        sleep $RETRY_INTERVAL
    fi
done

echo ""
echo -e "${RED}Health check failed after ${MAX_RETRIES} attempts${NC}"
echo ""
echo "Troubleshooting:"
echo "1. Is the application running? Check: ps aux | grep 'python3 app.py'"
echo "2. Check logs: tail -50 application.log"
echo "3. Is port ${APP_PORT} in use? Check: lsof -i :${APP_PORT}"
exit 1
