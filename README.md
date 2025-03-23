## Container Housing Analysis Project
https://container-housing-dashboard-988102729e39.herokuapp.com/

### Overview

This project analyzes the feasibility of recycling shipping containers into sustainable housing options for urban development, primarily relating to a Philippine setting (wherever possible) with a focus on cost comparison, sustainability metrics, ROI and payback period, and practical implementation challenges. Based on a college analysis paper I previously created, this project demonstrates data analytics, visualization, and research skills. Currently working with AI such as Claude and DeepSeek to streamline tasks and analysis, as well as learning and familiarizing myself again with coding.

### Completed Work
- Processed and transformed shipping container and freight index data from 2017-2024 using Excel Power Query and SQL
- Implemented data cleaning and import scripts using Python
- Created SQL schema, views, and stored procedures for data analysis
- Established PostgreSQL database with tables for housing models, cost breakdowns, container prices, and efficiency metrics

Developed analysis modules and visualization for:
- Cost comparison between traditional housing and container-based alternatives
- Sustainability metrics tracking (waste reduction, material usage)
- Price forecasting for shipping containers
- ROI and payback period analysis
- Sensitivity analysis using Monte Carlo simulation

### Work in Progress
- Clean app interface
- Tableau integration
- Finalizing references and citations
  
### Technology Stack

Database: PostgreSQL
Programming: Python, SQL
Data Processing: Pandas, NumPy, SQLAlchemy
Analysis: Scikit-learn, SciPy
Visualization: Plotly, Streamlit, Tableau
Development: Git, VSCode

### Project Structure
```plaintext
Container Housing Feasibility/
├── .vscode/                          # VS Code configuration
├── connection/                    # Database connection modules
│   ├── pycache/
│   ├── init__.py
│   └── db_connect.py
├── data-practice/                    # Data storage and processing
│   ├── processed/                    # Processed data files
│   │   └── Per Year/                 # CSV files organized by year (2017-2024)
│   │       ├── 2017.csv
│   │       ├── 2018.csv
│   │       └── ...
│   ├── Python/                    # Python scripts
│   │   ├── analysis/              # Analysis modules
│   │   │   ├── __pycache__/
│   │   │   ├── __init__.py
│   │   │   ├── cost_analysis.py
│   │   │   ├── price_forecasting.py
│   │   │   └── sensitivity_analysis.py
│   │   ├── dashboard/
│   │   │   └── app.py
│   │   ├── db.setup.sh
│   │   ├── main.py
│   │   ├── run_analysis.py
│   │   ├── run_dashboard.py
│   ├── raw/                       # Raw data files
│   └── SQL/                       # SQL scripts
│       ├── analysis_query.sql
│       ├── import_container_data.py
│       ├── import_data.sql
│       ├── procedures.sql
│       ├── reports.sql
│       ├── schema.sql
│       ├── schema_container_prices.sql
│       ├── view_container_price.sql
│       ├── view_shipping_analysis.sql
│       ├── views_container_price_trends.sql
│       ├── views_housing_dashboard.sql
│       └── views_housing_roi.sql
├── documentation/                    # Project documentation
│   ├── limitations/                  # Project scope and limitations
│   └── project-notes/                # Development notes (old)
│       └── Revised Container Housing Project Workflow.mermaid
├── .gitignore
├── Procfile
├── README.md
├── requirements.txt
└── runtime.txt
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

---

## Setup Instructions

### 1. Environment Setup

```bash
# Create and activate virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt
```

### 2. Database Configuration

- Host: localhost
- Database: container_housing
- User: postgres
- Password: postgres
- Port: 5432

Then:

```bash
# Database setup
bash db.setup.sh

# Or run individual scripts:
psql -U postgres -c "CREATE DATABASE container_housing;"
psql -U postgres -d container_housing -f SQL/schema.sql
psql -U postgres -d container_housing -f SQL/schema_container_prices.sql
psql -U postgres -d container_housing -f SQL/import_container_data.py
```

### 3. Running the Analysis

```bash
Copy# Run full analysis pipeline
python run_analysis.py

# Run sensitivity analysis
python run_sensitivity.py

# Launch Streamlit dashboard
python run_dashboard.py  # Access at http://localhost:8501
```

## Analysis Modules

### Price Forecasting
Analyzes container price and freight index trends from 2017-2024 and predicts future prices with confidence intervals.

### Cost Analysis
Compares housing models on total cost, cost breakdown, and efficiency metrics.

### Sensitivity Analysis
Simulates scenarios with varying parameters:
* Container price changes (-5% to 5%)
* Rental income variations:
  * Low income: ₱15,460-16,000 annually
  * Middle income: ₱30,000-31,000 annually
  * Upper income: ₱59,000-60,000 annually
* Expected lifespan:
  * Traditional housing: 80-150 years
  * Container housing: 40-150 years

---

## References
[WIP, cross-checking references, citations are in the app and limitation files]

## Notes
- Some data are inferences based of existing data like maintenance cost for container homes based of maintenance cost for traditional housing.
