import os
import sys
import time

# Add project root to path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(project_root)

# Import the sensitivity analysis module - update the import path as needed
from analysis.sensitivity_analysis import run_sensitivity_pipeline

def main():
    """Run the sensitivity analysis pipeline"""
    print("=" * 60)
    print("RUNNING SENSITIVITY ANALYSIS".center(60))
    print("=" * 60)
    print("This will generate data for the Sensitivity Analysis dashboard")
    print("=" * 60)
    
    start_time = time.time()
    
    # Run the sensitivity analysis
    results, summary, optimal, viable, non_viable = run_sensitivity_pipeline()
    
    # Print summary information
    print("\nSensitivity Analysis Summary:")
    print(f"Total scenarios analyzed: {len(results)}")
    print(f"Viable scenarios: {len(viable)}")
    print(f"Non-viable scenarios: {len(non_viable)}")
    
    # Print execution time
    execution_time = time.time() - start_time
    print(f"\nExecution completed in {execution_time:.2f} seconds")
    
    print("\nYou can now run the Streamlit dashboard to view the results")
    print("=" * 60)

if __name__ == "__main__":
    main()