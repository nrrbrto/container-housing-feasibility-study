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

param_ranges = {
    'container_price_change': (-5, 5),        # Updated range including negative values
    'rental_income': {
        'low': (15460, 16000),                # Annual for low income
        'middle': (30000, 31000),             # Annual for middle income
        'upper': (59000, 60000)               # Annual for upper income
    },
    'lifespan_years_trad': (80, 150),         # For traditional housing per Krull's research
    'lifespan_years_container': (40, 150),    # For container housing per Krull's research
    'maintenance_pct_trad': (0.01, 0.03),     # For traditional housing
    'maintenance_pct_container': (0.008, 0.025), # For container housing
    'interest_subsidy_pct': (3, 5),           # Government interest rate subsidy
    'govt_subsidy_percentage': (15, 30),      # Initial cost subsidy percentage
    # ROI target ranges based on real estate investment standards
    'roi_ranges': {
        'minimum_acceptable': 6,    # Minimum acceptable ROI
        'good_target': 10,          # Good target ROI
        'excellent_target': 15      # Excellent target ROI
    },
    # Payback period expectations based on industry standards
    'max_payback_years': 30         # Maximum acceptable payback threshold
}

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
    
    if base_data.empty:
        print("Error: Housing models data not found")
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()
    
    # Initialize results list
    results = []
    viable_results = []
    non_viable_results = []
    
    # Run simulations
    for i in range(iterations):
        # Choose income segment (low or middle)
        income_segment = np.random.choice(['low', 'middle'])
        
        # Generate random parameters for this iteration
        params = {
            'container_price_increase': np.random.uniform(param_ranges['container_price_change'][0], 
                                                     param_ranges['container_price_change'][1]),
            'rental_income': np.random.uniform(param_ranges['rental_income'][income_segment][0], 
                                           param_ranges['rental_income'][income_segment][1]),
            # Choose appropriate lifespan range based on income segment
            'expected_lifespan': None,      
            'maintenance_pct_trad': np.random.uniform(param_ranges['maintenance_pct_trad'][0],
                                                  param_ranges['maintenance_pct_trad'][1]),
            'maintenance_pct_container': np.random.uniform(param_ranges['maintenance_pct_container'][0],
                                                       param_ranges['maintenance_pct_container'][1]),
            'income_segment': income_segment
        }
        
        # Process each housing model
        for _, model in base_data.iterrows():
            # Select appropriate lifespan range based on housing type
            lifespan_range = param_ranges['lifespan_years_trad'] if model['model_name'] == 'Traditional Housing' else param_ranges['lifespan_years_container']
            
            # Generate expected lifespan for this model
            if model['model_name'] == 'Traditional Housing':
                model_lifespan = int(np.random.uniform(param_ranges['lifespan_years_trad'][0], 
                                                    param_ranges['lifespan_years_trad'][1]))
            else:
                model_lifespan = int(np.random.uniform(param_ranges['lifespan_years_container'][0], 
                                                    param_ranges['lifespan_years_container'][1]))
                
            # Override the placeholder value
            params['expected_lifespan'] = model_lifespan
            
            # Adjust investment based on container price change
            adjusted_investment = model['total_cost']
            if 'Container' in model['model_name']:
                adjusted_investment = model['total_cost'] * (1 + params['container_price_increase']/100)
            
            # Apply government subsidy to initial cost
            subsidy_pct = np.random.uniform(param_ranges['govt_subsidy_percentage'][0], 
                                        param_ranges['govt_subsidy_percentage'][1])
            adjusted_investment = adjusted_investment * (1 - subsidy_pct/100)
            
            # Set maintenance percentage based on model type
            maintenance_pct = params['maintenance_pct_trad'] if model['model_name'] == 'Traditional Housing' else params['maintenance_pct_container']
            
            # Calculate annual maintenance cost
            annual_maintenance = adjusted_investment * maintenance_pct
            
            # Calculate annual net income
            annual_net_income = params['rental_income'] - annual_maintenance
            
            # Apply interest rate subsidy for improved ROI calculation
            interest_subsidy = np.random.uniform(param_ranges['interest_subsidy_pct'][0],
                                            param_ranges['interest_subsidy_pct'][1])
            
            # Calculate payback period and ROI
            if annual_net_income > 0:
                payback_years = adjusted_investment / annual_net_income
                # Cap payback years to avoid infinity issues
                payback_years = min(payback_years, 100)
                annual_roi_percentage = (annual_net_income / adjusted_investment) * 100
            else:
                payback_years = 100  # Use a large but finite number
                annual_roi_percentage = 0
            
            # Create result dictionary
            result = {
                'model_name': model['model_name'],
                'adjusted_investment': adjusted_investment,
                'annual_maintenance': annual_maintenance,
                'annual_net_income': annual_net_income,
                'payback_years': payback_years,
                'annual_roi_percentage': annual_roi_percentage,
                'container_price_increase': params['container_price_increase'],
                'rental_income': params['rental_income'],
                'expected_lifespan': params['expected_lifespan'],
                'maintenance_pct': maintenance_pct,
                'income_segment': params['income_segment'],
                'iteration': i
            }
            
            # Add to appropriate list
            if annual_net_income <= 0 or annual_roi_percentage <= 0:
                result['viability_issue'] = "Negative cash flow" if annual_net_income <= 0 else "Negative ROI"
                non_viable_results.append(result)
            else:
                viable_results.append(result)
            
            # Add to main results list
            results.append(result)
    
    # Convert to DataFrames
    results_df = pd.DataFrame(results)
    viable_df = pd.DataFrame(viable_results) if viable_results else pd.DataFrame()
    non_viable_df = pd.DataFrame(non_viable_results) if non_viable_results else pd.DataFrame()
    
    # Save results to database
    try:
        print(f"Saving {len(results)} total records to database")
        dataframe_to_sql(results_df, 'sensitivity_analysis_results', if_exists='replace')
        
        if not viable_df.empty:
            print(f"Saving {len(viable_df)} viable records to database")
            dataframe_to_sql(viable_df, 'sensitivity_analysis_viable', if_exists='replace')
        
        if not non_viable_df.empty:
            print(f"Saving {len(non_viable_df)} non-viable records to database")
            dataframe_to_sql(non_viable_df, 'sensitivity_analysis_non_viable', if_exists='replace')
    except Exception as e:
        print(f"Error saving results to database: {e}")
    
    return results_df, viable_df, non_viable_df

