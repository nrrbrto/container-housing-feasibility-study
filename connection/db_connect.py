import os
import psycopg2
from sqlalchemy import create_engine
import pandas as pd
import urllib.parse

# Use transaction pooler with the updated password
DATABASE_URL = os.environ.get('DATABASE_URL', 'postgresql://postgres.bfqeyzepvkrhbdfjxeld:9K8GArjphAhQNLJc@aws-0-us-west-1.pooler.supabase.com:6543/postgres?sslmode=require')

# Fix for Heroku's postgres:// vs postgresql:// issue
if DATABASE_URL and DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

def get_connection():
    """Get a PostgreSQL database connection"""
    try:
        print(f"Connecting using direct connection")
        conn = psycopg2.connect(DATABASE_URL)
        
        # Test the connection
        cursor = conn.cursor()
        cursor.execute("SELECT version()")
        db_version = cursor.fetchone()
        print(f"Connected to PostgreSQL: {db_version[0]}")
        
        # List tables
        cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public'")
        tables = [table[0] for table in cursor.fetchall()]
        print(f"Available tables: {tables}")
        cursor.close()
        
        return conn
    except Exception as e:
        print(f"Error connecting to database: {e}")
        return None

def get_sqlalchemy_engine():
    """Get SQLAlchemy engine for pandas operations"""
    try:
        # Create a safe version for logging (hide password)
        safe_url = DATABASE_URL
        if '@' in safe_url:
            parts = safe_url.split('@')
            credentials = parts[0].split(':')
            if len(credentials) > 2:
                safe_url = f"{credentials[0]}:{credentials[1]}:****@{parts[1]}"
            else:
                safe_url = f"{credentials[0]}:****@{parts[1]}"
        
        print(f"Creating SQLAlchemy engine with URL pattern: {safe_url}")
        engine = create_engine(DATABASE_URL)
        
        # Test connection
        with engine.connect() as conn:
            result = conn.execute("SELECT 1")
            print("SQLAlchemy connection test successful")
        
        return engine
    except Exception as e:
        print(f"Error creating SQLAlchemy engine: {e}")
        import traceback
        traceback.print_exc()
        raise

def query_to_dataframe(query):
    """Execute SQL query and return results as pandas DataFrame"""
    try:
        engine = get_sqlalchemy_engine()
        print(f"Executing query: {query}")
        df = pd.read_sql(query, engine)
        print(f"Query returned {len(df)} rows with columns: {df.columns.tolist()}")
        return df
    except Exception as e:
        print(f"Error executing query: {e}")
        return pd.DataFrame()

def dataframe_to_sql(df, table_name, if_exists='replace'):
    """Write pandas DataFrame to SQL database"""
    try:
        engine = get_sqlalchemy_engine()
        df.to_sql(table_name, engine, if_exists=if_exists, index=False)
        print(f"Data written to table {table_name} successfully.")
        return True
    except Exception as e:
        print(f"Error writing to database: {e}")
        return False