import pandas as pd
import numpy as np
import sys
import os

#Parent directory to path to import connection module
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from connection.db_connect import query_to_dataframe, dataframe_to_sql

def load_cost_data():
    """Load cost data from database"""
    queries = {
        'housing_models': "SELECT * FROM housing_models",
        'cost_breakdown': "SELECT * FROM cost_breakdown",
        'cost_per_sqm': "SELECT * FROM cost_per_sqm"
    }
    
    results = {}
    for key, query in queries.items():
        results[key] = query_to_dataframe(query)
    
    return results

def calculate_cost_efficiency_metrics(cost_data):
    """Calculate cost efficiency metrics compared to traditional housing"""
    # Get traditional housing data as baseline
    traditional = cost_data['housing_models'][cost_data['housing_models']['model_name'] == 'Traditional Housing']
    
    if traditional.empty:
        print("Error: Traditional housing data not found")
        return pd.DataFrame()
    
    # Get baseline values
    baseline_cost = traditional['total_cost'].iloc[0]
    baseline_cost_per_sqm = traditional['cost_per_sqm'].iloc[0]
    
    # Calculate efficiency metrics for all models
    metrics = cost_data['housing_models'].copy()
    
    # Calculate cost savings and percentages
    metrics['cost_savings'] = baseline_cost - metrics['total_cost']
    metrics['savings_percentage'] = (metrics['cost_savings'] / baseline_cost) * 100
    metrics['percent_of_traditional'] = (metrics['total_cost'] / baseline_cost) * 100
    
    # Calculate cost per sqm metrics
    metrics['sqm_savings'] = baseline_cost_per_sqm - metrics['cost_per_sqm']
    metrics['sqm_savings_percentage'] = (metrics['sqm_savings'] / baseline_cost_per_sqm) * 100
    
    return metrics

def analyze_cost_breakdown(cost_data):
    """Analyze the cost breakdown for different housing models"""
    breakdown = cost_data['cost_breakdown'].copy()
    
    # Calculate percentages
    breakdown['materials_percentage'] = (breakdown['materials_cost'] / breakdown['total_cost']) * 100
    breakdown['labor_percentage'] = (breakdown['labor_cost'] / breakdown['total_cost']) * 100
    breakdown['finishings_percentage'] = (breakdown['finishings_cost'] / breakdown['total_cost']) * 100
    
    # Calculate comparison to traditional
    traditional = breakdown[breakdown['model_name'] == 'Traditional Housing']
    
    if not traditional.empty:
        trad_materials = traditional['materials_cost'].iloc[0]
        trad_labor = traditional['labor_cost'].iloc[0]
        trad_finishings = traditional['finishings_cost'].iloc[0]
        
        breakdown['materials_vs_trad'] = (breakdown['materials_cost'] / trad_materials) * 100
        breakdown['labor_vs_trad'] = (breakdown['labor_cost'] / trad_labor) * 100
        breakdown['finishings_vs_trad'] = (breakdown['finishings_cost'] / trad_finishings) * 100
    
    return breakdown

def run_cost_analysis():
    """Main function to run the cost analysis pipeline"""
    # Load data
    print("Loading cost data...")
    cost_data = load_cost_data()
    
    # Calculate metrics
    print("Calculating efficiency metrics...")
    efficiency_metrics = calculate_cost_efficiency_metrics(cost_data)
    
    # Analyze cost breakdown
    print("Analyzing cost breakdown...")
    breakdown_analysis = analyze_cost_breakdown(cost_data)
    
    # Save results to database
    print("Saving results to database...")
    dataframe_to_sql(efficiency_metrics, 'cost_efficiency_analysis', if_exists='replace')
    dataframe_to_sql(breakdown_analysis, 'cost_breakdown_analysis', if_exists='replace')
    
    return efficiency_metrics, breakdown_analysis

if __name__ == "__main__":
    print("Running cost analysis...")
    metrics, breakdown = run_cost_analysis()
    if not metrics.empty and not breakdown.empty:
        print("Cost analysis completed successfully!")
        print("\nEfficiency Metrics:")
        print(metrics[['model_name', 'savings_percentage', 'percent_of_traditional']])
        print("\nCost Breakdown Analysis:")
        print(breakdown[['model_name', 'materials_percentage', 'labor_percentage', 'finishings_percentage']])