import os
import subprocess
import sys

def run_dashboard():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    dashboard_path = os.path.join(project_root, "Python", "dashboard", "app.py")  # Fix the path
    
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