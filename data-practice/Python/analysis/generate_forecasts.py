import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
import psycopg2
from sqlalchemy import create_engine

# Database connection parameters
DB_PARAMS = {
    'host': 'localhost',
    'database': 'container_housing',
    'user': 'postgres',
    'password': 'postgres',
    'port': 5432
}

def get_connection():
    return psycopg2.connect(**DB_PARAMS)

def get_sqlalchemy_engine():
    conn_string = f"postgresql://{DB_PARAMS['user']}:{DB_PARAMS['password']}@{DB_PARAMS['host']}:{DB_PARAMS['port']}/{DB_PARAMS['database']}"
    return create_engine(conn_string)

def query_to_dataframe(query):
    engine = get_sqlalchemy_engine()
    return pd.read_sql(query, engine)

def setup_forecast_table():
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("DROP TABLE IF EXISTS container_price_forecast")
        cursor.execute("""
        CREATE TABLE container_price_forecast (
            id SERIAL PRIMARY KEY,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            time_index INTEGER NOT NULL,
            year_fraction NUMERIC(10,2) NOT NULL,
            avg_price NUMERIC(12,2),
            lower_bound NUMERIC(12,2),
            upper_bound NUMERIC(12,2),
            avg_freight_index NUMERIC(12,2),
            freight_lower_bound NUMERIC(12,2),
            freight_upper_bound NUMERIC(12,2),
            calculated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)
        conn.commit()
        return True
    except Exception as e:
        print(f"Error creating forecast table: {e}")
        conn.rollback()
        return False
    finally:
        conn.close()

def load_container_price_data():
    query = """
    SELECT 
        EXTRACT(YEAR FROM ship_date) AS year,
        EXTRACT(MONTH FROM ship_date) AS month,
        AVG(base_price) AS avg_price,
        AVG(freight_index) AS avg_freight_index
    FROM shipping_container_prices
    GROUP BY EXTRACT(YEAR FROM ship_date), EXTRACT(MONTH FROM ship_date)
    ORDER BY year, month
    """
    return query_to_dataframe(query)

def create_features(df, target_column):
    df_features = df.copy()
    df_features['time_index'] = df_features.index
    df_features['year_fraction'] = df_features['year'] + (df_features['month'] - 1) / 12
    
    # Add seasonality features
    df_features['month_sin'] = np.sin(2 * np.pi * df_features['month'] / 12)
    df_features['month_cos'] = np.cos(2 * np.pi * df_features['month'] / 12)
    
    # Create lag features
    df_features[f'{target_column}_lag1'] = df_features[target_column].shift(1)
    df_features[f'{target_column}_lag2'] = df_features[target_column].shift(2)
    
    # Create rolling mean features
    df_features['rolling_mean_2'] = df_features[target_column].rolling(window=2).mean()
    
    # Drop rows with NaN values
    df_features = df_features.dropna()
    return df_features

def train_model(features_df, target_column):
    feature_cols = ['time_index', 'year_fraction', f'{target_column}_lag1', 
                    f'{target_column}_lag2', 'rolling_mean_2']
    X = features_df[feature_cols]
    y = features_df[target_column]
    
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X, y)
    
    return model, feature_cols

def forecast_prices(model, feature_cols, last_data, target_column, periods=12):
    last_index = last_data.index.max()
    last_year = last_data['year'].iloc[-1]
    last_month = last_data['month'].iloc[-1]
    
    future_periods = []
    for i in range(1, periods + 1):
        new_month = (last_month + i) % 12
        if new_month == 0:
            new_month = 12
        new_year = last_year + ((last_month + i - 1) // 12)
        
        future_periods.append({
            'year': new_year,
            'month': new_month,
            'time_index': last_index + i,
            'year_fraction': new_year + (new_month - 1) / 12
        })
    
    future_df = pd.DataFrame(future_periods)
    
    # Create temp columns for prediction
    temp_cols = [col for col in feature_cols if col not in future_df.columns]
    for col in temp_cols:
        future_df[col] = 0.0
    
    # Generate predictions
    for i in range(periods):
        if i == 0:
            future_df.loc[0, f'{target_column}_lag1'] = last_data[target_column].iloc[-1]
            future_df.loc[0, f'{target_column}_lag2'] = last_data[target_column].iloc[-2]
            future_df.loc[0, 'rolling_mean_2'] = last_data[target_column].iloc[-2:].mean()
        else:
            future_df.loc[i, f'{target_column}_lag1'] = future_df.loc[i-1, target_column]
            future_df.loc[i, f'{target_column}_lag2'] = future_df.loc[i-2, target_column] if i > 1 else last_data[target_column].iloc[-1]
            future_df.loc[i, 'rolling_mean_2'] = (future_df.loc[i-1, target_column] + (future_df.loc[i-2, target_column] if i > 1 else last_data[target_column].iloc[-1])) / 2
        
        # Make prediction
        X_pred = future_df.loc[i:i, feature_cols]
        future_df.loc[i, target_column] = model.predict(X_pred)[0]
    
    # Add prediction interval
    future_df['lower_bound'] = future_df[target_column] * 0.9
    future_df['upper_bound'] = future_df[target_column] * 1.1
    
    # Drop temporary columns
    future_df = future_df.drop(columns=temp_cols)
    
    return future_df

def main():
    # Create the forecast table with proper structure
    print("Setting up forecast table...")
    setup_forecast_table()
    
    print("Loading price data...")
    price_data = load_container_price_data()
    
    if price_data.empty:
        print("No price data available")
        return
    
    print(f"Loaded {len(price_data)} price records")
    
    # Process base price
    print("\nForecasting base price...")
    price_features = create_features(price_data, 'avg_price')
    price_model, price_cols = train_model(price_features, 'avg_price')
    price_forecast = forecast_prices(price_model, price_cols, price_features, 'avg_price')
    
    # Process freight index
    print("\nForecasting freight index...")
    freight_features = create_features(price_data, 'avg_freight_index')
    freight_model, freight_cols = train_model(freight_features, 'avg_freight_index')
    freight_forecast = forecast_prices(freight_model, freight_cols, freight_features, 'avg_freight_index')
    
    # Combine forecasts
    print("\nCombining forecasts...")
    combined_forecast = price_forecast.copy()
    combined_forecast['avg_freight_index'] = freight_forecast['avg_freight_index']
    combined_forecast['freight_lower_bound'] = freight_forecast['lower_bound']
    combined_forecast['freight_upper_bound'] = freight_forecast['upper_bound']
    
    # Save to database using engine
    print("\nSaving to database...")
    engine = get_sqlalchemy_engine()
    combined_forecast.to_sql('container_price_forecast', engine, if_exists='append', index=False)
    
    print("Forecast generated successfully!")
    print("\nPrice forecast:")
    print(combined_forecast[['year', 'month', 'avg_price']])
    print("\nFreight index forecast:")
    print(combined_forecast[['year', 'month', 'avg_freight_index']])

if __name__ == "__main__":
    main()