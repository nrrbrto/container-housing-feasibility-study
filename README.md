## Container Housing Analysis Project

### Overview

This project analyzes the feasibility of recycling shipping containers into sustainable housing options for urban development, primarily relating to a Philippine setting (wherever possible) with a focus on cost comparison, sustainability metrics, and practical implementation challenges. Based on a college analysis paper I previously created, this project demonstrates data analytics, visualization, and research skills. Currently working with AI such as Claude and DeepSeek to streamline tasks and analysis, as well as learning and familiarizing myself again with coding.

Skills used: Data entry, analysis, and visualization, research, problem-solving, coding, etc.

### Completed Work

Established PostgreSQL database with tables for housing models, cost breakdowns, container prices, and efficiency metrics
Created SQL schema, views, and stored procedures for data analysis
Processed and transformed shipping container data from 2017-2024
Implemented data cleaning and import scripts using Python
Developed analysis modules for price forecasting and cost comparison
Created analysis queries for ROI evaluation and cost efficiency calculations
Built visualization components for housing model comparisons and price trends

### Work in Progress -
Python > Tableau
Python analysis pipelines for sensitivity and Monte Carlo simulation
Streamlit dashboard implementation for interactive analysis
Tableau integration for advanced visualizations
Comprehensive report generation with findings
Link query results and visualizations for straightforward progress evaluation

### Project Structure -
```plaintext
Container Housing Feasibility/
├── .vscode/                          # VS Code configuration
├── data-practice/                    # Data storage and processing
│   ├── processed/                    # Processed data files
│   │   └── Per Year/                 # CSV files organized by year (2017-2024)
│   │       ├── 2017.csv
│   │       ├── 2018.csv
│   │       └── ...
│   ├── Python/                       # Python analysis scripts
│   │   ├── connection/               # Database connection modules
│   │   ├── analysis/                 # Analysis modules for forecasting, cost, sensitivity
│   │   ├── visualization/            # Visualization libraries and helpers
│   │   ├── dashboard/                # Streamlit dashboard components
│   │   └── main.py                   # Main analysis runner
│   ├── SQL/                          # SQL scripts and queries
│   │   ├── analysis_query.sql        # Analysis queries
│   │   ├── import_container_data.py  # Data import script
│   │   ├── import_data.sql           # Data import SQL
│   │   ├── procedures.sql            # Stored procedures
│   │   ├── reports.sql               # Report generation queries
│   │   ├── schema.sql                # Main database schema
│   │   ├── schema_container_prices.sql # Container prices schema
│   │   ├── view_container_price.sql  # Container price views
│   │   ├── view_shipping_analysis.sql # Shipping analysis views
│   │   ├── views_container_price_trends.sql # Price trend views
│   │   ├── views_housing_dashboard.sql # Dashboard views
│   │   └── views_housing_roi.sql     # ROI calculation views
│   └── raw/                          # Raw data files
├── documentation/                    # Project documentation
│   ├── CE10_Proj.pdf                 # Base research paper
│   ├── ArchJosieDeAsisDP.pdf         # Container housing potential study
│   ├── limitations/                  # Project scope and limitations
│   │   ├── Container Housing Project Limitations.md
│   │   └── Model Comparison Limitations.md
│   └── project-notes/                # Development notes
│       └── Revised Container Housing Project Workflow.mermaid
└── visualizations/                   # Visualization components
    ├── dashboards/                   # Tableau dashboards
    └── exports/                      # Exported visualizations
```

### Database Structure (using local PostgreSQL connection)
```plaintext
container_housing (Database)
└── public (Schema)
    ├── Tables
    │   ├── container_prices
    │   ├── container_prices_raw
    │   ├── cost_breakdown
    │   ├── cost_breakdown_concmod
    │   ├── cost_per_sqm
    │   ├── efficiency_metrics
    │   ├── housing_models
    │   ├── resource_usage
    │   ├── shipping_container_prices
    │   ├── shipping_container_raw
    │   └── total_cost_comparison
    ├── Views
    │   ├── container_price_trends
    │   ├── housing_dashboard
    │   ├── housing_roi
    │   ├── monthly_shipping_volume
    │   ├── priority_impact
    │   ├── producer_performance
    │   └── route_analysis
    └── Functions
        └── analyze_housing_sensitivity(numeric, numeric, integer)
```

### Technology Stack

Database: PostgreSQL
Programming: Python, SQL
Data Processing: Pandas, NumPy, SQLAlchemy
Analysis: Scikit-learn, SciPy
Visualization: Plotly, Streamlit, Tableau
Development: Git, VSCode

---

## Setup Instructions

### 1. Environment Setup

Create and activate a virtual environment to keep project dependencies isolated from other Python projects. This prevents conflicts between package versions. (I forgot but you should):

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows
venv\Scripts\activate
# Mac/Linux
source venv/bin/activate
```
In VS Code, you can select this environment:

- Press Ctrl+Shift+P (or Cmd+Shift+P on Mac)
- Type "Python: Select Interpreter"
- Choose the interpreter from your newly created venv

Install required packages:

```bash
pip install -r requirements.txt
```

### 2. Database Configuration

Ensure PostgreSQL is installed and running. The database connection parameters are:

- Host: localhost
- Database: container_housing
- User: postgres
- Password: postgres
- Port: 5432

Then:

- Use referred PostgreSQL client
- Create a new database named container_housing
- Run the schema scripts from the SQL folder

```bash
# Create database
psql -U postgres -c CREATE DATABASE container_housing;

# Run schema creation and data import scripts
psql -U postgres -d container_housing -f SQL/schema.sql
psql -U postgres -d container_housing -f SQL/schema_container_prices.sql
psql -U postgres -d container_housing -f SQL/import_data.sql
psql -U postgres -d container_housing -f SQL/import_container_data.py
```

...or run and setup everything using preferred editor.

### 3. Running the Analysis

- Navigate to the Python folder
- Run run_analysis.py to execute all analysis modules
- Results will be displayed in the terminal and saved to the database

### 4. Launching the Dashboard

Start the Streamlit dashboard:
- Navigate to the Python folder
- Run run_dashboard.py
- The dashboard will open in the default browser at http://localhost:8501

---

## Analysis Modules

### Price Forecasting
- Analyzes historical container price trends
- Builds predictive models for future container prices
- Generates price forecasts with prediction intervals

### Cost Analysis
- Compares total costs of different housing models
- Analyzes cost breakdown by component (materials, labor, finishings)
- Calculates cost efficiency metrics relative to traditional housing

### Sensitivity Analysis
- Simulates different economic scenarios using Monte Carlo simulation [WIP, finding proper data to use]
- Analyzes impact of key parameters:
  - Container price fluctuations (-30% to +70%)
  - Rental income variations (₱8,000 to ₱20,000)
  - Expected lifespan (15-40 years)
- Identifies optimal scenarios for each housing model:
  - Highest ROI scenarios
  - Shortest payback periods
  - Statistical performance metrics (mean, min, max, std)

## Result Analysis

The sensitivity analysis module processes simulation results to:

- Identify optimal scenarios for each housing model
- Find configurations with highest ROI potential
- Determine conditions for shortest payback periods
- Calculate statistical distributions (mean, min, max, standard deviation)
- Rank models based on performance across varied economic conditions

---

## References

[WIP, still reading]

## Commands Summary

```bash
# Run analysis pipeline
python run_analysis.py

# Run dashboard
python run_dashboard.py
```

## Notes

- All ROI calculations are based on placeholder values for demonstration
- The sensitivity analysis uses Monte Carlo simulation with 500 iterations
- Container price forecasts are based on historical data from 2017-2024
