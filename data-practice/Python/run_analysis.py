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

# Now use relative imports for analysis modules
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
    
    # Step 3: Run sensitivity analysis
    print("-" * 80)
    print("STEP 3: SENSITIVITY ANALYSIS".center(80))
    print("-" * 80)
    
    # Unpack all five returned values
    results, summary, optimal, viable, non_viable = run_sensitivity_pipeline()
    
    # If you only need the first three values, use:
    # results, summary, optimal, _, _ = run_sensitivity_pipeline()
    
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