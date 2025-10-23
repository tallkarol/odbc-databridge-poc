# ODBC Cloud SQL Proof of Concept

A complete proof of concept demonstrating ODBC connectivity to Google Cloud SQL MySQL from a web service deployed on Google Cloud Run.

## Overview

This project provides a minimal FastAPI web service that connects to a Google Cloud SQL MySQL instance using ODBC drivers. It includes three essential endpoints to verify ODBC connectivity:

- **Health Check**: Verify the service is running
- **Connection Test**: Test ODBC connectivity without executing queries
- **Single Record Retrieval**: Execute a simple query to prove ODBC queries work

## Project Structure

```
odbc-databridge-poc/
├── main.py                 # FastAPI web service with ODBC connectivity
├── requirements.txt        # Python dependencies
├── Dockerfile             # Container configuration with ODBC drivers
├── init_database.sql      # Database and table creation script
├── deploy.sh              # Cloud Run deployment script
├── .env.example           # Environment variables template
├── .gitignore            # Git ignore rules
└── README.md             # This file
```

## Prerequisites

- Google Cloud account with billing enabled
- `gcloud` CLI installed and configured
- Basic familiarity with Google Cloud Console
- MySQL client (optional, for database setup)

## Complete Setup Instructions

### Part 1: Google Cloud Project Setup

#### 1.1 Create a New Google Cloud Project

```bash
# Set your desired project ID
export PROJECT_ID="your-unique-project-id"

# Create the project
gcloud projects create $PROJECT_ID --name="ODBC Cloud SQL POC"

# Set as active project
gcloud config set project $PROJECT_ID

# Link billing account (replace BILLING_ACCOUNT_ID with your billing account ID)
# Find billing accounts: gcloud billing accounts list
gcloud billing projects link $PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

#### 1.2 Enable Required APIs

```bash
# Enable Cloud SQL Admin API
gcloud services enable sqladmin.googleapis.com

# Enable Cloud Run API
gcloud services enable run.googleapis.com

# Enable Cloud Build API (for container builds)
gcloud services enable cloudbuild.googleapis.com

# Enable Artifact Registry API
gcloud services enable artifactregistry.googleapis.com

# Verify APIs are enabled
gcloud services list --enabled
```

### Part 2: Cloud SQL Instance Setup

#### 2.1 Create Cloud SQL MySQL Instance

Choose your configuration (development or production-like):

**Development Configuration (lower cost):**
```bash
gcloud sql instances create odbc-poc-instance \
    --database-version=MYSQL_8_0 \
    --tier=db-f1-micro \
    --region=us-central1 \
    --root-password="CHOOSE_A_STRONG_PASSWORD" \
    --backup-start-time=03:00 \
    --enable-bin-log \
    --storage-type=SSD \
    --storage-size=10GB \
    --availability-type=zonal
```

**Production-like Configuration:**
```bash
gcloud sql instances create odbc-poc-instance \
    --database-version=MYSQL_8_0 \
    --tier=db-n1-standard-1 \
    --region=us-central1 \
    --root-password="CHOOSE_A_STRONG_PASSWORD" \
    --backup-start-time=03:00 \
    --enable-bin-log \
    --storage-type=SSD \
    --storage-size=20GB \
    --storage-auto-increase \
    --availability-type=regional
```

**Note:** Instance creation takes 5-10 minutes.

#### 2.2 Enable Public IP (for testing)

**Option A: Using gcloud (if not already enabled):**
```bash
# Get current configuration
gcloud sql instances describe odbc-poc-instance

# If needed, assign public IP
gcloud sql instances patch odbc-poc-instance \
    --assign-ip
```

**Option B: Using Cloud Console:**
1. Go to Cloud SQL instances
2. Click on `odbc-poc-instance`
3. Click "Edit"
4. Under "Connections", enable "Public IP"
5. Save changes

#### 2.3 Configure Authorized Networks

Allow your development machine and Cloud Run to connect:

```bash
# Add your current IP (for development/testing)
MY_IP=$(curl -s ifconfig.me)
gcloud sql instances patch odbc-poc-instance \
    --authorized-networks=$MY_IP

# For Cloud Run connectivity, add 0.0.0.0/0 (or use Private IP for production)
gcloud sql instances patch odbc-poc-instance \
    --authorized-networks=$MY_IP,0.0.0.0/0