def analyze_sensitivity_results(results_df):
    """Analyze sensitivity analysis results to find optimal scenarios"""
    if results_df.empty:
        print("Error: No results to analyze")
        return pd.DataFrame(), pd.DataFrame()
    
    # Filter out any invalid values before analysis
    valid_results = results_df[
        (results_df['annual_roi_percentage'] > 0) & 
        (results_df['payback_years'] > 0) &
        (results_df['payback_years'] < 100)  # Exclude extremely high payback periods
    ].copy()
    
    if valid_results.empty:
        print("Warning: No valid scenarios for analysis")
        return pd.DataFrame(), pd.DataFrame()
    
    # Group by model_name
    model_summary = valid_results.groupby('model_name').agg({
        'annual_roi_percentage': ['mean', 'std', 'min', 'max'],
        'payback_years': ['mean', 'std', 'min', 'max']
    }).reset_index()
    
    # Flatten MultiIndex columns
    model_summary.columns = ['_'.join(col).strip('_') for col in model_summary.columns.values]
    
    # Add ROI classification in the model summary
    model_summary['roi_classification'] = pd.cut(
        model_summary['annual_roi_percentage_mean'],
        bins=[-float('inf'), param_ranges['roi_ranges']['minimum_acceptable'], 
            param_ranges['roi_ranges']['good_target'], 
            param_ranges['roi_ranges']['excellent_target'], float('inf')],
        labels=['Poor', 'Acceptable', 'Good', 'Excellent']
    )
    
    # Add payback feasibility based on lifespan
    for idx, row in model_summary.iterrows():
        model_name = row['model_name']
        avg_payback = row['payback_years_mean']
        min_lifespan = param_ranges['lifespan_years_trad'][0] if model_name == 'Traditional Housing' else param_ranges['lifespan_years_container'][0]
        
        # Determine if payback period is feasible given the minimum lifespan
        model_summary.at[idx, 'payback_feasibility'] = 'Viable' if avg_payback < min_lifespan else 'Not Viable'
    
    # Find optimal scenarios for each model
    optimal_scenarios = {}
    
    for model in valid_results['model_name'].unique():
        model_data = valid_results[valid_results['model_name'] == model]
        
        if not model_data.empty:
            # Find scenario with highest ROI
            best_roi_idx = model_data['annual_roi_percentage'].idxmax()
            optimal_scenarios[f"{model}_best_roi"] = model_data.loc[best_roi_idx]
            
            # Find scenario with shortest payback
            best_payback_idx = model_data['payback_years'].idxmin()
            optimal_scenarios[f"{model}_best_payback"] = model_data.loc[best_payback_idx]
    
    # Convert to DataFrame
    optimal_df = pd.DataFrame(optimal_scenarios).T if optimal_scenarios else pd.DataFrame()
    
    # Save to database
    try:
        dataframe_to_sql(model_summary, 'sensitivity_model_summary', if_exists='replace')
        
        if not optimal_df.empty:
            dataframe_to_sql(optimal_df, 'sensitivity_optimal_scenarios', if_exists='replace')
    except Exception as e:
        print(f"Error saving analysis results to database: {e}")
    
    return model_summary, optimal_df

def run_sensitivity_pipeline():
    """Main function to run the sensitivity analysis pipeline"""
    print("Running sensitivity analysis...")
    
    # Run sensitivity analysis
    try:
        results, viable, non_viable = run_sensitivity_analysis(iterations=500)
    except Exception as e:
        print(f"Error during sensitivity analysis: {e}")
        return None, None, None, None, None
    
    # Analyze sensitivity results
    try:
        print("Analyzing sensitivity results...")
        summary, optimal = analyze_sensitivity_results(results)
    except Exception as e:
        print(f"Error during sensitivity results analysis: {e}")
        return results, None, None, viable, non_viable
    
    print("Sensitivity analysis completed successfully!")

    # Print model summary
    if summary is not None and not summary.empty:
        print("\nModel Summary:")
        summary_cols = ['model_name', 'annual_roi_percentage_mean', 'payback_years_mean']
        if all(col in summary.columns for col in summary_cols):
            print(summary[summary_cols])
        else:
            print("Warning: Not all expected columns are in the summary dataframe")
    else:
        print("Warning: No summary data available.")

    # Print optimal scenarios
    if optimal is not None and not optimal.empty:
        print("\nOptimal Scenarios (Top 5):")
        optimal_cols = ['model_name', 'annual_roi_percentage', 'payback_years', 
                        'container_price_increase', 'rental_income', 'expected_lifespan']
        if all(col in optimal.columns for col in optimal_cols):
            print(optimal[optimal_cols].head())
        else:
            print("Warning: Not all expected columns are in the optimal scenarios dataframe")
    else:
        print("Warning: No optimal scenarios data available.")

    # Return all results
    return results, summary, optimal, viable, non_viable

if __name__ == "__main__":
    results, summary, optimal, viable, non_viable = run_sensitivity_pipeline()  