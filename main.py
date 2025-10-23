"""
ODBC Cloud SQL Proof of Concept - FastAPI Web Service

This service demonstrates ODBC connectivity to Google Cloud SQL MySQL instance.
Provides three endpoints: health check, connection test, and single record retrieval.
"""

import os
import logging
from typing import Dict, Any, Optional
from contextlib import contextmanager
from urllib.parse import quote_plus

import pyodbc
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="ODBC Cloud SQL POC",
    description="Proof of concept for ODBC connectivity to Google Cloud SQL",
    version="1.0.0"
)


class HealthResponse(BaseModel):
    status: str
    message: str


class ConnectionTestResponse(BaseModel):
    status: str
    message: str
    driver_info: Optional[Dict[str, str]] = None


class RecordResponse(BaseModel):
    status: str
    record: Optional[Dict[str, Any]] = None
    message: str


def get_connection_string() -> str:
    """
    Construct ODBC connection string from environment variables.

    Required environment variables:
    - DB_HOST: Cloud SQL instance IP or connection name
    - DB_PORT: Database port (default: 3306)
    - DB_NAME: Database name
    - DB_USER: Database user
    - DB_PASSWORD: Database password
    """
    host = os.getenv('DB_HOST')
    port = os.getenv('DB_PORT', '3306')
    database = os.getenv('DB_NAME')
    user = os.getenv('DB_USER')
    password = os.getenv('DB_PASSWORD')

    # Validate required variables
    missing_vars = []
    if not host:
        missing_vars.append('DB_HOST')
    if not database:
        missing_vars.append('DB_NAME')
    if not user:
        missing_vars.append('DB_USER')
    if not password:
        missing_vars.append('DB_PASSWORD')

    if missing_vars:
        raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

    # Try to find an available MySQL-compatible ODBC driver
    available_drivers = pyodbc.drivers()
    driver = None

    # Preferred driver names in order of preference
    preferred_drivers = [
        "MySQL ODBC 8.0 Driver",
        "MariaDB ODBC 3.1 Driver",
        "MySQL",
        "MariaDB"
    ]

    for preferred in preferred_drivers:
        if preferred in available_drivers:
            driver = preferred
            break

    if not driver:
        # Fallback: try to find any driver with "mysql" or "mariadb" in the name
        for d in available_drivers:
            if "mysql" in d.lower() or "mariadb" in d.lower():
                driver = d
                break

    if not driver:
        raise ValueError(f"No MySQL-compatible ODBC driver found. Available drivers: {available_drivers}")

    # Construct connection string
    # Wrap password in braces to handle special characters
    connection_string = (
        f"DRIVER={{{driver}}};"
        f"SERVER={host};"
        f"PORT={port};"
        f"DATABASE={database};"
        f"UID={user};"
        f"PWD={{{password}}};"
        f"charset=utf8mb4;"
    )

    logger.info(f"Using driver: {driver}, connecting to host: {host}, database: {database}")
    return connection_string


@contextmanager
def get_db_connection():
    """
    Context manager for database connections.
    Ensures proper connection cleanup.

    Uses individual connection parameters instead of a connection string
    to avoid issues with special characters in passwords.
    """
    conn = None
    try:
        # Get configuration
        host = os.getenv('DB_HOST')
        port = os.getenv('DB_PORT', '3306')
        database = os.getenv('DB_NAME')
        user = os.getenv('DB_USER')
        password = os.getenv('DB_PASSWORD')

        # Validate required variables
        missing_vars = []
        if not host:
            missing_vars.append('DB_HOST')
        if not database:
            missing_vars.append('DB_NAME')
        if not user:
            missing_vars.append('DB_USER')
        if not password:
            missing_vars.append('DB_PASSWORD')

        if missing_vars:
            raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

        # Find available driver
        available_drivers = pyodbc.drivers()
        driver = None
        preferred_drivers = [
            "MariaDB Unicode",
            "MariaDB ODBC 3.1 Driver",
            "MySQL ODBC 8.0 Driver",
            "MySQL",
            "MariaDB"
        ]

        for preferred in preferred_drivers:
            if preferred in available_drivers:
                driver = preferred
                break

        if not driver:
            for d in available_drivers:
                if "mysql" in d.lower() or "mariadb" in d.lower():
                    driver = d
                    break

        if not driver:
            raise ValueError(f"No MySQL-compatible ODBC driver found. Available drivers: {available_drivers}")

        logger.info(f"Attempting connection with driver: {driver}, host: {host}, database: {database}, user: {user}")

        # URL encode the password to handle special characters
        encoded_password = quote_plus(password)

        # Build connection string
        connection_string = (
            f"DRIVER={{{driver}}};"
            f"SERVER={host};"
            f"PORT={port};"
            f"DATABASE={database};"
            f"UID={user};"
            f"PWD={encoded_password};"
        )

        logger.info(f"Connection string built (password encoded)")
        conn = pyodbc.connect(connection_string, timeout=10)
        logger.info("Database connection established")
        yield conn
    except pyodbc.Error as e:
        logger.error(f"Database connection error: {str(e)}")
        raise
    finally:
        if conn:
            conn.close()
            logger.info("Database connection closed")


