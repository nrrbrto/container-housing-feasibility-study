import os
import sys
import pandas as pd
import time

# Import analysis modules
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.append(project_root)

# Absolute imports from the project root
from analysis.price_forecasting import run_price_forecasting
from analysis.cost_analysis import run_cost_analysis
from analysis.sensitivity_analysis import run_sensitivity_pipeline

def main():
    """Run all analysis pipelines"""
    start_time = time.time()
    
    print("=" * 50)
    print("CONTAINER HOUSING FEASIBILITY ANALYSIS")
    print("=" * 50)
    print()
    
    # Run price forecasting
    print("-" * 50)
    print("STEP 1: CONTAINER PRICE FORECASTING")
    print("-" * 50)
    forecast = run_price_forecasting()
    print()
    
    # Run cost analysis
    print("-" * 50)
    print("STEP 2: COST ANALYSIS")
    print("-" * 50)
    metrics, breakdown = run_cost_analysis()
    print()
    
    # Run sensitivity analysis
    print("-" * 50)
    print("STEP 3: SENSITIVITY ANALYSIS")
    print("-" * 50)
    results, summary, optimal = run_sensitivity_pipeline()
    print()
    
    # Print summary of results
    print("=" * 50)
    print("ANALYSIS SUMMARY")
    print("=" * 50)
    
    print("\nPrice Forecast (Next 12 months):")
    if forecast is not None:
        print(forecast[['year', 'month', 'avg_price']].head(4))
    
    print("\nCost Efficiency (% Savings vs Traditional):")
    if metrics is not None:
        print(metrics[['model_name', 'savings_percentage']].sort_values('savings_percentage', ascending=False))
    
    print("\nROI Analysis (Average across Scenarios):")
    if summary is not None:
        print(summary[['model_name', 'annual_roi_percentage_mean', 'payback_years_mean']])
    
    print("\nAnalysis completed in {:.2f} seconds".format(time.time() - start_time))
    print("=" * 50)

if __name__ == "__main__":
    main()