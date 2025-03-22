import os
import psycopg2
from sqlalchemy import create_engine
import pandas as pd

# Get database connection parameters from environment variables or use defaults
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
            print(f"Connecting using DATABASE_URL")
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
        else:
            conn = psycopg2.connect(**DB_PARAMS)
            return conn
    except Exception as e:
        print(f"Error connecting to database: {e}")
        return None

def get_sqlalchemy_engine():
    """Get SQLAlchemy engine for pandas operations"""
    try:
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
        print(f"Executing query: {query}")
        df = pd.read_sql(query, engine)
        print(f"Query returned {len(df)} rows with columns: {df.columns.tolist()}")
        return df
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