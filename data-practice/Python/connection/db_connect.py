import os
import psycopg2
from sqlalchemy import create_engine
import pandas as pd

# Get database connection parameters from environment variables or use defaults
# Default connection string for your Supabase database
DATABASE_URL = os.environ.get('DATABASE_URL', 'postgresql://postgres:postgres@db.bfqeyzepvkrhbdfjxeld.supabase.co:5432/postgres')

# Fix for Heroku's postgres:// vs postgresql:// issue
if DATABASE_URL and DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

# For backwards compatibility with the existing code
DB_PARAMS = {
    'host': os.environ.get('DB_HOST', 'db.bfqeyzepvkrhbdfjxeld.supabase.co'),
    'database': os.environ.get('DB_NAME', 'postgres'),
    'user': os.environ.get('DB_USER', 'postgres'),
    'password': os.environ.get('DB_PASSWORD', 'postgres'),
    'port': int(os.environ.get('DB_PORT', 5432))
}

def get_connection():
    """Get a PostgreSQL database connection"""
    try:
        # Try to connect using DATABASE_URL first, fall back to DB_PARAMS
        if DATABASE_URL:
            conn = psycopg2.connect(DATABASE_URL)
        else:
            conn = psycopg2.connect(**DB_PARAMS)
        return conn
    except Exception as e:
        print(f"Error connecting to database: {e}")
        return None

def get_sqlalchemy_engine():
    """Get SQLAlchemy engine for pandas operations"""
    try:
        # Try to use DATABASE_URL first, fall back to constructing connection string
        if DATABASE_URL:
            return create_engine(DATABASE_URL)
        else:
            connection_string = f"postgresql+psycopg2://{DB_PARAMS['user']}:{DB_PARAMS['password']}@{DB_PARAMS['host']}:{DB_PARAMS['port']}/{DB_PARAMS['database']}"
            return create_engine(connection_string)
    except Exception as e:
        print(f"Error creating SQLAlchemy engine: {e}")
        raise

def query_to_dataframe(query):
    """Execute SQL query and return results as pandas DataFrame"""
    engine = get_sqlalchemy_engine()
    try:
        return pd.read_sql(query, engine)
    except Exception as e:
        print(f"Error executing query: {e}")
        return pd.DataFrame()

def dataframe_to_sql(df, table_name, if_exists='replace'):
    """Write pandas DataFrame to SQL database"""
    engine = get_sqlalchemy_engine()
    try:
        df.to_sql(table_name, engine, if_exists=if_exists, index=False)
        return True
    except Exception as e:
        print(f"Error writing to database: {e}")
        return False