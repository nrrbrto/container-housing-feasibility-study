import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
import os
from datetime import datetime

# Database connection parameters
DB_PARAMS = {
    'host': 'localhost',
    'database': 'container_housing',
    'user': 'postgres',
    'password': 'postgres',
    'port': 5432
}

# Path to CSV files
BASE_PATH = 'C:/Users/Banette/Documents/Container Housing Feasibility/data-practice/processed/Per Year/'
YEARS = list(range(2017, 2024))  # 2017 to 2024

def connect_to_db():
    """Connect to the PostgreSQL database server"""
    conn = None
    try:
        print('Connecting to the PostgreSQL database...')
        conn = psycopg2.connect(**DB_PARAMS)
        return conn
    except (Exception, psycopg2.DatabaseError) as error:
        print(f"Error connecting to PostgreSQL: {error}")
        if conn is not None:
            conn.close()
        raise

def clean_data(df):
    """Clean and standardize data"""
    # Make a copy of the dataframe to avoid warnings
    df = df.copy()
    
    # Handle date columns with explicit format (day/month/year)
    date_columns = ['ship_date', 'delivery_date']
    for col in date_columns:
        if col in df.columns:
            try:
                # Convert to string
                df[col] = df[col].astype(str)
                # Parse with day first format
                df[col] = pd.to_datetime(df[col], errors='coerce', dayfirst=True)
                # Convert to string
                df[col] = df[col].dt.strftime('%Y-%m-%d')
            except Exception as e:
                print(f"Warning: Error converting {col} column: {e}")
    
    # Standardize column names
    df.columns = [col.lower().strip() for col in df.columns]
    
    # Handle missing values
    df = df.where(pd.notnull(df), None)
    
    # Standardize status values
    if 'status' in df.columns:
        df['status'] = df['status'].str.lower() if df['status'].dtype == 'object' else df['status']
        # Map status values
        status_map = {
            'dlvrd': 'delivered',
            'in_transit': 'in_transit',
            'ordered': 'ordered'
        }
        df['status'] = df['status'].map(lambda x: status_map.get(x, x) if isinstance(x, str) else x)
    
    return df

