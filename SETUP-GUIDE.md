# Step-by-Step Setup Guide (Google Cloud Console)

This guide walks you through setting up the ODBC Cloud SQL POC using the Google Cloud Console UI. Each step has verification checkpoints so you can confirm everything works before proceeding.

---

## Overview of What We'll Build

```
Your Browser → Cloud Run (FastAPI + ODBC) → Cloud SQL (MySQL)
```

**Time Required:** 45-60 minutes (with validation at each step)
**Cost:** ~$10-15/month while running

---

## Phase 1: Google Cloud Project Setup

### Step 1.1: Create a New Project

**In Google Cloud Console:**

1. Go to https://console.cloud.google.com/
2. Click the project dropdown at the top (next to "Google Cloud")
3. Click "NEW PROJECT"
4. Enter project details:
   - **Project name:** `odbc-cloud-sql-poc` (or your choice)
   - **Project ID:** Will auto-generate (note this down - you'll need it!)
   - **Organization:** Leave as default (No organization)
5. Click "CREATE"
6. Wait 10-20 seconds for project creation

**✓ VERIFICATION:**
- You should see a notification "Project created successfully"
- The project dropdown should now show your new project name

**📝 SAVE THIS:**
```
Project ID: ___________________ (write this down!)
```

---

### Step 1.2: Enable Billing

**In Google Cloud Console:**

1. Make sure your new project is selected (check project dropdown at top)
2. Go to: https://console.cloud.google.com/billing
3. Click "LINK A BILLING ACCOUNT"
4. Select your billing account (or create one if you haven't)
5. Click "SET ACCOUNT"

**✓ VERIFICATION:**
- You should see "Billing account: [Your Account]" at the top
- No warning about billing being required

**⏸️ PAUSE HERE:** Confirm billing is enabled before continuing

---

### Step 1.3: Enable Required APIs

**In Google Cloud Console:**

1. Go to: https://console.cloud.google.com/apis/library
2. Search for and enable each of these (one at a time):

   **a) Cloud SQL Admin API**
   - Search: "Cloud SQL Admin API"
   - Click on it
   - Click "ENABLE"
   - Wait for "API enabled" message

   **b) Cloud Run API**
   - Search: "Cloud Run API"
   - Click on it
   - Click "ENABLE"

   **c) Cloud Build API**
   - Search: "Cloud Build API"
   - Click on it
   - Click "ENABLE"

   **d) Artifact Registry API**
   - Search: "Artifact Registry API"
   - Click on it
   - Click "ENABLE"

**✓ VERIFICATION:**
- Go to: https://console.cloud.google.com/apis/dashboard
- You should see all 4 APIs listed as "Enabled"

**⏸️ PAUSE HERE:** Confirm all APIs are enabled

---

## Phase 2: Cloud SQL Setup

### Step 2.1: Create Cloud SQL Instance

**In Google Cloud Console:**

1. Go to: https://console.cloud.google.com/sql
2. Click "CREATE INSTANCE"
3. Choose "MySQL"
4. Click "CHOOSE MYSQL" (or "Enable API" if shown)

**Configure the instance:**

**Instance Info:**
- **Instance ID:** `odbc-poc-instance`
- **Password:** (Choose a strong password - SAVE THIS!)
  ```
  Root Password: ___________________ (write this down securely!)
  ```
- **Database version:** MySQL 8.0
- **Region:** Choose closest to you (e.g., `us-central1`)
- **Zonal availability:** Single zone

**Machine Configuration:**
- Click "SHOW CONFIGURATION OPTIONS"
- Under "Machine type":
  - **Preset:** Lightweight
  - **Machine type:** db-f1-micro (1 vCPU, 0.6 GB) - Good for testing

**Storage:**
- **Storage type:** SSD
- **Storage capacity:** 10 GB
- Enable automatic storage increases: ☐ (leave unchecked for POC)

**Connections:**
- **Public IP:** ☑ (check this box)
- **Private IP:** ☐ (leave unchecked)
- **Authorized networks:** We'll configure this after creation

