import pandas as pd
import numpy as np
import sys
import os

# Parent directory to path to import connection module
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from connection.db_connect import query_to_dataframe, dataframe_to_sql, get_connection

def load_base_data():
    """Load base data for sensitivity analysis"""
    housing_models = query_to_dataframe("SELECT * FROM housing_models")
    return housing_models

def run_sensitivity_analysis(iterations=500):
    """
    Run Monte Carlo sensitivity analysis with varying parameters
    
    Parameters:
    - iterations: Number of simulations to run
    
    Returns:
    - DataFrame with simulation results
    """
    # Load base data
    base_data = load_base_data()
    
    # Define parameter ranges for the simulation
    param_ranges = {
        'container_price_change': (-30, 70),     # Percentage change in container prices
        'rental_income': (8000, 20000),          # Annual rental income
        'lifespan_years': (15, 40),              # Expected lifespan in years
        'maintenance_pct_trad': (0.02, 0.05),    # Maintenance percentage for traditional
        'maintenance_pct_container': (0.025, 0.06)  # Maintenance percentage for container
    }
    
    # Connect to database to use the stored procedure
    conn = get_connection()
    cursor = conn.cursor()
    
    # Initialize results list
    results = []
    
    # Run simulations
    for i in range(iterations):
        # Generate random parameters for this iteration
        params = {
            'container_price_increase': np.random.uniform(param_ranges['container_price_change'][0], 
                                                        param_ranges['container_price_change'][1]),
            'rental_income': np.random.uniform(param_ranges['rental_income'][0], 
                                             param_ranges['rental_income'][1]),
            'expected_lifespan': int(np.random.uniform(param_ranges['lifespan_years'][0], 
                                                     param_ranges['lifespan_years'][1]))
        }
        
        # Use the stored procedure for sensitivity analysis
        query = """
        SELECT * FROM analyze_housing_sensitivity(%(container_price_increase)s, %(rental_income)s, %(expected_lifespan)s)
        """
        
        cursor.execute(query, params)
        rows = cursor.fetchall()
        
        # Process results
        column_names = [desc[0] for desc in cursor.description]
        
        for row in rows:
            row_dict = dict(zip(column_names, row))
            row_dict.update({
                'iteration': i,
                'container_price_increase': params['container_price_increase'],
                'rental_income': params['rental_income'],
                'expected_lifespan': params['expected_lifespan']
            })
            results.append(row_dict)
    
    # Close cursor and connection
    cursor.close()
    conn.close()
    
    # Convert results to DataFrame
    results_df = pd.DataFrame(results)
    
    # Save results to database
    dataframe_to_sql(results_df, 'sensitivity_analysis_results', if_exists='replace')
    
    return results_df

def analyze_sensitivity_results(results_df):
    """Analyze sensitivity analysis results to find optimal scenarios"""
    # Group by model_name
    model_summary = results_df.groupby('model_name').agg({
        'annual_roi_percentage': ['mean', 'std', 'min', 'max'],
        'payback_years': ['mean', 'std', 'min', 'max']
    }).reset_index()
    
    # Flatten MultiIndex columns
    model_summary.columns = ['_'.join(col).strip('_') for col in model_summary.columns.values]
    
    # Find optimal scenarios for each model
    optimal_scenarios = {}
    
    for model in results_df['model_name'].unique():
        model_data = results_df[results_df['model_name'] == model]
        
        # Find scenario with highest ROI
        best_roi_idx = model_data['annual_roi_percentage'].idxmax()
        optimal_scenarios[f"{model}_best_roi"] = model_data.loc[best_roi_idx]
        
        # Find scenario with shortest payback
        best_payback_idx = model_data['payback_years'].idxmin()
        optimal_scenarios[f"{model}_best_payback"] = model_data.loc[best_payback_idx]
    
    # Convert to DataFrame
    optimal_df = pd.DataFrame(optimal_scenarios).T
    
    # Save to database
    dataframe_to_sql(model_summary, 'sensitivity_model_summary', if_exists='replace')
    dataframe_to_sql(optimal_df, 'sensitivity_optimal_scenarios', if_exists='replace')
    
    return model_summary, optimal_df

def run_sensitivity_pipeline():
    """Main function to run the sensitivity analysis pipeline"""
    print("Running sensitivity analysis...")
    results = run_sensitivity_analysis(iterations=500)
    
    print("Analyzing sensitivity results...")
    summary, optimal = analyze_sensitivity_results(results)
    
    print("Sensitivity analysis completed successfully!")
    print("\nModel Summary:")
    print(summary[['model_name', 'annual_roi_percentage_mean', 'payback_years_mean']])
    print("\nOptimal Scenarios (Top 5):")
    cols = ['model_name', 'annual_roi_percentage', 'payback_years', 
            'container_price_increase', 'rental_income', 'expected_lifespan']
    print(optimal[cols].head())
    
    return results, summary, optimal

if __name__ == "__main__":
    results, summary, optimal = run_sensitivity_pipeline()