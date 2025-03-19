import psycopg2
from sqlalchemy import create_engine
import pandas as pd

# Database connection parameters
DB_PARAMS = {
    'host': 'localhost',
    'database': 'container_housing',
    'user': 'postgres',
    'password': 'postgres',
    'port': 5432
}

def get_connection():
    """Get a PostgreSQL database connection"""
    try:
        conn = psycopg2.connect(**DB_PARAMS)
        return conn
    except Exception as e:
        print(f"Error connecting to database: {e}")
        return None

def get_sqlalchemy_engine():
    """Get SQLAlchemy engine for pandas operations"""
    connection_string = f"postgresql+psycopg2://{DB_PARAMS['user']}:{DB_PARAMS['password']}@{DB_PARAMS['host']}:{DB_PARAMS['port']}/{DB_PARAMS['database']}"
    return create_engine(connection_string)

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