#!/bin/bash

# Automated Cloud Setup Script for ODBC Cloud SQL POC
# This script automates the complete setup process on Google Cloud

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo ""
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user confirmation
confirm_continue() {
    read -p "$(echo -e ${YELLOW}Press Enter to continue or Ctrl+C to abort...${NC})"
}

# Banner
clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║   ODBC Cloud SQL POC - Automated Setup           ║
║   Google Cloud Platform Deployment                ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
print_step "Step 0: Checking Prerequisites"

if ! command_exists gcloud; then
    print_error "gcloud CLI is not installed"
    echo "Please install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi
print_success "gcloud CLI is installed"

if ! command_exists jq; then
    print_warning "jq is not installed (optional, but recommended for JSON parsing)"
    echo "Install with: sudo apt-get install jq  (or brew install jq on Mac)"
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" > /dev/null 2>&1; then
    print_error "Not authenticated with gcloud"
    echo "Please run: gcloud auth login"
    exit 1
fi
print_success "Authenticated with gcloud"

echo ""
print_info "All prerequisites met!"
echo ""

# ============================================================================
# CONFIGURATION
# ============================================================================

print_step "Step 1: Configuration"

# Project ID
echo "Enter your desired Google Cloud Project ID:"
echo "(Must be unique across all of Google Cloud, 6-30 characters, lowercase, numbers, hyphens)"
read -p "Project ID [odbc-poc-$(date +%s)]: " PROJECT_ID
PROJECT_ID=${PROJECT_ID:-odbc-poc-$(date +%s)}

# Region
echo ""
echo "Select a region for your resources:"
echo "1) us-central1 (Iowa)"
echo "2) us-east1 (South Carolina)"
echo "3) us-west1 (Oregon)"
echo "4) europe-west1 (Belgium)"
echo "5) asia-east1 (Taiwan)"
read -p "Enter number [1]: " REGION_CHOICE
REGION_CHOICE=${REGION_CHOICE:-1}

case $REGION_CHOICE in
    1) REGION="us-central1" ;;
    2) REGION="us-east1" ;;
    3) REGION="us-west1" ;;
    4) REGION="europe-west1" ;;
    5) REGION="asia-east1" ;;
    *) REGION="us-central1" ;;
esac

# Database password
echo ""
echo "Enter a strong password for the database root user:"
read -s -p "Database Password: " DB_ROOT_PASSWORD
echo ""
read -s -p "Confirm Password: " DB_ROOT_PASSWORD_CONFIRM
echo ""

if [ "$DB_ROOT_PASSWORD" != "$DB_ROOT_PASSWORD_CONFIRM" ]; then
    print_error "Passwords do not match"
    exit 1
fi

if [ ${#DB_ROOT_PASSWORD} -lt 8 ]; then
    print_error "Password must be at least 8 characters"
    exit 1
fi

# Application user password
echo ""
echo "Enter a strong password for the database application user (odbcuser):"
read -s -p "Application User Password: " DB_APP_PASSWORD
echo ""
read -s -p "Confirm Password: " DB_APP_PASSWORD_CONFIRM
echo ""

if [ "$DB_APP_PASSWORD" != "$DB_APP_PASSWORD_CONFIRM" ]; then
    print_error "Passwords do not match"
    exit 1
fi

# Database configuration
DB_NAME="odbc_poc_db"
DB_USER="odbcuser"
INSTANCE_NAME="odbc-poc-instance"
SERVICE_NAME="odbc-cloudsql-poc"

# Instance tier
echo ""
echo "Select Cloud SQL instance tier:"
echo "1) db-f1-micro (Shared CPU, 0.6GB RAM) - ~$7/month - Good for testing"
echo "2) db-g1-small (Shared CPU, 1.7GB RAM) - ~$25/month"
echo "3) db-n1-standard-1 (1 CPU, 3.75GB RAM) - ~$50/month - Production-ready"
read -p "Enter number [1]: " TIER_CHOICE
TIER_CHOICE=${TIER_CHOICE:-1}

case $TIER_CHOICE in
    1) TIER="db-f1-micro" ;;
    2) TIER="db-g1-small" ;;
    3) TIER="db-n1-standard-1" ;;
    *) TIER="db-f1-micro" ;;
