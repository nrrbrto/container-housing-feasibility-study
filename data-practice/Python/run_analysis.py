import os
import sys
import time

# Dynamically determine the project root directory
project_root = os.path.abspath(os.path.dirname(__file__))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

# Add parent directories to path
parent_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
if root_dir not in sys.path:
    sys.path.insert(0, root_dir)

print("Updated Python Path:", sys.path)

# Relative imports for analysis modules
from analysis.price_forecasting import run_price_forecasting
from analysis.cost_analysis import run_cost_analysis
from analysis.sensitivity_analysis import run_sensitivity_pipeline

# Import from root connection module
from connection.db_connect import query_to_dataframe, dataframe_to_sql

def main():
    """Run all analysis pipelines"""
    start_time = time.time()
    
    print("=" * 80)
    print("CONTAINER HOUSING FEASIBILITY ANALYSIS".center(80))
    print("=" * 80)
    print()
    
    # Step 1: Run price forecasting
    print("-" * 80)
    print("STEP 1: PRICE FORECASTING".center(80))
    print("-" * 80)
    
    forecast_results = run_price_forecasting()
    
    if forecast_results is not None:
        print("\nPrice forecasting completed successfully!")
        try:
            # Simply display key forecast information
            print("\nPrice forecast summary:")
            if 'price' in forecast_results:
                print(forecast_results['price'][['year', 'month', 'avg_price']].head())
            
            print("\nFreight index forecast summary:")
            if 'freight' in forecast_results:
                print(forecast_results['freight'][['year', 'month', 'avg_freight_index']].head())
        except Exception as e:
            print(f"Error displaying forecast results: {e}")
    else:
        print("Price forecasting failed or returned no results")
    
    # Step 2: Run cost analysis
    print("\n" + "-" * 80)
    print("STEP 2: COST ANALYSIS".center(80))
    print("-" * 80)
    
    metrics, breakdown = run_cost_analysis()
    
    # Simple output of results
    if metrics is not None and not metrics.empty and breakdown is not None and not breakdown.empty:
        print("\nCost analysis completed successfully!")
        print("\nCost Efficiency Metrics:")
        print(metrics[['model_name', 'savings_percentage', 'percent_of_traditional']] 
              if all(col in metrics.columns for col in ['model_name', 'savings_percentage', 'percent_of_traditional']) 
              else metrics.head())
        
        print("\nCost Breakdown Analysis:")
        print(breakdown[['model_name', 'materials_percentage', 'labor_percentage', 'finishings_percentage']]
              if all(col in breakdown.columns for col in ['model_name', 'materials_percentage', 'labor_percentage', 'finishings_percentage'])
              else breakdown.head())
    else:
        print("Cost analysis failed or returned incomplete results")
    
    # Step 3: Run sensitivity analysis
    print("\n" + "-" * 80)
    print("STEP 3: SENSITIVITY ANALYSIS".center(80))
    print("-" * 80)
    
    # Unpack all five returned values
    results, summary, optimal, viable, non_viable = run_sensitivity_pipeline()
    
    print("\nSensitivity analysis completed.")
    print(f"Results: {len(results)} total records")
    print(f"Viable: {len(viable)} records")
    print(f"Non-viable: {len(non_viable)} records")
    
    print("\nModel Summary:")
    print(summary)
    
    print("\nOptimal Scenarios:")
    print(optimal.head())
    
    # Print execution summary
    print("=" * 80)
    print("ANALYSIS COMPLETE".center(80))
    print(f"Total execution time: {time.time() - start_time:.2f} seconds".center(80))
    print("=" * 80)

if __name__ == "__main__":
    main()