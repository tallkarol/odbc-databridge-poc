#!/bin/bash

# Test Deployment Script
# Tests all endpoints of the deployed ODBC Cloud SQL POC service

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_test() {
    echo -e "${BLUE}Testing: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ PASSED: $1${NC}"
}

print_error() {
    echo -e "${RED}✗ FAILED: $1${NC}"
}

print_response() {
    echo -e "${YELLOW}Response:${NC}"
    echo "$1" | jq '.' 2>/dev/null || echo "$1"
    echo ""
}

# Get service URL
if [ -f ".env.deployed" ]; then
    source .env.deployed
elif [ -n "$1" ]; then
    SERVICE_URL="$1"
else
    echo "Usage: $0 <SERVICE_URL>"
    echo "Or run after setup.sh to automatically use deployed URL"
    exit 1
fi

echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Testing ODBC Cloud SQL POC Deployment       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo "Service URL: $SERVICE_URL"
echo ""

# Test 1: Root endpoint
print_test "Root endpoint (/)"
RESPONSE=$(curl -s "$SERVICE_URL/")
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q "success"; then
    print_success "Root endpoint"
else
    print_error "Root endpoint"
fi

echo ""

# Test 2: Health check
print_test "Health check endpoint (/health)"
RESPONSE=$(curl -s "$SERVICE_URL/health")
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q '"status":"success"'; then
    print_success "Health check"
else
    print_error "Health check"
fi

echo ""

# Test 3: Available drivers
print_test "Available drivers endpoint (/available-drivers)"
RESPONSE=$(curl -s "$SERVICE_URL/available-drivers")
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q "MySQL"; then
    print_success "MySQL ODBC driver found"
else
    print_error "MySQL ODBC driver not found"
fi

echo ""

# Test 4: Connection test
print_test "ODBC connection test (/test-connection)"
RESPONSE=$(curl -s "$SERVICE_URL/test-connection")
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q '"status":"success"'; then
    print_success "ODBC connection test"

    # Extract driver info
    if echo "$RESPONSE" | grep -q "driver_name"; then
        echo -e "${GREEN}Driver Information:${NC}"
        echo "$RESPONSE" | jq '.driver_info' 2>/dev/null || echo "Could not parse driver info"
        echo ""
    fi
else
    print_error "ODBC connection test"
    echo -e "${RED}This indicates a problem connecting to Cloud SQL via ODBC${NC}"
fi

echo ""

# Test 5: Database query
print_test "Database query test (/get-record)"
RESPONSE=$(curl -s "$SERVICE_URL/get-record")
print_response "$RESPONSE"

if echo "$RESPONSE" | grep -q '"status":"success"'; then
    if echo "$RESPONSE" | grep -q "sample_record"; then
        print_success "Database query executed successfully"

        # Show the retrieved record
        echo -e "${GREEN}Retrieved Record:${NC}"
        echo "$RESPONSE" | jq '.record' 2>/dev/null || echo "Could not parse record"
        echo ""
    else
        print_error "No records found in database"
        echo -e "${YELLOW}Database might be empty. Check database initialization.${NC}"
    fi
else
    print_error "Database query"
    echo -e "${RED}This indicates a problem executing queries${NC}"
fi

echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Test Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""
echo "All endpoints tested. Review results above."
echo ""
echo "If any tests failed, check the logs:"
echo "  gcloud run services logs read $SERVICE_NAME --limit=50"
echo ""
echo "To test manually:"
echo "  curl $SERVICE_URL/health | jq"
echo "  curl $SERVICE_URL/test-connection | jq"
echo "  curl $SERVICE_URL/get-record | jq"
echo ""