**Data Protection:**
- **Automated backups:** ☑ (keep enabled)
- **Backup time:** 03:00 (default is fine)

5. Click "CREATE INSTANCE"

**⏳ WAIT:** This takes 5-10 minutes. You'll see "Creating instance..."

**✓ VERIFICATION:**
- Instance status shows green checkmark
- Instance is "RUNNABLE"
- You can see a Public IP address

**📝 SAVE THIS:**
```
Instance Name: odbc-poc-instance
Public IP: ___________________ (you'll see this in the instance details)
Region: ___________________
```

**⏸️ PAUSE HERE:** Wait until instance is fully created and running

---

### Step 2.2: Configure Network Access

**In Google Cloud Console:**

1. Go to: https://console.cloud.google.com/sql/instances
2. Click on `odbc-poc-instance`
3. Click "CONNECTIONS" tab (left sidebar)
4. Under "Authorized networks" section:
   - Click "ADD NETWORK"
   - **Name:** `allow-all-poc` (temporary for testing)
   - **Network:** `0.0.0.0/0`
   - Click "DONE"
   - Click "SAVE" at the bottom

**⚠️ SECURITY NOTE:**
- `0.0.0.0/0` allows connections from anywhere (OK for POC)
- For production, restrict this to specific IPs

**✓ VERIFICATION:**
- You should see `0.0.0.0/0` listed under Authorized networks
- No error messages

**⏸️ PAUSE HERE:** Confirm network configuration is saved

---

### Step 2.3: Create Database User

**In Google Cloud Console:**

1. Still in your Cloud SQL instance page
2. Click "USERS" tab (left sidebar)
3. Click "ADD USER ACCOUNT"
4. Configure:
   - **User name:** `odbcuser`
   - **Password:** (Choose a strong password - SAVE THIS!)
     ```
     App User Password: ___________________ (write this down securely!)
     ```
   - **Host name:** Allow any host (%)
5. Click "ADD"

**✓ VERIFICATION:**
- You should see `odbcuser` listed in the users table
- Host shows `%`

**📝 SAVE THIS:**
```
Database User: odbcuser
Database Password: ___________________
```

**⏸️ PAUSE HERE:** User created successfully?

---

### Step 2.4: Create Database and Table

**Option A: Using Cloud Shell (Recommended)**

1. In Google Cloud Console, click the Cloud Shell icon (>_) at the top right
2. Wait for Cloud Shell to start
3. Connect to your database:

```bash
gcloud sql connect odbc-poc-instance --user=root
```

4. Enter the root password when prompted
5. You should see `mysql>` prompt

**Now run these SQL commands** (copy and paste each section):

```sql
-- Create database
CREATE DATABASE IF NOT EXISTS odbc_poc_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
```

**✓ CHECK:** Should see "Query OK, 1 row affected"

```sql
-- Switch to database
USE odbc_poc_db;
```

**✓ CHECK:** Should see "Database changed"

```sql
-- Create table
CREATE TABLE databricks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    value VARCHAR(255),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**✓ CHECK:** Should see "Query OK, 0 rows affected"

```sql
-- Insert sample data
INSERT INTO databricks (name, value, description) VALUES
    ('sample_record_1', 'test_value_1', 'This is a test record for ODBC connectivity verification'),
    ('sample_record_2', 'test_value_2', 'Second test record to ensure multiple rows work'),
    ('sample_record_3', 'test_value_3', 'Third test record for comprehensive testing');
