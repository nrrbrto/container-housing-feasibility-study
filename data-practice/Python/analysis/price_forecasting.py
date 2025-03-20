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

def create_price_features(df, target_column):
    """Create features for price forecasting model"""
    # Copy to avoid modifying the original
    df_features = df.copy()
    
    # Create time-based features
    df_features['time_index'] = df_features.index
    df_features['year_fraction'] = df_features['year'] + (df_features['quarter'] - 1) / 4
    
    # Create lag features (1, 2, and 4 periods)
    df_features[f'{target_column}_lag1'] = df_features[target_column].shift(1)
    df_features[f'{target_column}_lag2'] = df_features[target_column].shift(2)
    df_features[f'{target_column}_lag4'] = df_features[target_column].shift(4)
    
    # Create rolling mean features
    df_features[f'rolling_mean_2'] = df_features[target_column].rolling(window=2).mean()
    df_features[f'rolling_mean_4'] = df_features[target_column].rolling(window=4).mean()
    
    # Drop rows with NaN values
    df_features = df_features.dropna()
    
    return df_features

def train_price_model(features_df, target_column):
    """Train a RandomForest model to predict container prices"""
    # Define features and target
    feature_cols = ['time_index', 'year_fraction', 
                   f'{target_column}_lag1', 
                   f'{target_column}_lag2', 
                   f'{target_column}_lag4', 
                   'rolling_mean_2', 'rolling_mean_4']
    X = features_df[feature_cols]
    y = features_df[target_column]
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Train model
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    # Evaluate model
    train_score = model.score(X_train, y_train)
    test_score = model.score(X_test, y_test)
    print(f"{target_column} Model R² on training data: {train_score:.4f}")
    print(f"{target_column} Model R² on test data: {test_score:.4f}")
    
    return model, feature_cols

def forecast_container_prices(model, feature_cols, last_data, target_column, periods=12):
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
            future_df.loc[0, f'{target_column}_lag1'] = last_data[target_column].iloc[-1]
            future_df.loc[0, f'{target_column}_lag2'] = last_data[target_column].iloc[-2]
            future_df.loc[0, f'{target_column}_lag4'] = last_data[target_column].iloc[-4]
            future_df.loc[0, 'rolling_mean_2'] = last_data[target_column].iloc[-2:].mean()
            future_df.loc[0, 'rolling_mean_4'] = last_data[target_column].iloc[-4:].mean()
        else:
            # For subsequent predictions, use the previously predicted values
            lag1_idx = i - 1 if i - 1 >= 0 else None
            lag2_idx = i - 2 if i - 2 >= 0 else None
            lag4_idx = i - 4 if i - 4 >= 0 else None
            
            future_df.loc[i, f'{target_column}_lag1'] = future_df.loc[lag1_idx, target_column] if lag1_idx is not None else last_data[target_column].iloc[-(abs(lag1_idx) + 1)]
            future_df.loc[i, f'{target_column}_lag2'] = future_df.loc[lag2_idx, target_column] if lag2_idx is not None else last_data[target_column].iloc[-(abs(lag2_idx) + 1)]
            future_df.loc[i, f'{target_column}_lag4'] = future_df.loc[lag4_idx, target_column] if lag4_idx is not None else last_data[target_column].iloc[-(abs(lag4_idx) + 1)]
            
            # Calculate rolling means
            if i < 2:
                values = list(last_data[target_column].iloc[-(2-i):]) + list(future_df.loc[:i-1, target_column])
                future_df.loc[i, 'rolling_mean_2'] = np.mean(values)
            else:
                future_df.loc[i, 'rolling_mean_2'] = future_df.loc[i-2:i-1, target_column].mean()
                
            if i < 4:
                values = list(last_data[target_column].iloc[-(4-i):]) + list(future_df.loc[:i-1, target_column])
                future_df.loc[i, 'rolling_mean_4'] = np.mean(values)
            else:
                future_df.loc[i, 'rolling_mean_4'] = future_df.loc[i-4:i-1, target_column].mean()
        
        # Make prediction for this period
        X_pred = future_df.loc[i:i, feature_cols]
        future_df.loc[i, target_column] = model.predict(X_pred)[0]
    
    # Add prediction interval (simplified approach)
    future_df['lower_bound'] = future_df[target_column] * 0.9
    future_df['upper_bound'] = future_df[target_column] * 1.1
    
    return future_df

def run_price_forecasting():
    """Main function to run the price forecasting pipeline for both price and freight index"""
    # Load data
    print("Loading container price data...")
    price_data = load_container_price_data()
    
    if price_data.empty:
        print("Error: No price data available")
        return None, None
    
    forecasts = {}
    
    # Process price forecast
    print("\nProcessing base price forecasting...")
    # Create features for base price
    price_features_df = create_price_features(price_data, 'avg_price')
    
    # Train base price model
    price_model, price_feature_cols = train_price_model(price_features_df, 'avg_price')
    
    # Generate base price forecast
    price_forecast = forecast_container_prices(price_model, price_feature_cols, price_features_df, 'avg_price', periods=8)
    forecasts['price'] = price_forecast
    
    # Process freight index forecast
    print("\nProcessing freight index forecasting...")
    # Create features for freight index
    freight_features_df = create_price_features(price_data, 'avg_freight_index')
    
    # Train freight index model
    freight_model, freight_feature_cols = train_price_model(freight_features_df, 'avg_freight_index')
    
    # Generate freight index forecast
    freight_forecast = forecast_container_prices(freight_model, freight_feature_cols, freight_features_df, 'avg_freight_index', periods=8)
    forecasts['freight'] = freight_forecast
    
    # Combine forecasts for storage
    combined_forecast = price_forecast.copy()
    combined_forecast['avg_freight_index'] = freight_forecast['avg_freight_index']
    combined_forecast['freight_lower_bound'] = freight_forecast['lower_bound']
    combined_forecast['freight_upper_bound'] = freight_forecast['upper_bound']
    
    # Save combined forecast to database
    print("Saving forecast to database...")
    dataframe_to_sql(combined_forecast, 'container_price_forecast', if_exists='replace')
    
    return forecasts

if __name__ == "__main__":
    print("Running container price forecasting...")
    forecast_results = run_price_forecasting()
    if forecast_results is not None:
        print("Forecasting completed successfully!")
        print("\nPrice forecast summary:")
        print(forecast_results['price'][['year', 'quarter', 'avg_price']])
        print("\nFreight index forecast summary:")
        print(forecast_results['freight'][['year', 'quarter', 'avg_freight_index']])