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
    ORDER BY year, month
    """
    return query_to_dataframe(query)

def create_price_features(df, target_column):
    """Create features for price forecasting model"""
    # Copy to avoid modifying the original
    df_features = df.copy()
    
    # Create time-based features
    df_features['time_index'] = df_features.index
    df_features['year_fraction'] = df_features['year'] + (df_features['month'] - 1) / 12
    
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
            # Fix the lag index handling to avoid None values
            lag1_idx = max(0, i - 1)  # Use max to ensure it's never negative
            lag2_idx = max(0, i - 2)
            lag4_idx = max(0, i - 4)
            
            # For lag1
            if i >= 1:
                future_df.loc[i, f'{target_column}_lag1'] = future_df.loc[i-1, target_column]
            else:
                future_df.loc[i, f'{target_column}_lag1'] = last_data[target_column].iloc[-1]
            
            # For lag2
            if i >= 2:
                future_df.loc[i, f'{target_column}_lag2'] = future_df.loc[i-2, target_column]
            else:
                future_df.loc[i, f'{target_column}_lag2'] = last_data[target_column].iloc[-(2-i)]
            
            # For lag4
            if i >= 4:
                future_df.loc[i, f'{target_column}_lag4'] = future_df.loc[i-4, target_column]
            else:
                future_df.loc[i, f'{target_column}_lag4'] = last_data[target_column].iloc[-(4-i)]
            
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

def calculate_percent_changes(forecast_df, price_data, target_column):
    """Calculate percentage changes for historical and forecasted data"""
    try:
        # Calculate month-over-month percent changes for original data
        price_data[f'{target_column}_pct_change'] = price_data[target_column].pct_change() * 100
        # Rename columns for consistency with dashboard
        if target_column == 'avg_price':
            price_data.rename(columns={
                'avg_price_pct_change': 'price_pct_change'
            }, inplace=True)
        elif target_column == 'avg_freight_index':
            price_data.rename(columns={
                'avg_freight_index_pct_change': 'freight_pct_change'
            }, inplace=True)
        
        # Calculate changes for the first forecast period
        if len(forecast_df) > 0 and len(price_data) > 0:
            # Get last historical data point
            last_historical = price_data.iloc[-1]
            latest_value = last_historical[target_column]
            
            # Calculate first forecast period's change from last historical
            first_forecast_value = forecast_df.iloc[0][target_column]
            first_pct_change = ((first_forecast_value - latest_value) / latest_value) * 100
            forecast_df.loc[0, f'{target_column}_pct_change'] = first_pct_change
            
            # Calculate month-over-month changes for subsequent periods
            for i in range(1, len(forecast_df)):
                current = forecast_df.iloc[i][target_column]
                previous = forecast_df.iloc[i-1][target_column]
                pct_change = ((current - previous) / previous) * 100
                forecast_df.loc[i, f'{target_column}_pct_change'] = pct_change
            
            # Calculate cumulative change from last historical value
            for i in range(len(forecast_df)):
                current = forecast_df.iloc[i][target_column]
                cumulative_pct = ((current - latest_value) / latest_value) * 100
                forecast_df.loc[i, f'cumulative_{target_column}_pct'] = cumulative_pct
                
            # Calculate changes for bound values
            for i in range(1, len(forecast_df)):
                # Lower bound
                current_lower = forecast_df.iloc[i]['lower_bound']
                previous_lower = forecast_df.iloc[i-1]['lower_bound']
                lower_pct = ((current_lower - previous_lower) / previous_lower) * 100
                forecast_df.loc[i, f'{target_column}_lower_pct'] = lower_pct
                
                # Upper bound
                current_upper = forecast_df.iloc[i]['upper_bound']
                previous_upper = forecast_df.iloc[i-1]['upper_bound']
                upper_pct = ((current_upper - previous_upper) / previous_upper) * 100
                forecast_df.loc[i, f'{target_column}_upper_pct'] = upper_pct
            
            # First period's bound changes initialized to 0
            forecast_df.loc[0, f'{target_column}_lower_pct'] = 0
            forecast_df.loc[0, f'{target_column}_upper_pct'] = 0
        
                # Save historical percent changes
        try:
            # Keep the original column name instead of renaming
            change_col_name = f'{target_column}_pct_change'
            
            # Create a copy of the data without renaming columns
            historical_data = price_data.copy()
            
            # Print original and target column names for clarity
            print(f"Original column: {target_column}_pct_change, Target column: {change_col_name}")
            
            # Rename columns for consistency with dashboard
            if target_column == 'avg_price':
                historical_data.rename(columns={
                    f'{target_column}_pct_change': 'price_pct_change'
                }, inplace=True)
            elif target_column == 'avg_freight_index':
                historical_data.rename(columns={
                    f'{target_column}_pct_change': 'freight_pct_change'
                }, inplace=True)
            
            # Debugging: Print the first few rows of the historical data after renaming
            print(f"Historical data preview after renaming for {target_column}:")
            print(historical_data.head())
            
            # Save historical changes data to database
            dataframe_to_sql(historical_data, 'historical_price_changes', if_exists='replace')
            print(f"Saved historical {target_column} changes to database")
        except Exception as e:
            print(f"Error saving historical changes: {e}")
    
    except Exception as e:
        print(f"Error calculating percent changes: {e}")
    
    return forecast_df

def run_price_forecasting():
    """Main function to run the price forecasting pipeline for both price and freight index"""
    # Load data
    print("Loading container price data...")
    try:
        price_data = load_container_price_data()
        
        if price_data.empty:
            print("Error: No price data available")
            return None
        
        print(f"Loaded data with columns: {price_data.columns.tolist()}")
        print(f"Data range: {price_data['year'].min()}-{price_data['year'].max()}")
        
    except Exception as e:
        print(f"Error loading data: {e}")
        return None
    
    forecasts = {}
    
    # Process price forecast
    print("\nProcessing base price forecasting...")
    # Create features for base price
    price_features_df = create_price_features(price_data, 'avg_price')
    
    # Train base price model
    price_model, price_feature_cols = train_price_model(price_features_df, 'avg_price')
    
    # Generate base price forecast
    price_forecast = forecast_container_prices(price_model, price_feature_cols, price_features_df, 'avg_price', periods=12)
    
    # Calculate percent changes for price forecast
    print("\nCalculating price percentage changes...")
    price_forecast = calculate_percent_changes(price_forecast, price_data, 'avg_price')
    forecasts['price'] = price_forecast
    
    # Process freight index forecast
    print("\nProcessing freight index forecasting...")
    # Create features for freight index
    freight_features_df = create_price_features(price_data, 'avg_freight_index')
    
    # Train freight index model
    freight_model, freight_feature_cols = train_price_model(freight_features_df, 'avg_freight_index')
    
    # Generate freight index forecast
    freight_forecast = forecast_container_prices(freight_model, freight_feature_cols, freight_features_df, 'avg_freight_index', periods=12)
    
    # Calculate percent changes for freight forecast
    print("\nCalculating freight percentage changes...")
    freight_forecast = calculate_percent_changes(freight_forecast, price_data, 'avg_freight_index')
    forecasts['freight'] = freight_forecast
    
    # Combine forecasts for storage
    combined_forecast = price_forecast.copy()
    combined_forecast['avg_freight_index'] = freight_forecast['avg_freight_index']
    combined_forecast['freight_lower_bound'] = freight_forecast['lower_bound']
    combined_forecast['freight_upper_bound'] = freight_forecast['upper_bound']
    # Use the actual column names from the freight_forecast DataFrame
    combined_forecast['freight_pct_change'] = freight_forecast['avg_freight_index_pct_change']
    combined_forecast['freight_lower_pct'] = freight_forecast['avg_freight_index_lower_pct']
    combined_forecast['freight_upper_pct'] = freight_forecast['avg_freight_index_upper_pct']
    combined_forecast['cumulative_freight_pct'] = freight_forecast['cumulative_avg_freight_index_pct']

    # Rename columns for consistency
    combined_forecast.rename(columns={
        'avg_price_pct_change': 'price_pct_change',
        'avg_price_lower_pct': 'price_lower_pct',
        'avg_price_upper_pct': 'price_upper_pct',
        'cumulative_avg_price_pct': 'cumulative_price_pct'
    }, inplace=True)
    
    # Print summary of percent changes
    print("\nPercent changes calculated:")
    print(combined_forecast[['year', 'month', 'price_pct_change', 'freight_pct_change']].head())
    
    # Print column names before saving
    print(f"DataFrame columns before saving: {combined_forecast.columns.tolist()}")
    
    # Save combined forecast to database
    print("\nSaving to database...")
    try:
        dataframe_to_sql(combined_forecast, 'container_price_forecast', if_exists='replace')
        print("Forecast saved successfully")
    except Exception as e:
        print(f"Error saving forecast: {e}")
    
    return forecasts

if __name__ == "__main__":
    print("Running container price forecasting...")
    forecast_results = run_price_forecasting()
    if forecast_results is not None:
        print("Forecasting completed successfully!")
        try:
            print("\nPrice forecast summary:")
            print(forecast_results['price'][['year', 'month', 'avg_price', 'avg_price_pct_change']].head())
            print("\nFreight index forecast summary:")
            print(forecast_results['freight'][['year', 'month', 'avg_freight_index', 'avg_freight_index_pct_change']].head())
        except Exception as e:
            print(f"Error printing summary: {e}")
    else:
        print("Price forecasting failed")