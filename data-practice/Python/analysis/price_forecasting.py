import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
import sys
import os

# Parent directory to path to import connection module
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from connection.db_connect import query_to_dataframe, dataframe_to_sql

def load_container_price_data():
    """Load container price data from database"""
    query = """
    SELECT * FROM container_price_trends 
    ORDER BY year, quarter
    """
    return query_to_dataframe(query)

def create_price_features(df):
    """Create features for price forecasting model"""
    # Copy to avoid modifying the original
    df_features = df.copy()
    
    # Create time-based features
    df_features['time_index'] = df_features.index
    df_features['year_fraction'] = df_features['year'] + (df_features['quarter'] - 1) / 4
    
    # Create lag features (1, 2, and 4 periods)
    df_features['avg_price_lag1'] = df_features['avg_price'].shift(1)
    df_features['avg_price_lag2'] = df_features['avg_price'].shift(2)
    df_features['avg_price_lag4'] = df_features['avg_price'].shift(4)
    
    # Create rolling mean features
    df_features['rolling_mean_2'] = df_features['avg_price'].rolling(window=2).mean()
    df_features['rolling_mean_4'] = df_features['avg_price'].rolling(window=4).mean()
    
    # Drop rows with NaN values
    df_features = df_features.dropna()
    
    return df_features

def train_price_model(features_df):
    """Train a RandomForest model to predict container prices"""
    # Define features and target
    feature_cols = ['time_index', 'year_fraction', 'avg_price_lag1', 
                   'avg_price_lag2', 'avg_price_lag4', 
                   'rolling_mean_2', 'rolling_mean_4']
    X = features_df[feature_cols]
    y = features_df['avg_price']
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Train model
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    # Evaluate model
    train_score = model.score(X_train, y_train)
    test_score = model.score(X_test, y_test)
    print(f"Model R² on training data: {train_score:.4f}")
    print(f"Model R² on test data: {test_score:.4f}")
    
    return model, feature_cols

def forecast_container_prices(model, feature_cols, last_data, periods=12):
    """Generate price forecasts for future periods"""
    # Create dataframe for future periods
    last_index = last_data.index.max()
    last_year = last_data['year'].iloc[-1]
    last_quarter = last_data['quarter'].iloc[-1]
    
    future_periods = []
    
    for i in range(1, periods + 1):
        new_quarter = (last_quarter + i) % 4
        if new_quarter == 0:
            new_quarter = 4
        new_year = last_year + ((last_quarter + i - 1) // 4)
        
        future_periods.append({
            'year': new_year,
            'quarter': new_quarter,
            'time_index': last_index + i,
            'year_fraction': new_year + (new_quarter - 1) / 4
        })
    
    future_df = pd.DataFrame(future_periods)
    
    # Generate predictions iteratively (one period at a time)
    for i in range(periods):
        if i == 0:
            # For the first prediction, use the last known values
            future_df.loc[0, 'avg_price_lag1'] = last_data['avg_price'].iloc[-1]
            future_df.loc[0, 'avg_price_lag2'] = last_data['avg_price'].iloc[-2]
            future_df.loc[0, 'avg_price_lag4'] = last_data['avg_price'].iloc[-4]
            future_df.loc[0, 'rolling_mean_2'] = last_data['avg_price'].iloc[-2:].mean()
            future_df.loc[0, 'rolling_mean_4'] = last_data['avg_price'].iloc[-4:].mean()
        else:
            # For subsequent predictions, use the previously predicted values
            lag1_idx = i - 1 if i - 1 >= 0 else None
            lag2_idx = i - 2 if i - 2 >= 0 else None
            lag4_idx = i - 4 if i - 4 >= 0 else None
            
            future_df.loc[i, 'avg_price_lag1'] = future_df.loc[lag1_idx, 'avg_price'] if lag1_idx is not None else last_data['avg_price'].iloc[-(abs(lag1_idx) + 1)]
            future_df.loc[i, 'avg_price_lag2'] = future_df.loc[lag2_idx, 'avg_price'] if lag2_idx is not None else last_data['avg_price'].iloc[-(abs(lag2_idx) + 1)]
            future_df.loc[i, 'avg_price_lag4'] = future_df.loc[lag4_idx, 'avg_price'] if lag4_idx is not None else last_data['avg_price'].iloc[-(abs(lag4_idx) + 1)]
            
            # Calculate rolling means
            if i < 2:
                values = list(last_data['avg_price'].iloc[-(2-i):]) + list(future_df.loc[:i-1, 'avg_price'])
                future_df.loc[i, 'rolling_mean_2'] = np.mean(values)
            else:
                future_df.loc[i, 'rolling_mean_2'] = future_df.loc[i-2:i-1, 'avg_price'].mean()
                
            if i < 4:
                values = list(last_data['avg_price'].iloc[-(4-i):]) + list(future_df.loc[:i-1, 'avg_price'])
                future_df.loc[i, 'rolling_mean_4'] = np.mean(values)
            else:
                future_df.loc[i, 'rolling_mean_4'] = future_df.loc[i-4:i-1, 'avg_price'].mean()
        
        # Make prediction for this period
        X_pred = future_df.loc[i:i, feature_cols]
        future_df.loc[i, 'avg_price'] = model.predict(X_pred)[0]
    
    # Add prediction interval (simplified approach)
    future_df['lower_bound'] = future_df['avg_price'] * 0.9
    future_df['upper_bound'] = future_df['avg_price'] * 1.1
    
    return future_df

def run_price_forecasting():
    """Main function to run the price forecasting pipeline"""
    # Load data
    print("Loading container price data...")
    price_data = load_container_price_data()
    
    if price_data.empty:
        print("Error: No price data available")
        return None
    
    # Create features
    print("Creating features...")
    features_df = create_price_features(price_data)
    
    # Train model
    print("Training model...")
    model, feature_cols = train_price_model(features_df)
    
    # Generate forecast
    print("Generating forecast...")
    forecast = forecast_container_prices(model, feature_cols, features_df, periods=8)
    
    # Save forecast to database
    print("Saving forecast to database...")
    dataframe_to_sql(forecast, 'container_price_forecast', if_exists='replace')
    
    return forecast

if __name__ == "__main__":
    print("Running container price forecasting...")
    forecast_result = run_price_forecasting()
    if forecast_result is not None:
        print("Forecasting completed successfully!")
        print(forecast_result)