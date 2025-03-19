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