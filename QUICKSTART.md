# Quick Start Guide

Get your ODBC Cloud SQL POC running in under 30 minutes.

## Prerequisites Checklist

- [ ] Google Cloud account with billing enabled
- [ ] `gcloud` CLI installed ([Install Guide](https://cloud.google.com/sdk/docs/install))
- [ ] Logged into gcloud: `gcloud auth login`

## 5-Step Setup

### Step 1: Set Up Google Cloud Project (5 min)

```bash
# Set variables (customize these)
export PROJECT_ID="my-odbc-poc-$(date +%s)"
export DB_PASSWORD="ChangeMe123!"
export REGION="us-central1"

# Create and configure project
gcloud projects create $PROJECT_ID
gcloud config set project $PROJECT_ID

# Enable billing (you'll need your billing account ID)
gcloud billing accounts list
export BILLING_ACCOUNT="YOUR-BILLING-ACCOUNT-ID"
gcloud billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT

# Enable required APIs
gcloud services enable sqladmin.googleapis.com run.googleapis.com \
  cloudbuild.googleapis.com artifactregistry.googleapis.com
```

### Step 2: Create Cloud SQL Instance (10 min)

```bash
# Create instance (takes ~7 minutes)
gcloud sql instances create odbc-poc-instance \
    --database-version=MYSQL_8_0 \
    --tier=db-f1-micro \
    --region=$REGION \
    --root-password="$DB_PASSWORD" \
    --backup-start-time=03:00 \
    --enable-bin-log \
    --storage-type=SSD \
    --storage-size=10GB \
    --availability-type=zonal

# Get the instance IP
export DB_HOST=$(gcloud sql instances describe odbc-poc-instance \
    --format="value(ipAddresses[0].ipAddress)")

echo "Database IP: $DB_HOST"

# Allow connections (development only - replace with your IP for security)
gcloud sql instances patch odbc-poc-instance \
    --authorized-networks=0.0.0.0/0
```

**Security Note:** `0.0.0.0/0` allows all IPs. For production, use specific IPs or Private IP.

### Step 3: Set Up Database (5 min)

```bash
# Create application user
gcloud sql users create odbcuser \
    --instance=odbc-poc-instance \
    --password="$DB_PASSWORD"

# Connect and initialize database
gcloud sql connect odbc-poc-instance --user=root
```

In the MySQL prompt, paste:

```sql
CREATE DATABASE odbc_poc_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE odbc_poc_db;

CREATE TABLE databricks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    value VARCHAR(255),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT INTO databricks (name, value, description) VALUES
    ('sample_record_1', 'test_value_1', 'ODBC connectivity test record'),
    ('sample_record_2', 'test_value_2', 'Second test record'),
    ('sample_record_3', 'test_value_3', 'Third test record');

GRANT ALL PRIVILEGES ON odbc_poc_db.* TO 'odbcuser'@'%';
FLUSH PRIVILEGES;

SELECT * FROM databricks;
EXIT;
```

### Step 4: Deploy to Cloud Run (5 min)

```bash
# Set deployment variables
export GOOGLE_CLOUD_PROJECT=$PROJECT_ID
export DB_NAME="odbc_poc_db"
export DB_USER="odbcuser"
export DB_PORT="3306"

# Deploy (takes ~3-5 minutes)
./deploy.sh
```

### Step 5: Test Your Deployment (2 min)

```bash
# Get service URL
export SERVICE_URL=$(gcloud run services describe odbc-cloudsql-poc \
    --platform managed \
    --region $REGION \
    --format 'value(status.url)')

echo "Service URL: $SERVICE_URL"

# Test endpoints
echo "Testing health check..."
curl $SERVICE_URL/health | jq

echo "Testing ODBC connection..."
curl $SERVICE_URL/test-connection | jq

echo "Testing query execution..."
curl $SERVICE_URL/get-record | jq
```

## Success Indicators

You should see:

1. **Health Check**: `{"status": "success", ...}`
2. **Connection Test**: Driver info with MySQL ODBC 8.0
3. **Get Record**: Your sample data from the databricks table

## What You Just Built

```
Internet → Cloud Run (FastAPI) → ODBC → Cloud SQL (MySQL)
           └─ Container with MySQL ODBC drivers
```

## Quick Local Testing

Want to run locally first?

```bash
# Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Install ODBC drivers (Ubuntu/Debian)
sudo apt-get install -y unixodbc unixodbc-dev

# Set environment variables
export DB_HOST=$DB_HOST
export DB_NAME="odbc_poc_db"
export DB_USER="odbcuser"
export DB_PASSWORD="$DB_PASSWORD"

# Run locally
python main.py
```

Test at `http://localhost:8080`

## Troubleshooting

**"Cannot connect to Cloud SQL"**
```bash
# Verify instance is running
gcloud sql instances describe odbc-poc-instance | grep state

# Check authorized networks
gcloud sql instances describe odbc-poc-instance \
    --format="value(settings.ipConfiguration.authorizedNetworks)"
```

**"No ODBC drivers found"**
```bash
# Check drivers in deployed service
curl $SERVICE_URL/available-drivers
```

**"Build failed"**
```bash
# Check build logs
gcloud builds list --limit 5
gcloud builds log $(gcloud builds list --limit 1 --format="value(id)")
```

## Next Steps

- [ ] Review the full [README.md](README.md) for production security
- [ ] Customize the `databricks` table with your own schema
- [ ] Add authentication to your Cloud Run service
- [ ] Set up monitoring and alerting
- [ ] Migrate to Private IP for production

## Clean Up (Important!)

To avoid charges:

```bash
# Delete everything
gcloud run services delete odbc-cloudsql-poc --region $REGION --quiet
gcloud sql instances delete odbc-poc-instance --quiet

# Or delete entire project
gcloud projects delete $PROJECT_ID
```

## Cost Warning

Running this POC costs approximately $10-15/month. Remember to clean up when done testing!

## Get Help

- **Stuck?** Check [README.md](README.md) for detailed troubleshooting
- **Logs:** `gcloud run services logs read odbc-cloudsql-poc --limit 50`
- **Cloud SQL:** `gcloud sql operations list --instance=odbc-poc-instance`

---

**Estimated Time:** 25-30 minutes total
**Cost:** ~$0.50 for a few hours of testing