```

**Security Note:** For production, use Cloud SQL Proxy or Private IP instead of `0.0.0.0/0`.

#### 2.4 Get Instance Connection Details

```bash
# Get the public IP address
gcloud sql instances describe odbc-poc-instance \
    --format="value(ipAddresses[0].ipAddress)"

# Save it for later
export DB_HOST=$(gcloud sql instances describe odbc-poc-instance \
    --format="value(ipAddresses[0].ipAddress)")

echo "Database Host: $DB_HOST"
```

### Part 3: Database Setup

#### 3.1 Create Database User

```bash
# Create a dedicated application user
gcloud sql users create odbcuser \
    --instance=odbc-poc-instance \
    --password="CHOOSE_A_STRONG_PASSWORD"

# Save credentials
export DB_USER="odbcuser"
export DB_PASSWORD="CHOOSE_A_STRONG_PASSWORD"
```

#### 3.2 Initialize Database and Table

**Option A: Using Cloud Shell or Local MySQL Client:**

```bash
# Connect to the instance
gcloud sql connect odbc-poc-instance --user=root

# Once connected to MySQL prompt, run:
```

```sql
-- Create database
CREATE DATABASE IF NOT EXISTS odbc_poc_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE odbc_poc_db;

-- Create the databricks table
CREATE TABLE databricks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    value VARCHAR(255),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert sample data
INSERT INTO databricks (name, value, description) VALUES
    ('sample_record_1', 'test_value_1', 'This is a test record for ODBC connectivity verification'),
    ('sample_record_2', 'test_value_2', 'Second test record to ensure multiple rows work'),
    ('sample_record_3', 'test_value_3', 'Third test record for comprehensive testing');

-- Grant permissions to application user
GRANT ALL PRIVILEGES ON odbc_poc_db.* TO 'odbcuser'@'%';
FLUSH PRIVILEGES;

-- Verify
SELECT * FROM databricks;
```

**Option B: Using the Provided SQL Script:**

```bash
# Upload and execute the init script
gcloud sql import sql odbc-poc-instance gs://your-bucket/init_database.sql \
    --database=mysql

# Note: You'll need to upload init_database.sql to a Cloud Storage bucket first
```

#### 3.3 Verify Database Setup

```bash
# Connect and verify
gcloud sql connect odbc-poc-instance --user=odbcuser --database=odbc_poc_db

# In MySQL prompt:
# SELECT COUNT(*) FROM databricks;
# Should show 3 records
```

### Part 4: Local Development and Testing

#### 4.1 Set Up Local Environment

```bash
# Clone this repository (if not already done)
cd odbc-databridge-poc

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

#### 4.2 Configure Environment Variables

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your values
# DB_HOST=<your-cloud-sql-ip>
# DB_PORT=3306
# DB_NAME=odbc_poc_db
# DB_USER=odbcuser
# DB_PASSWORD=<your-password>
```

#### 4.3 Install ODBC Drivers (Local Development)

**On Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y unixodbc unixodbc-dev
wget https://dev.mysql.com/get/Downloads/Connector-ODBC/8.0/mysql-connector-odbc-8.0.35-linux-glibc2.28-x86-64bit.tar.gz
tar -xzf mysql-connector-odbc-8.0.35-linux-glibc2.28-x86-64bit.tar.gz
sudo cp mysql-connector-odbc-8.0.35-linux-glibc2.28-x86-64bit/lib/libmyodbc8* /usr/lib/x86_64-linux-gnu/odbc/

# Register driver
sudo bash -c 'cat > /etc/odbcinst.ini << EOF
[MySQL ODBC 8.0 Driver]
Description = MySQL ODBC 8.0 Driver
Driver = /usr/lib/x86_64-linux-gnu/odbc/libmyodbc8w.so
Setup = /usr/lib/x86_64-linux-gnu/odbc/libmyodbc8S.so
UsageCount = 1
EOF'
```

**On macOS:**
```bash
brew install unixodbc
brew install mysql-connector-odbc

# Register driver (path may vary)
odbcinst -i -d -f /usr/local/Cellar/mysql-connector-odbc/*/odbcinst.ini
```

#### 4.4 Run Locally

```bash
# Load environment variables
source .env  # or: export $(cat .env | xargs)

# Run the application
python main.py

# Or using uvicorn directly
uvicorn main:app --reload --port 8080
```

