# Python/run_analysis.py

"""
Run the complete container housing analysis pipeline.
This script executes all analysis modules in sequence.
"""

import os
import sys
import time

# Add the project root to the Python path
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.append(project_root)

# Now use absolute imports from the project root
from analysis.price_forecasting import run_price_forecasting
from analysis.cost_analysis import run_cost_analysis
from analysis.sensitivity_analysis import run_sensitivity_pipeline

def main():
    """Run all analysis pipelines"""
    start_time = time.time()
    
    print("=" * 80)
    print("CONTAINER HOUSING FEASIBILITY ANALYSIS".center(80))
    print("=" * 80)
    print()
    
    # Step 1: Run price forecasting
    print("-" * 80)
    print("STEP 1: CONTAINER PRICE FORECASTING".center(80))
    print("-" * 80)
    forecast = run_price_forecasting()
    print()
    
    # Step 2: Run cost analysis
    print("-" * 80)
    print("STEP 2: COST ANALYSIS".center(80))
    print("-" * 80)
    metrics, breakdown = run_cost_analysis()
    print()
    
    # Step 3: Run sensitivity analysis
    print("-" * 80)
    print("STEP 3: SENSITIVITY ANALYSIS".center(80))
    print("-" * 80)
    results, summary, optimal = run_sensitivity_pipeline()
    print()
    
    # Print execution summary
    print("=" * 80)
    print("ANALYSIS COMPLETE".center(80))
    print(f"Total execution time: {time.time() - start_time:.2f} seconds".center(80))
    print("=" * 80)

if __name__ == "__main__":
    main()

# Python/run_dashboard.py

"""
Run the Streamlit dashboard for visualizing container housing analysis.
"""

import os
import subprocess
import sys

def run_dashboard():
    """
    Run the Streamlit dashboard application.
    
    This function executes the Streamlit command to run the dashboard.
    The dashboard will be available at http://localhost:8501.
    """
    # Get the path to the dashboard app.py file
    project_root = os.path.dirname(os.path.abspath(__file__))
    dashboard_path = os.path.join(project_root, "dashboard", "app.py")
    
    # Check if the dashboard file exists
    if not os.path.exists(dashboard_path):
        print(f"Error: Dashboard file not found at {dashboard_path}")
        return False
    
    print("=" * 80)
    print("STARTING CONTAINER HOUSING DASHBOARD".center(80))
    print("=" * 80)
    print(f"\nDashboard file: {dashboard_path}")
    print("\nThe dashboard will be available at http://localhost:8501")
    print("\nPress Ctrl+C to stop the dashboard")
    print("=" * 80)
    
    # Run the Streamlit command
    try:
        subprocess.run(["streamlit", "run", dashboard_path], check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error running Streamlit: {e}")
        return False
    except KeyboardInterrupt:
        print("\nDashboard stopped by user")
        return True

if __name__ == "__main__":
    run_dashboard()