esac

# Summary
echo ""
print_step "Configuration Summary"
echo "Project ID:        $PROJECT_ID"
echo "Region:            $REGION"
echo "SQL Instance:      $INSTANCE_NAME"
echo "Instance Tier:     $TIER"
echo "Database Name:     $DB_NAME"
echo "Database User:     $DB_USER"
echo "Service Name:      $SERVICE_NAME"
echo ""
print_warning "Estimated monthly cost: \$10-50 depending on tier and usage"
echo ""
confirm_continue

# ============================================================================
# PROJECT CREATION
# ============================================================================

print_step "Step 2: Creating Google Cloud Project"

# Check if project already exists
if gcloud projects describe "$PROJECT_ID" > /dev/null 2>&1; then
    print_warning "Project $PROJECT_ID already exists"
    read -p "Use existing project? (y/n): " USE_EXISTING
    if [ "$USE_EXISTING" != "y" ]; then
        print_error "Please choose a different project ID"
        exit 1
    fi
else
    print_info "Creating project: $PROJECT_ID"
    gcloud projects create "$PROJECT_ID" --name="ODBC Cloud SQL POC"
    print_success "Project created"
fi

# Set active project
gcloud config set project "$PROJECT_ID"
print_success "Set active project to $PROJECT_ID"

# Link billing account
echo ""
print_info "Available billing accounts:"
gcloud billing accounts list

echo ""
BILLING_ACCOUNTS=($(gcloud billing accounts list --format="value(name)" --filter="open=true"))

