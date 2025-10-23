# Use official Python runtime as base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies required for ODBC
RUN apt-get update && apt-get install -y \
    # ODBC driver manager
    unixodbc \
    unixodbc-dev \
    # MySQL client libraries
    default-libmysqlclient-dev \
    # Download tools
    wget \
    gnupg \
    curl \
    lsb-release \
    # Build tools (needed for some Python packages)
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install MySQL ODBC Connector from MySQL APT repository
# This is more reliable than direct downloads and always gets compatible versions
RUN wget https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb \
    && DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.29-1_all.deb \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-connector-odbc \
    && rm mysql-apt-config_0.8.29-1_all.deb \
    && rm -rf /var/lib/apt/lists/*

# Register the MySQL ODBC driver with odbcinst
RUN odbcinst -i -d -f /usr/share/mysql-connector-odbc/odbcinst.ini

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