#### 4.5 Test Local Endpoints

```bash
# Health check
curl http://localhost:8080/health

# Connection test
curl http://localhost:8080/test-connection

# Get record
curl http://localhost:8080/get-record

# Available drivers
curl http://localhost:8080/available-drivers
```

### Part 5: Cloud Run Deployment

#### 5.1 Set Environment Variables for Deployment

```bash
export GOOGLE_CLOUD_PROJECT="your-project-id"
export DB_HOST="<your-cloud-sql-ip>"
export DB_NAME="odbc_poc_db"
export DB_USER="odbcuser"
export DB_PASSWORD="<your-password>"
export REGION="us-central1"  # Optional
```

#### 5.2 Deploy Using the Deployment Script

```bash
# Make script executable (if not already)
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

#### 5.3 Manual Deployment (Alternative)

```bash
# Build container
gcloud builds submit --tag gcr.io/$PROJECT_ID/odbc-cloudsql-poc

# Deploy to Cloud Run
gcloud run deploy odbc-cloudsql-poc \
    --image gcr.io/$PROJECT_ID/odbc-cloudsql-poc \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated \
    --set-env-vars "DB_HOST=$DB_HOST,DB_PORT=3306,DB_NAME=$DB_NAME,DB_USER=$DB_USER,DB_PASSWORD=$DB_PASSWORD" \
    --memory 512Mi \
    --cpu 1 \
    --timeout 300
```

#### 5.4 Get Service URL

```bash
# Get the deployed service URL
gcloud run services describe odbc-cloudsql-poc \
    --platform managed \
    --region us-central1 \
    --format 'value(status.url)'
```

### Part 6: Testing the Deployed Service

```bash
# Save the service URL
export SERVICE_URL=$(gcloud run services describe odbc-cloudsql-poc \
    --platform managed \
    --region us-central1 \
    --format 'value(status.url)')

# Test health endpoint
curl $SERVICE_URL/health

# Test connection
curl $SERVICE_URL/test-connection

# Retrieve record
curl $SERVICE_URL/get-record

# Check available drivers
curl $SERVICE_URL/available-drivers
```

Expected responses:

**Health Check:**
```json
{
  "status": "success",
  "message": "Service is healthy and running"
}
```

**Connection Test:**
```json
{
  "status": "success",
  "message": "ODBC connection successful",
  "driver_info": {
    "driver_name": "libmyodbc8w.so",
    "driver_version": "08.00.0035",
    "database_name": "odbc_poc_db",
    "dbms_name": "MySQL",
    "dbms_version": "8.0.31"
  }
}
```

**Get Record:**
```json
{
  "status": "success",
  "record": {
    "id": 1,
    "name": "sample_record_1",
    "value": "test_value_1",
    "description": "This is a test record for ODBC connectivity verification",
    "created_at": "2024-01-01T12:00:00",
    "updated_at": "2024-01-01T12:00:00"
  },
  "message": "Record retrieved successfully"
}
```

## API Endpoints Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Root endpoint, returns service info |
| `/health` | GET | Health check without database connection |
| `/test-connection` | GET | Tests ODBC connection and returns driver info |
| `/get-record` | GET | Retrieves one record from databricks table |
| `/available-drivers` | GET | Lists installed ODBC drivers |

## Architecture

```
┌─────────────┐         ┌──────────────┐         ┌─────────────────┐
│   Client    │────────>│  Cloud Run   │────────>│   Cloud SQL     │
│  (HTTP)     │         │  (FastAPI)   │         │    (MySQL)      │
└─────────────┘         └──────────────┘         └─────────────────┘
                             │                            │
                             │                            │
                        ODBC Driver                  Public IP
                        MySQL 8.0                   (or Private IP)
```

## Security Considerations

### For Production Use:

1. **Use Cloud SQL Proxy or Private IP** instead of public IP
2. **Remove 0.0.0.0/0** from authorized networks
3. **Use Secret Manager** for database credentials instead of environment variables
4. **Enable Cloud SQL IAM authentication**
5. **Require authentication** for Cloud Run service
6. **Enable VPC connector** for private connectivity
7. **Use least privilege** database user permissions

### Example: Using Secret Manager

```bash
# Create secrets
echo -n "$DB_PASSWORD" | gcloud secrets create db-password --data-file=-

