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
        # Force drop the table
        cursor.execute("DROP TABLE IF EXISTS container_price_forecast")
        conn.commit()
        
        # Create the table with all required columns
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
            price_pct_change NUMERIC(10,2),
            price_lower_pct NUMERIC(10,2),
            price_upper_pct NUMERIC(10,2),
            freight_pct_change NUMERIC(10,2),
            freight_lower_pct NUMERIC(10,2),
            freight_upper_pct NUMERIC(10,2),
            cumulative_price_pct NUMERIC(10,2),
            cumulative_freight_pct NUMERIC(10,2),
            calculated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)
        conn.commit()
        print("Forecast table created successfully")
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

def calculate_percent_changes(forecast_df):
    """Calculate percent changes for both historical and forecasted values"""
    # Load historical data
    query = """
        SELECT 
            year, month, avg_price, avg_freight_index 
        FROM container_price_trends 
        ORDER BY year, month
    """
    historical_data = query_to_dataframe(query)
    
    if historical_data.empty:
        print("Warning: No historical data found")
        return forecast_df
    
    print(f"Loaded {len(historical_data)} historical data points from {historical_data['year'].min()} to {historical_data['year'].max()}")
    
    # Calculate month-over-month percent changes for historical data
    historical_data['price_pct_change'] = historical_data['avg_price'].pct_change() * 100
    historical_data['freight_pct_change'] = historical_data['avg_freight_index'].pct_change() * 100
    
    # Fill NaN values for the first row
    historical_data = historical_data.fillna({'price_pct_change': 0, 'freight_pct_change': 0})
    
    # Save historical percent changes to database
    try:
        engine = get_sqlalchemy_engine()
        historical_data.to_sql('historical_price_changes', engine, if_exists='replace', index=False)
        print(f"Saved {len(historical_data)} historical price changes to database")
    except Exception as e:
        print(f"Error saving historical price changes: {e}")
    
    # For forecast data, calculate changes from last historical point
    if len(forecast_df) > 0 and len(historical_data) > 0:
        # Get the last historical data point
        last_historical = historical_data.iloc[-1]
        latest_price = last_historical['avg_price']
        latest_freight = last_historical['avg_freight_index']
        
        # Calculate first forecast month's percent change from last historical month
        if len(forecast_df) > 0:
            forecast_df.at[0, 'price_pct_change'] = ((forecast_df.at[0, 'avg_price'] - latest_price) / latest_price) * 100
            forecast_df.at[0, 'freight_pct_change'] = ((forecast_df.at[0, 'avg_freight_index'] - latest_freight) / latest_freight) * 100
            
            # For subsequent forecast months, calculate month-over-month
            for i in range(1, len(forecast_df)):
                forecast_df.at[i, 'price_pct_change'] = ((forecast_df.at[i, 'avg_price'] - forecast_df.at[i-1, 'avg_price']) / 
                                                        forecast_df.at[i-1, 'avg_price']) * 100
                forecast_df.at[i, 'freight_pct_change'] = ((forecast_df.at[i, 'avg_freight_index'] - forecast_df.at[i-1, 'avg_freight_index']) / 
                                                         forecast_df.at[i-1, 'avg_freight_index']) * 100
                
                # Calculate bound changes
                forecast_df.at[i, 'price_lower_pct'] = ((forecast_df.at[i, 'lower_bound'] - forecast_df.at[i-1, 'lower_bound']) / 
                                                      forecast_df.at[i-1, 'lower_bound']) * 100
                forecast_df.at[i, 'price_upper_pct'] = ((forecast_df.at[i, 'upper_bound'] - forecast_df.at[i-1, 'upper_bound']) / 
                                                      forecast_df.at[i-1, 'upper_bound']) * 100
                forecast_df.at[i, 'freight_lower_pct'] = ((forecast_df.at[i, 'freight_lower_bound'] - forecast_df.at[i-1, 'freight_lower_bound']) / 
                                                        forecast_df.at[i-1, 'freight_lower_bound']) * 100
                forecast_df.at[i, 'freight_upper_pct'] = ((forecast_df.at[i, 'freight_upper_bound'] - forecast_df.at[i-1, 'freight_upper_bound']) / 
                                                        forecast_df.at[i-1, 'freight_upper_bound']) * 100
        
        # Calculate cumulative changes from the latest historical data point
        for i in range(len(forecast_df)):
            forecast_df.at[i, 'cumulative_price_pct'] = ((forecast_df.at[i, 'avg_price'] - latest_price) / latest_price) * 100
            forecast_df.at[i, 'cumulative_freight_pct'] = ((forecast_df.at[i, 'avg_freight_index'] - latest_freight) / latest_freight) * 100
    
    print(f"Historical data range: {historical_data['year'].min()}-{historical_data['year'].max()}")
    print(f"Sample historical changes:\n{historical_data[['year', 'month', 'price_pct_change', 'freight_pct_change']].head()}")
    
    return forecast_df

def main():
    # Create the forecast table with proper structure
    print("Setting up forecast table...")
    if not setup_forecast_table():
        print("Failed to set up forecast table, exiting")
        return
    
    print("Loading price data...")
    price_data = load_container_price_data()
    
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
    
    # Calculate percent changes
    print("\nCalculating percent changes...")
    combined_forecast = calculate_percent_changes(combined_forecast)
    print("\nPercent changes calculated:")
    print(combined_forecast[['year', 'month', 'price_pct_change', 'freight_pct_change']].head())
    
    #Print column names before saving   
    print(f"DataFrame columns before saving: {combined_forecast.columns.tolist()}")
    
    print("\nSaving to database...")
    engine = get_sqlalchemy_engine()
    combined_forecast.to_sql('container_price_forecast', engine, if_exists='append', index=False)

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