if [ ${#BILLING_ACCOUNTS[@]} -eq 0 ]; then
    print_error "No active billing accounts found"
    echo "Please set up billing at: https://console.cloud.google.com/billing"
    exit 1
elif [ ${#BILLING_ACCOUNTS[@]} -eq 1 ]; then
    BILLING_ACCOUNT="${BILLING_ACCOUNTS[0]}"
    print_info "Using billing account: $BILLING_ACCOUNT"
else
    echo "Multiple billing accounts found. Enter the billing account ID to use:"
    read -p "Billing Account ID: " BILLING_ACCOUNT
fi

# Check if billing is already linked
CURRENT_BILLING=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingAccountName)" 2>/dev/null || echo "")

if [ -z "$CURRENT_BILLING" ]; then
    print_info "Linking billing account..."
    gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
    print_success "Billing account linked"
else
    print_success "Billing already configured"
fi

echo ""
confirm_continue

# ============================================================================
# ENABLE APIS
# ============================================================================

print_step "Step 3: Enabling Required APIs"

APIS=(
    "sqladmin.googleapis.com"
    "run.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    "compute.googleapis.com"
)

for API in "${APIS[@]}"; do
    print_info "Enabling $API..."
    gcloud services enable "$API" --project="$PROJECT_ID"
done

print_success "All APIs enabled"
echo ""
confirm_continue

# ============================================================================
# CREATE CLOUD SQL INSTANCE
# ============================================================================

print_step "Step 4: Creating Cloud SQL Instance"
print_warning "This will take 5-10 minutes..."

# Check if instance exists
if gcloud sql instances describe "$INSTANCE_NAME" --project="$PROJECT_ID" > /dev/null 2>&1; then
    print_warning "Instance $INSTANCE_NAME already exists"
    read -p "Use existing instance? (y/n): " USE_EXISTING_INSTANCE
    if [ "$USE_EXISTING_INSTANCE" != "y" ]; then
        print_error "Please delete the existing instance or choose a different name"
        exit 1
    fi
    print_info "Using existing instance"
else
    print_info "Creating Cloud SQL MySQL instance: $INSTANCE_NAME"

    gcloud sql instances create "$INSTANCE_NAME" \
        --database-version=MYSQL_8_0 \
        --tier="$TIER" \
        --region="$REGION" \
        --root-password="$DB_ROOT_PASSWORD" \
        --backup-start-time=03:00 \
        --enable-bin-log \
        --storage-type=SSD \
        --storage-size=10GB \
        --availability-type=zonal \
        --project="$PROJECT_ID"

    print_success "Cloud SQL instance created"
fi

# Get instance IP
print_info "Retrieving instance IP address..."
DB_HOST=$(gcloud sql instances describe "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --format="value(ipAddresses[0].ipAddress)")

print_success "Database IP: $DB_HOST"

# Configure authorized networks (allow all for POC - update for production)
print_info "Configuring network access..."
print_warning "Allowing all IPs (0.0.0.0/0) - OK for POC, use Private IP for production"

gcloud sql instances patch "$INSTANCE_NAME" \
    --authorized-networks=0.0.0.0/0 \
    --project="$PROJECT_ID" \
    --quiet

print_success "Network access configured"
echo ""
confirm_continue

# ============================================================================
# CREATE DATABASE USER
# ============================================================================

print_step "Step 5: Creating Database User"

# Check if user exists
if gcloud sql users list --instance="$INSTANCE_NAME" --project="$PROJECT_ID" | grep -q "$DB_USER"; then
    print_warning "User $DB_USER already exists"
    print_info "Updating password..."
    gcloud sql users set-password "$DB_USER" \
        --instance="$INSTANCE_NAME" \
        --password="$DB_APP_PASSWORD" \
        --project="$PROJECT_ID"
else
    print_info "Creating database user: $DB_USER"
    gcloud sql users create "$DB_USER" \
        --instance="$INSTANCE_NAME" \
        --password="$DB_APP_PASSWORD" \
        --project="$PROJECT_ID"
fi

print_success "Database user configured"
echo ""
confirm_continue

# ============================================================================
# INITIALIZE DATABASE
# ============================================================================

print_step "Step 6: Initializing Database"

print_info "Connecting to Cloud SQL to create database and table..."
print_warning "This requires the mysql client. If not installed, you can skip and do this manually."

if command_exists mysql; then
    print_info "MySQL client found, proceeding with database initialization..."

    # Create a temporary SQL file with the initialization commands
    cat > /tmp/init_db.sql << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE $DB_NAME;

DROP TABLE IF EXISTS databricks;

CREATE TABLE databricks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    value VARCHAR(255),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO databricks (name, value, description) VALUES
    ('sample_record_1', 'test_value_1', 'This is a test record for ODBC connectivity verification'),
    ('sample_record_2', 'test_value_2', 'Second test record to ensure multiple rows work'),
    ('sample_record_3', 'test_value_3', 'Third test record for comprehensive testing');

GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;

SELECT COUNT(*) as record_count FROM databricks;
EOF

    # Execute using gcloud sql connect
    print_info "Executing database initialization script..."
    gcloud sql connect "$INSTANCE_NAME" --user=root --quiet --project="$PROJECT_ID" < /tmp/init_db.sql

    rm /tmp/init_db.sql
    print_success "Database initialized successfully"
else
    print_warning "MySQL client not found. You'll need to initialize the database manually."
    echo ""
    echo "Run these commands:"
    echo "  gcloud sql connect $INSTANCE_NAME --user=root --project=$PROJECT_ID"
    echo ""
    echo "Then copy and paste the SQL from init_database.sql"
    echo ""
    read -p "Have you initialized the database? (y/n): " DB_INITIALIZED
    if [ "$DB_INITIALIZED" != "y" ]; then
        print_error "Please initialize the database before continuing"
        exit 1
    fi
fi

echo ""
confirm_continue

# ============================================================================
# DEPLOY TO CLOUD RUN
# ============================================================================

print_step "Step 7: Building and Deploying to Cloud Run"
print_warning "This will take 3-5 minutes..."

print_info "Building container image..."
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

gcloud builds submit --tag "$IMAGE_NAME" --project="$PROJECT_ID"

print_success "Container image built"

print_info "Deploying to Cloud Run..."

gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE_NAME" \
    --platform managed \
    --region "$REGION" \
    --allow-unauthenticated \
    --set-env-vars "DB_HOST=$DB_HOST,DB_PORT=3306,DB_NAME=$DB_NAME,DB_USER=$DB_USER,DB_PASSWORD=$DB_APP_PASSWORD" \
    --memory 512Mi \
    --cpu 1 \
    --timeout 300 \
    --max-instances 10 \
    --project "$PROJECT_ID"

print_success "Deployment complete!"

# Get service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --platform managed \
    --region "$REGION" \
    --project "$PROJECT_ID" \
    --format='value(status.url)')

# ============================================================================
# TESTING
# ============================================================================

print_step "Step 8: Testing Deployment"

echo ""
print_info "Service URL: $SERVICE_URL"
echo ""

print_info "Testing health endpoint..."
sleep 3  # Give service a moment to be fully ready
HEALTH_RESPONSE=$(curl -s "$SERVICE_URL/health")
echo "$HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q "success"; then
    print_success "Health check passed"
else
    print_error "Health check failed"
fi

echo ""
print_info "Testing ODBC connection..."
CONNECTION_RESPONSE=$(curl -s "$SERVICE_URL/test-connection")
echo "$CONNECTION_RESPONSE"

if echo "$CONNECTION_RESPONSE" | grep -q "success"; then
    print_success "Connection test passed"
else
    print_error "Connection test failed"
fi

echo ""
print_info "Testing database query..."
QUERY_RESPONSE=$(curl -s "$SERVICE_URL/get-record")
echo "$QUERY_RESPONSE"

if echo "$QUERY_RESPONSE" | grep -q "sample_record"; then
    print_success "Database query test passed"
else
    print_error "Database query test failed"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
print_step "Setup Complete! 🎉"

cat << EOF

${GREEN}╔═══════════════════════════════════════════════════════════════╗
║                   DEPLOYMENT SUCCESSFUL                       ║
╚═══════════════════════════════════════════════════════════════╝${NC}

${BLUE}Service Information:${NC}
  Service URL:       $SERVICE_URL
  Project ID:        $PROJECT_ID
  Region:            $REGION
  SQL Instance:      $INSTANCE_NAME
  Database:          $DB_NAME

${BLUE}Test Endpoints:${NC}
  Health Check:      $SERVICE_URL/health
  Connection Test:   $SERVICE_URL/test-connection
  Get Record:        $SERVICE_URL/get-record
  List Drivers:      $SERVICE_URL/available-drivers

${BLUE}Quick Test Commands:${NC}
  curl $SERVICE_URL/health
  curl $SERVICE_URL/test-connection
  curl $SERVICE_URL/get-record

${BLUE}View Logs:${NC}
  gcloud run services logs read $SERVICE_NAME --project=$PROJECT_ID --limit=50

${BLUE}Cloud Console Links:${NC}
  Cloud Run:    https://console.cloud.google.com/run?project=$PROJECT_ID
  Cloud SQL:    https://console.cloud.google.com/sql/instances?project=$PROJECT_ID
  Logs:         https://console.cloud.google.com/logs?project=$PROJECT_ID

${YELLOW}Important Notes:${NC}
  • Your service is publicly accessible (no authentication)
  • Database is accessible from all IPs (0.0.0.0/0)
  • For production, implement:
    - Cloud Run authentication
    - Private IP for Cloud SQL
    - Secret Manager for credentials
    - More restrictive network policies

${YELLOW}Estimated Monthly Cost: \$10-50${NC}
  Cloud SQL ($TIER): ~\$7-50/month
  Cloud Run (minimal traffic): ~\$0-5/month

${RED}To Clean Up (Delete Everything):${NC}
  gcloud run services delete $SERVICE_NAME --region=$REGION --project=$PROJECT_ID
  gcloud sql instances delete $INSTANCE_NAME --project=$PROJECT_ID
  gcloud projects delete $PROJECT_ID

${GREEN}Configuration saved to: .env.deployed${NC}

EOF

# Save configuration for reference
cat > .env.deployed << EOF
# Deployment Configuration - $(date)
PROJECT_ID=$PROJECT_ID
REGION=$REGION
INSTANCE_NAME=$INSTANCE_NAME
DB_HOST=$DB_HOST
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_APP_PASSWORD
SERVICE_NAME=$SERVICE_NAME
SERVICE_URL=$SERVICE_URL
EOF

print_success "Setup script completed successfully!"
echo ""