```

**✓ CHECK:** Should see "Query OK, 3 rows affected"

```sql
-- Grant permissions to application user
GRANT ALL PRIVILEGES ON odbc_poc_db.* TO 'odbcuser'@'%';
FLUSH PRIVILEGES;
```

**✓ CHECK:** Should see "Query OK, 0 rows affected" twice

```sql
-- Verify data
SELECT * FROM databricks;
```

**✓ CHECK:** Should see a table with 3 rows of data

```sql
-- Exit
EXIT;
```

**✓ VERIFICATION:**
- Database `odbc_poc_db` exists
- Table `databricks` exists with 3 records
- User `odbcuser` has permissions

**📝 SAVE THIS:**
```
Database Name: odbc_poc_db
Table Name: databricks
Record Count: 3
```

**⏸️ PAUSE HERE:** Can you see the 3 sample records? If yes, database is ready!

---

## Phase 3: Prepare for Cloud Run Deployment

### Step 3.1: Set Up Cloud Shell Environment

**In Cloud Shell** (the terminal at bottom of Cloud Console):

1. Make sure you're in Cloud Shell (click >_ icon if not open)
2. Set your project ID:

```bash
# Replace with YOUR actual project ID
export PROJECT_ID="your-project-id-here"
gcloud config set project $PROJECT_ID
```

**✓ CHECK:** Should see "Updated property [core/project]"

3. Clone this repository (or upload files):

```bash
# If you have the code in a repo:
git clone <your-repo-url>
cd odbc-databridge-poc

# OR upload files manually using Cloud Shell's upload button (⋮ menu → Upload)
```

**✓ VERIFICATION:**
```bash
ls -la
```

You should see:
- main.py
- requirements.txt
- Dockerfile
- deploy.sh

**⏸️ PAUSE HERE:** Files are in Cloud Shell?

---

### Step 3.2: Review and Update Configuration

**In Cloud Shell**, create your environment configuration:

```bash
# Get your Cloud SQL IP (from Step 2.1)
export DB_HOST="YOUR_CLOUD_SQL_PUBLIC_IP"
export DB_PORT="3306"
export DB_NAME="odbc_poc_db"
export DB_USER="odbcuser"
export DB_PASSWORD="YOUR_APP_USER_PASSWORD"

# Show configuration (verify it's correct)
echo "DB_HOST: $DB_HOST"
echo "DB_NAME: $DB_NAME"
echo "DB_USER: $DB_USER"
```

**✓ VERIFICATION:**
- All values are correct
- DB_HOST is the public IP from your Cloud SQL instance
- No empty values

**📝 SAVE THESE COMMANDS** - you'll need them if Cloud Shell disconnects

**⏸️ PAUSE HERE:** Configuration looks correct?

---

## Phase 4: Build and Deploy to Cloud Run

### Step 4.1: Build Container Image

**In Cloud Shell:**

```bash
# Build the container (takes 3-5 minutes)
gcloud builds submit --tag gcr.io/$PROJECT_ID/odbc-cloudsql-poc
```

**⏳ WAIT:** This takes 3-5 minutes. You'll see:
- Creating temporary tarball
- Uploading tarball
- Building image step by step
- Docker steps executing

**✓ VERIFICATION:**
You should see at the end:
```
SUCCESS
ID                                    CREATE_TIME                DURATION
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  2024-XX-XXTXX:XX:XX+XX:XX  XmXXs
```

**If build fails**, common issues:
- API not enabled → Go back to Step 1.3
- Billing not enabled → Go back to Step 1.2
- Syntax error in Dockerfile → Check the file

**⏸️ PAUSE HERE:** Build successful? If yes, you have a container image!

---

### Step 4.2: Deploy to Cloud Run

**In Cloud Shell:**

```bash
gcloud run deploy odbc-cloudsql-poc \
    --image gcr.io/$PROJECT_ID/odbc-cloudsql-poc \
    --platform managed \
    --region us-central1 \
    --allow-unauthenticated \
    --set-env-vars "DB_HOST=$DB_HOST,DB_PORT=$DB_PORT,DB_NAME=$DB_NAME,DB_USER=$DB_USER,DB_PASSWORD=$DB_PASSWORD" \
    --memory 512Mi \
    --cpu 1 \
    --timeout 300 \
    --max-instances 10