def import_data_from_csv():
    """Import data from multiple CSV files (one per year)"""
    try:
        # Connect to database
        conn = connect_to_db()
        cursor = conn.cursor()
        
        # Create tables if they don't exist
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS shipping_container_raw (
            id SERIAL PRIMARY KEY,
            container_id VARCHAR(20),
            ship_date DATE,
            delivery_date DATE,
            producer VARCHAR(100),
            producer_type VARCHAR(50),
            container_type VARCHAR(50),
            container_qty NUMERIC(10,1),
            origin VARCHAR(50),
            destination VARCHAR(50),
            freight_index NUMERIC(10,2),
            base_price NUMERIC(12,2),
            priority VARCHAR(20),
            status VARCHAR(20),
            import_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)
        
        # Clear existing raw data if needed
        cursor.execute("TRUNCATE TABLE shipping_container_raw")
        
        total_rows = 0
        
        # Process each year's CSV file
        for year in YEARS:
            csv_file = f"{BASE_PATH}{year}.csv"
            
            # Check if file exists
            if not os.path.exists(csv_file):
                print(f"Warning: File for year {year} not found at {csv_file}")
                continue
                
            print(f"Processing data for year {year}")
            
            # Read CSV file
            try:
                df = pd.read_csv(csv_file)
                print(f"  Loaded {len(df)} rows from CSV")
                
                # Print column information
                print(f"  Columns in CSV: {', '.join(df.columns)}")
                
                # Show sample of first row
                if len(df) > 0:
                    print(f"  First row sample: {dict(df.iloc[0])}")
                
            except Exception as e:
                print(f"Error reading CSV for year {year}: {e}")
                continue
            
            # Clean and standardize the data
            df = clean_data(df)
            
            # Check necessary columns exist
            required_columns = ['container_id', 'ship_date', 'freight_index', 'base_price']
            missing_columns = [col for col in required_columns if col not in df.columns]
            
            if missing_columns:
                print(f"Warning: Data for year {year} is missing required columns: {', '.join(missing_columns)}")
                print(f"Available columns: {', '.join(df.columns)}")
                continue
            
            # Select only columns that exist in our table
            valid_columns = [
                'container_id', 'ship_date', 'delivery_date', 'producer', 'producer_type',
                'container_type', 'container_qty', 'origin', 'destination', 
                'freight_index', 'base_price', 'priority', 'status'
            ]
            existing_columns = [col for col in valid_columns if col in df.columns]
            df = df[existing_columns]
            
            # Convert DataFrame to list of tuples
            data = []
            for _, row in df.iterrows():
                # Create a tuple with only the values for existing columns
                # Handle None/NaN values appropriately
                record = tuple(None if pd.isna(row[col]) else row[col] for col in existing_columns)
                data.append(record)
            
            if not data:
                print(f"No valid data found for year {year}")
                continue

            valid_data = []
            for record in data:
                # Determine indices for container_id and ship_date fields
                container_id_idx = existing_columns.index('container_id') if 'container_id' in existing_columns else None
                ship_date_idx = existing_columns.index('ship_date') if 'ship_date' in existing_columns else None
                
                # Skip if both essential fields are None
                if (container_id_idx is None or record[container_id_idx] is None) and \
                (ship_date_idx is None or record[ship_date_idx] is None):
                    print(f"Skipping record with null essential fields: {record}")
                    continue
                
                valid_data.append(record)

            # Use valid_data instead of data for inserts
            data = valid_data

            # Generate column list for SQL
            columns = ', '.join(existing_columns)
            
            # Build the query with the right number of placeholders
            placeholders = ', '.join(['%s'] * len(existing_columns))
            query = f"INSERT INTO shipping_container_raw ({columns}) VALUES ({placeholders})"
            
            # Execute the insert for each row (safer approach)
            for record in data:
                try:
                    cursor.execute(query, record)
                except Exception as e:
                    print(f"Error inserting record: {e}")
                    print(f"  Record data: {record}")
                    # Continue with next record
                    continue
            
            rows_added = len(data)
            total_rows += rows_added
            print(f"Added {rows_added} rows from year {year}")
        
        # Calculate monthly averages and populate shipping_container_prices table
        print("Calculating monthly averages...")
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS shipping_container_prices (
            id SERIAL PRIMARY KEY,
            ship_date DATE NOT NULL,
            freight_index NUMERIC(10,2) NOT NULL,
            base_price NUMERIC(12,2) NOT NULL,
            calculated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)
        
        # Clear existing data and recalculate
        cursor.execute("TRUNCATE TABLE shipping_container_prices")
        
        # Insert monthly averages
        cursor.execute("""
        INSERT INTO shipping_container_prices (ship_date, freight_index, base_price)
        SELECT 
            DATE_TRUNC('month', ship_date)::DATE AS month_date,
            AVG(freight_index) AS avg_freight_index,
            AVG(base_price) AS avg_base_price
        FROM shipping_container_raw
        WHERE ship_date IS NOT NULL
        GROUP BY DATE_TRUNC('month', ship_date)
        ORDER BY month_date
        """)
        
        # Commit the transaction
        conn.commit()
        
        # Count the records in both tables
        cursor.execute("SELECT COUNT(*) FROM shipping_container_raw")
        raw_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM shipping_container_prices")
        monthly_count = cursor.fetchone()[0]
        
        print(f"Import completed successfully!")
        print(f"Total raw records: {raw_count}")
        print(f"Monthly aggregated records: {monthly_count}")
        
        # Close cursor and connection
        cursor.close()
        conn.close()
        
    except Exception as e:
        print(f"Error during import: {e}")
        if 'conn' in locals() and conn is not None:
            conn.rollback()
            conn.close()

if __name__ == "__main__":
    import_data_from_csv()