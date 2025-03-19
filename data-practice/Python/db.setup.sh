#!/bin/bash

# Database configuration
DB_USER="postgres"
DB_NAME="container_housing"
DB_HOST="localhost"

# Step 1: Create database if it doesn't exist
echo "Creating database $DB_NAME if it doesn't exist..."
psql -U $DB_USER -h $DB_HOST -c "CREATE DATABASE $DB_NAME;" 2>/dev/null || echo "Database already exists"

# Step 2: Create schema and tables
echo "Creating schema and tables..."
psql -U $DB_USER -h $DB_HOST -d $DB_NAME -f SQL/schema.sql
psql -U $DB_USER -h $DB_HOST -d $DB_NAME -f SQL/schema_container_prices.sql

# Step 3: Create views
echo "Creating views..."
psql -U $DB_USER -h $DB_HOST -d $DB_NAME -f SQL/view_container_price.sql
psql -U $DB_USER -h $DB_HOST -d $DB_NAME -f SQL/view_shipping_analysis.sql
psql -U $DB_USER -h $DB_HOST -d $DB_NAME -f SQL/views_container_price_trends.sql
psql -U $DB_USER -h $DB_HOST -d $DB_NAME -f SQL/views_housing_dashboard.sql
psql -U $DB_USER -h $DB_HOST -d $DB_NAME -f SQL/views_housing_roi.sql

# Step 4: Create stored procedures
echo "Creating stored procedures..."
psql -U $DB_USER -h $DB_HOST -d $DB_NAME -f SQL/procedures.sql

# Step 5: Import sample data from SQL
echo "Importing sample data from SQL..."
psql -U $DB_USER -h $DB_HOST -d $DB_NAME -f SQL/import_data.sql

# Step 6: Import container data using Python script
echo "Importing container data using Python script..."
python Python/import_container_data.py

echo "Database setup complete!"