```

**Note:** Change `--region` if you used a different region for Cloud SQL

**⏳ WAIT:** Takes 30-60 seconds

You'll see:
- Deploying container
- Creating Revision
- Routing traffic
- Service URL displayed

**✓ VERIFICATION:**
You should see:
```
Service [odbc-cloudsql-poc] revision [odbc-cloudsql-poc-00001-xxx] has been deployed and is serving 100 percent of traffic.
Service URL: https://odbc-cloudsql-poc-xxxxxxxxx-uc.a.run.app
```

**📝 SAVE THIS:**
```
Service URL: ___________________ (copy the full URL)
```

**⏸️ PAUSE HERE:** Deployment successful? Got the service URL?

---

## Phase 5: Test Your Deployment

### Step 5.1: Test Health Endpoint

**In Cloud Shell OR your local terminal:**

```bash
# Set your service URL
export SERVICE_URL="https://odbc-cloudsql-poc-xxxxxxxxx-uc.a.run.app"

# Test health
curl $SERVICE_URL/health
```

**✓ EXPECTED RESPONSE:**
```json
{
  "status": "success",
  "message": "Service is healthy and running"
}
```

**⏸️ PAUSE HERE:** Health check working? If not, service isn't running properly.

---

### Step 5.2: Check Available Drivers

**In Cloud Shell:**

```bash
curl $SERVICE_URL/available-drivers
```

**✓ EXPECTED RESPONSE:**
```json
{
  "status": "success",
  "drivers": [
    "MySQL ODBC 8.0 Driver"
  ],
  "message": "Found 1 ODBC driver(s)"
}
```

**⏸️ PAUSE HERE:** Do you see "MySQL ODBC 8.0 Driver"?
- ✅ YES → Driver installed correctly
- ❌ NO → Container build issue, need to rebuild

---

### Step 5.3: Test ODBC Connection

**In Cloud Shell:**

```bash
curl $SERVICE_URL/test-connection
```

**✓ EXPECTED RESPONSE:**
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

**⏸️ PAUSE HERE:** Connection successful?
- ✅ YES → ODBC is working! Database connection established!
- ❌ NO → See troubleshooting section below

---

### Step 5.4: Test Database Query

**In Cloud Shell:**

```bash
curl $SERVICE_URL/get-record
```

**✓ EXPECTED RESPONSE:**
```json
{
  "status": "success",
  "record": {
    "id": 1,
    "name": "sample_record_1",
    "value": "test_value_1",
    "description": "This is a test record for ODBC connectivity verification",
    "created_at": "2024-XX-XXTXX:XX:XX",
    "updated_at": "2024-XX-XXTXX:XX:XX"
  },
  "message": "Record retrieved successfully"
}
```

**⏸️ PAUSE HERE:** Got your data back?
- ✅ YES → **SUCCESS! ODBC connectivity fully working!** 🎉
- ❌ NO → See troubleshooting section below

---

## Phase 6: Verify in Browser

### Step 6.1: Test Endpoints in Browser

Open these URLs in your browser (replace with your actual service URL):

1. **Health Check:**
   ```
   https://odbc-cloudsql-poc-xxxxxxxxx-uc.a.run.app/health
   ```

2. **Connection Test:**
   ```
   https://odbc-cloudsql-poc-xxxxxxxxx-uc.a.run.app/test-connection
   ```

3. **Get Record:**
   ```
   https://odbc-cloudsql-poc-xxxxxxxxx-uc.a.run.app/get-record
   ```

4. **Available Drivers:**
   ```
   https://odbc-cloudsql-poc-xxxxxxxxx-uc.a.run.app/available-drivers
   ```

**✓ VERIFICATION:**
- All endpoints return JSON responses
- No error messages
- Data looks correct

---

## 🎉 Success! What You've Accomplished

You now have:
- ✅ Google Cloud project with billing
- ✅ Cloud SQL MySQL instance running
- ✅ Database with sample data
- ✅ Cloud Run service with ODBC drivers
- ✅ Working ODBC connection to Cloud SQL
- ✅ Successful database queries via ODBC

---

## Troubleshooting Guide

### Issue: Connection Test Fails

**Symptoms:**
```json
{
  "status": "error",
  "detail": "Database connection failed: ..."
}
```

**Check:**

1. **Verify Cloud SQL is accessible:**
   ```bash
   # In Cloud Shell
   gcloud sql instances describe odbc-poc-instance | grep state
   ```
   Should show: `state: RUNNABLE`

2. **Verify authorized networks:**
   - Go to Cloud SQL → Connections
   - Should see `0.0.0.0/0` in authorized networks

3. **Verify environment variables:**
   ```bash
   gcloud run services describe odbc-cloudsql-poc \
       --region us-central1 \
       --format="value(spec.template.spec.containers[0].env)"
   ```

4. **Check logs:**
   ```bash
   gcloud run services logs read odbc-cloudsql-poc --limit=50
   ```

### Issue: No ODBC Drivers Found

**Symptoms:**
```json
{
  "drivers": [],
  "message": "Found 0 ODBC driver(s)"
}
```

**Fix:**
- Container didn't build correctly
- Rebuild with:
  ```bash
  gcloud builds submit --tag gcr.io/$PROJECT_ID/odbc-cloudsql-poc
  # Then redeploy
  ```

### Issue: Database Query Returns No Records

**Symptoms:**
```json
{
  "status": "success",
  "record": null,
  "message": "No records found"
}
```

**Fix:**
- Go back to Step 2.4 and re-insert data
- Verify with:
  ```bash
  gcloud sql connect odbc-poc-instance --user=odbcuser
  # Enter password
  USE odbc_poc_db;
  SELECT COUNT(*) FROM databricks;
  ```

### Issue: Service Won't Deploy

**Check:**
1. APIs enabled? (Step 1.3)
2. Billing enabled? (Step 1.2)
3. Container built successfully? (Step 4.1)
4. Check logs:
   ```bash
   gcloud run services logs read odbc-cloudsql-poc --limit=50
   ```

---

## View Logs and Monitor

**Cloud Run Logs:**
```bash
gcloud run services logs read odbc-cloudsql-poc --limit=50
```

**Cloud Run Console:**
https://console.cloud.google.com/run

**Cloud SQL Console:**
https://console.cloud.google.com/sql

**Logs Explorer:**
https://console.cloud.google.com/logs

---

## Next Steps

Now that ODBC connectivity is proven:

1. **Customize the table schema** - Edit `init_database.sql` with your data structure
2. **Add more endpoints** - Modify `main.py` to add CRUD operations
3. **Secure the deployment:**
   - Remove `0.0.0.0/0` from authorized networks
   - Use Cloud SQL Proxy or Private IP
   - Add authentication to Cloud Run
   - Use Secret Manager for credentials

4. **Add monitoring** - Set up Cloud Monitoring alerts
5. **Optimize costs** - Review Cloud SQL tier and Cloud Run settings

---

## Clean Up (When Done Testing)

**To delete everything and stop charges:**

1. **Delete Cloud Run service:**
   ```bash
   gcloud run services delete odbc-cloudsql-poc --region us-central1
   ```

2. **Delete Cloud SQL instance:**
   ```bash
   gcloud sql instances delete odbc-poc-instance
   ```

3. **Delete container images:**
   - Go to: https://console.cloud.google.com/gcr
   - Delete the `odbc-cloudsql-poc` image

4. **Delete project (optional - deletes EVERYTHING):**
   ```bash
   gcloud projects delete YOUR_PROJECT_ID
   ```

---

## Cost Tracking

Monitor your spending:
- Go to: https://console.cloud.google.com/billing
- Set up budget alerts
- Expected: ~$10-15/month while running

---

## Summary Checklist

- [ ] Project created and billing enabled
- [ ] Cloud SQL instance running
- [ ] Database and table created with sample data
- [ ] Container image built successfully
- [ ] Cloud Run service deployed
- [ ] Health check endpoint working
- [ ] ODBC drivers detected
- [ ] Connection test successful
- [ ] Database query returning data

**If all checked, you're done! 🎉**

---

## Getting Help

If stuck at any step:

1. Check the troubleshooting section above
2. Review the logs:
   ```bash
   gcloud run services logs read odbc-cloudsql-poc --limit=50
   ```
3. Verify each configuration value matches what you noted down
4. Start fresh from the step that failed

Remember: Each step builds on the previous one, so verify each checkpoint before moving forward!
