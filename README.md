Container Housing Analysis Project

- Overview -

This project analyzes the feasibility of recycling shipping containers into sustainable housing options for urban development, primarily relating to a Philippine setting (wherever possible) with a focus on cost comparison, sustainability metrics, and practical implementation challenges. Based on a college analysis paper I previously created, this project demonstrates data analytics, visualization, and research skills. Currently working with AI such as Claude and DeepSeek to streamline tasks and analysis, as well as learning and familiarizing myself again with coding.

Skills used: Data entry, analysis, and visualization, research, problem-solving, coding, etc.

- Completed Work -

Established PostgreSQL database with tables for housing models, cost breakdowns, container prices, and efficiency metrics
Created SQL schema, views, and stored procedures for data analysis
Processed and transformed shipping container data from 2017-2024
Implemented data cleaning and import scripts using Python
Developed analysis modules for price forecasting and cost comparison
Created analysis queries for ROI evaluation and cost efficiency calculations
Built visualization components for housing model comparisons and price trends

- Work in Progress -
Python > Tableau
Python analysis pipelines for sensitivity and Monte Carlo simulation
Streamlit dashboard implementation for interactive analysis
Tableau integration for advanced visualizations
Comprehensive report generation with findings
Link query results and visualizations for straightforward progress evaluation

- Project Structure -
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

- Database Structure (using local PostgreSQL connection) -
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

- Technology Stack -

Database: PostgreSQL
Programming: Python, SQL
Data Processing: Pandas, NumPy, SQLAlchemy
Analysis: Scikit-learn, SciPy
Visualization: Plotly, Streamlit, Tableau
Development: Git, VSCode
