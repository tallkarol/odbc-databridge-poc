#!/bin/bash

# Cloud Run Deployment Script for ODBC Cloud SQL POC
# This script builds and deploys the application to Google Cloud Run

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
PROJECT_ID="${GOOGLE_CLOUD_PROJECT}"
SERVICE_NAME="odbc-cloudsql-poc"
REGION="${REGION:-us-central1}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Database connection details (set these as environment variables or pass as arguments)
DB_HOST="${DB_HOST}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-odbc_poc_db}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"

echo -e "${GREEN}=== ODBC Cloud SQL POC Deployment ===${NC}"
echo ""

# Validate required variables
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: GOOGLE_CLOUD_PROJECT environment variable is not set${NC}"
    echo "Run: export GOOGLE_CLOUD_PROJECT=your-project-id"
    exit 1
fi

if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: Database connection variables are not set${NC}"
    echo "Required variables: DB_HOST, DB_USER, DB_PASSWORD"
    exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Service Name: $SERVICE_NAME"
echo "  Region: $REGION"
echo "  Image: $IMAGE_NAME"
echo "  DB Host: $DB_HOST"
echo "  DB Name: $DB_NAME"
echo ""

# Step 1: Build the container image
echo -e "${GREEN}Step 1: Building container image...${NC}"
gcloud builds submit --tag "$IMAGE_NAME" --project "$PROJECT_ID"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build container image${NC}"
    exit 1
fi

echo -e "${GREEN}Container image built successfully${NC}"
echo ""

# Step 2: Deploy to Cloud Run
echo -e "${GREEN}Step 2: Deploying to Cloud Run...${NC}"
gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE_NAME" \
    --platform managed \
    --region "$REGION" \
    --allow-unauthenticated \
    --set-env-vars "DB_HOST=${DB_HOST},DB_PORT=${DB_PORT},DB_NAME=${DB_NAME},DB_USER=${DB_USER},DB_PASSWORD=${DB_PASSWORD}" \
    --memory 512Mi \
    --cpu 1 \
    --timeout 300 \
    --max-instances 10 \
    --project "$PROJECT_ID"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to deploy to Cloud Run${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== Deployment Successful ===${NC}"

# Get the service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --platform managed \
    --region "$REGION" \
    --project "$PROJECT_ID" \
    --format 'value(status.url)')

echo ""
echo -e "${GREEN}Service is live at: ${SERVICE_URL}${NC}"
echo ""
echo "Test the endpoints:"
echo "  Health Check:       ${SERVICE_URL}/health"
echo "  Connection Test:    ${SERVICE_URL}/test-connection"
echo "  Get Record:         ${SERVICE_URL}/get-record"
echo "  Available Drivers:  ${SERVICE_URL}/available-drivers"
echo ""
