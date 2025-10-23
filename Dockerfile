# Use official Python runtime as base image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies and MariaDB ODBC driver (MySQL-compatible)
# Using Debian's stable packages - no external repos, no expired keys, no BS
RUN apt-get update && apt-get install -y \
    unixodbc \
    unixodbc-dev \
    odbc-mariadb \
    && rm -rf /var/lib/apt/lists/*

# MariaDB ODBC driver is automatically registered by the package
# Verify it's there and create an alias as "MySQL ODBC 8.0 Driver" for compatibility
RUN echo "[MySQL ODBC 8.0 Driver]" >> /etc/odbcinst.ini \
    && echo "Description = MariaDB ODBC Driver (MySQL Compatible)" >> /etc/odbcinst.ini \
    && echo "Driver = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so" >> /etc/odbcinst.ini

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