@app.get("/", response_model=HealthResponse)
async def root():
    """
    Root endpoint - redirects to health check.
    """
    return {
        "status": "success",
        "message": "ODBC Cloud SQL POC Service is running. Use /health for health check."
    }


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """
    Health check endpoint.
    Verifies the service is running without testing database connectivity.
    """
    logger.info("Health check requested")
    return {
        "status": "success",
        "message": "Service is healthy and running"
    }


@app.get("/test-connection", response_model=ConnectionTestResponse)
async def test_connection():
    """
    Database connection test endpoint.
    Tests ODBC connectivity without executing any queries.
    Returns driver information if connection succeeds.
    """
    logger.info("Connection test requested")

    try:
        with get_db_connection() as conn:
            # Get driver information
            driver_info = {
                "driver_name": conn.getinfo(pyodbc.SQL_DRIVER_NAME),
                "driver_version": conn.getinfo(pyodbc.SQL_DRIVER_VER),
                "database_name": conn.getinfo(pyodbc.SQL_DATABASE_NAME),
                "dbms_name": conn.getinfo(pyodbc.SQL_DBMS_NAME),
                "dbms_version": conn.getinfo(pyodbc.SQL_DBMS_VER),
            }

            logger.info("Connection test successful")
            return {
                "status": "success",
                "message": "ODBC connection successful",
                "driver_info": driver_info
            }

    except ValueError as e:
        logger.error(f"Configuration error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

    except pyodbc.Error as e:
        logger.error(f"ODBC connection failed: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Database connection failed: {str(e)}"
        )

    except Exception as e:
        logger.error(f"Unexpected error during connection test: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Unexpected error: {str(e)}"
        )


@app.get("/get-record", response_model=RecordResponse)
async def get_record():
    """
    Single record retrieval endpoint.
    Executes a simple query to retrieve one record from the databricks table.
    Proves that ODBC queries work correctly.
    """
    logger.info("Record retrieval requested")

    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()

            # Query to get one record from the databricks table
            query = "SELECT * FROM databricks LIMIT 1"
            logger.info(f"Executing query: {query}")

            cursor.execute(query)

            # Get column names
            columns = [column[0] for column in cursor.description]

            # Fetch one record
            row = cursor.fetchone()

            if row:
                # Convert row to dictionary
                record = dict(zip(columns, row))
                logger.info(f"Record retrieved successfully: {record}")

                return {
                    "status": "success",
                    "record": record,
                    "message": "Record retrieved successfully"
                }
            else:
                logger.warning("No records found in databricks table")
                return {
                    "status": "success",
                    "record": None,
                    "message": "No records found in databricks table"
                }

    except ValueError as e:
        logger.error(f"Configuration error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

    except pyodbc.Error as e:
        logger.error(f"Database query failed: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Database query failed: {str(e)}"
        )

    except Exception as e:
        logger.error(f"Unexpected error during record retrieval: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Unexpected error: {str(e)}"
        )


@app.get("/available-drivers")
async def available_drivers():
    """
    Utility endpoint to list available ODBC drivers.
    Useful for debugging driver installation issues.
    """
    logger.info("Available drivers requested")

    try:
        drivers = pyodbc.drivers()
        return {
            "status": "success",
            "drivers": drivers,
            "message": f"Found {len(drivers)} ODBC driver(s)"
        }
    except Exception as e:
        logger.error(f"Error listing drivers: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error listing drivers: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn

    # For local development
    port = int(os.getenv('PORT', 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