# Grant Cloud Run access
gcloud secrets add-iam-policy-binding db-password \
    --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# Deploy with secrets
gcloud run deploy odbc-cloudsql-poc \
    --update-secrets=DB_PASSWORD=db-password:latest
```

## Customizing for Your Data

To use your own sample data, modify `init_database.sql`:

1. Update the `databricks` table schema to match your data structure
2. Replace the INSERT statements with your sample data
3. Re-run the database initialization

Example:
```sql
CREATE TABLE databricks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    your_column_1 VARCHAR(255),
    your_column_2 INT,
    -- Add your columns here
);

INSERT INTO databricks (your_column_1, your_column_2) VALUES
    ('your_data_1', 123),
    ('your_data_2', 456);
```

## Troubleshooting

### Connection Issues

**Problem:** "No ODBC drivers found"
```bash
# Check available drivers
curl $SERVICE_URL/available-drivers

# Verify driver installation in container
gcloud run services describe odbc-cloudsql-poc --format=yaml | grep image
```

**Problem:** "Cannot connect to database"
```bash
# Verify Cloud SQL instance is running
gcloud sql instances describe odbc-poc-instance

# Check authorized networks
gcloud sql instances describe odbc-poc-instance \
    --format="value(settings.ipConfiguration.authorizedNetworks)"

# Test connection from Cloud Shell
gcloud sql connect odbc-poc-instance --user=odbcuser
```

**Problem:** "Access denied for user"
```bash
# Verify user exists
gcloud sql users list --instance=odbc-poc-instance

# Reset password
gcloud sql users set-password odbcuser \
    --instance=odbc-poc-instance \
    --password=NEW_PASSWORD
```

### Cloud Run Issues

**Problem:** "Service timeout"
```bash
# Increase timeout
gcloud run services update odbc-cloudsql-poc \
    --timeout 300

# Check logs
gcloud run services logs read odbc-cloudsql-poc
```

**Problem:** "Container failed to start"
```bash
# Check build logs
gcloud builds list --limit 5

# View specific build
gcloud builds log BUILD_ID
```

### Viewing Logs

```bash
# Cloud Run logs
gcloud run services logs read odbc-cloudsql-poc --limit 50

# Cloud SQL logs
gcloud sql operations list --instance=odbc-poc-instance

# Follow logs in real-time
gcloud run services logs tail odbc-cloudsql-poc
```

## Cost Estimation

**Development Setup (approximate monthly costs):**
- Cloud SQL (db-f1-micro, 10GB SSD): $7-10
- Cloud Run (minimal traffic): $0-2
- Cloud Build: Free tier (120 builds/day)
- **Total: ~$10-15/month**

**Production Setup:**
- Cloud SQL (db-n1-standard-1, 20GB SSD): $50-70
- Cloud Run (moderate traffic): $5-20
- **Total: ~$60-100/month**

## Clean Up

To avoid ongoing charges, delete resources when done testing:

```bash
# Delete Cloud Run service
gcloud run services delete odbc-cloudsql-poc --region us-central1

# Delete Cloud SQL instance (WARNING: This deletes all data!)
gcloud sql instances delete odbc-poc-instance

# Delete container images
gcloud container images list --repository=gcr.io/$PROJECT_ID
gcloud container images delete gcr.io/$PROJECT_ID/odbc-cloudsql-poc

# Delete project (WARNING: Deletes everything!)
gcloud projects delete $PROJECT_ID
```

## Next Steps

After proving ODBC connectivity works, consider:

1. **Add authentication**: Implement OAuth2 or API keys
2. **Add more endpoints**: CRUD operations for your data
3. **Implement connection pooling**: For better performance
4. **Add monitoring**: Cloud Monitoring and alerting
5. **Set up CI/CD**: Automated deployments with Cloud Build
6. **Migrate to Private IP**: For better security
7. **Add caching**: Redis or Memorystore for performance

## Additional Resources

- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [MySQL ODBC Driver Documentation](https://dev.mysql.com/doc/connector-odbc/en/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [pyodbc Documentation](https://github.com/mkleehammer/pyodbc/wiki)

## Support

For issues with:
- **Google Cloud**: Contact Google Cloud Support
- **This POC**: Create an issue in this repository
- **ODBC Drivers**: Check MySQL Connector/ODBC documentation

## License

This proof of concept is provided as-is for demonstration purposes.
