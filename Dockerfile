# Use official Python runtime as base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies required for ODBC
RUN apt-get update && apt-get install -y \
    # ODBC driver manager
    unixodbc \
    unixodbc-dev \
    # MySQL ODBC driver
    default-libmysqlclient-dev \
    # Download tools
    wget \
    gnupg \
    curl \
    # Build tools (needed for some Python packages)
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Download and install MySQL ODBC Connector 8.0
RUN wget https://dev.mysql.com/get/Downloads/Connector-ODBC/8.0/mysql-connector-odbc-8.0.35-linux-glibc2.28-x86-64bit.tar.gz \
    && tar -xzf mysql-connector-odbc-8.0.35-linux-glibc2.28-x86-64bit.tar.gz \
    && cp mysql-connector-odbc-8.0.35-linux-glibc2.28-x86-64bit/lib/libmyodbc8* /usr/lib/x86_64-linux-gnu/odbc/ \
    && rm -rf mysql-connector-odbc-8.0.35-linux-glibc2.28-x86-64bit* \
    # Register the MySQL ODBC driver
    && echo "[MySQL ODBC 8.0 Driver]" > /etc/odbcinst.ini \
    && echo "Description = MySQL ODBC 8.0 Driver" >> /etc/odbcinst.ini \
    && echo "Driver = /usr/lib/x86_64-linux-gnu/odbc/libmyodbc8w.so" >> /etc/odbcinst.ini \
    && echo "Setup = /usr/lib/x86_64-linux-gnu/odbc/libmyodbc8S.so" >> /etc/odbcinst.ini \
    && echo "UsageCount = 1" >> /etc/odbcinst.ini

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Expose port (Cloud Run will set PORT environment variable)
EXPOSE 8080

# Set environment variable for port
ENV PORT=8080

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
