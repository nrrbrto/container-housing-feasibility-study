import streamlit as st
import sys
import os
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots


# Project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from connection.db_connect import query_to_dataframe

# Page config
st.set_page_config(
    page_title="Container Housing Feasibility Analysis",
    page_icon="🏠",
    layout="wide"
)

# Title and description
st.title("Container Housing Feasibility Analysis Dashboard")
st.markdown("""
This dashboard provides comprehensive analysis of shipping container housing feasibility 
compared to traditional housing methods. Use the sidebar to navigate between different analysis sections.
""")

# Sidebar navigation
st.sidebar.title("Navigation")
page = st.sidebar.radio(
    "Select Analysis Section",
    ["Cost Analysis", "Price Forecasting", "Efficiency Metrics", "Sensitivity Analysis", "ROI Calculator"]
)

# Load data based on selected page
@st.cache_data(ttl=600)
def load_data(data_type):
    """Load data based on the selected data type"""
    if data_type == "housing_models":
        return query_to_dataframe("SELECT * FROM housing_models")
    elif data_type == "cost_breakdown":
        return query_to_dataframe("SELECT * FROM cost_breakdown")
    elif data_type == "price_forecast":
        return query_to_dataframe("SELECT * FROM container_price_forecast")
    elif data_type == "efficiency_metrics":
        return query_to_dataframe("SELECT * FROM cost_efficiency_analysis")
    elif data_type == "sensitivity":
        return query_to_dataframe("SELECT * FROM sensitivity_analysis_results LIMIT 1000")
    elif data_type == "optimal_scenarios":
        return query_to_dataframe("SELECT * FROM sensitivity_optimal_scenarios")
    elif data_type == "container_price_trends":
        return query_to_dataframe("SELECT * FROM container_price_trends")
    else:
        return pd.DataFrame()

# Cost Analysis Page
if page == "Cost Analysis":
    st.header("Cost Analysis")
    
    # Load data
    housing_models = load_data("housing_models")
    cost_breakdown = load_data("cost_breakdown")
    
    # Total cost comparison
    st.subheader("Total Cost Comparison")
    
    # Create bar chart for total costs
    fig = px.bar(
        housing_models, 
        x='model_name', 
        y='total_cost',
        title="Total Cost by Housing Model",
        labels={'total_cost': 'Total Cost (PHP)', 'model_name': 'Housing Model'},
        color='model_name',
        color_discrete_sequence=px.colors.qualitative.Pastel
    )
    fig.update_layout(xaxis_title="Housing Model", yaxis_title="Total Cost (PHP)")
    st.plotly_chart(fig, use_container_width=True)
    
    # Cost breakdown
    st.subheader("Cost Breakdown")
    
    # Create stacked bar chart for cost components
    cost_components = pd.melt(
        cost_breakdown, 
        id_vars=['model_name', 'total_cost'],
        value_vars=['materials_cost', 'labor_cost', 'finishings_cost'],
        var_name='cost_component',
        value_name='cost'
    )
    
    # Clean up component names
    cost_components['cost_component'] = cost_components['cost_component'].str.replace('_cost', '').str.capitalize()
    
    fig = px.bar(
        cost_components,
        x='model_name',
        y='cost',
        color='cost_component',
        title="Cost Breakdown by Component",
        labels={'cost': 'Cost (PHP)', 'model_name': 'Housing Model', 'cost_component': 'Component'},
        color_discrete_sequence=px.colors.qualitative.Safe
    )
    fig.update_layout(xaxis_title="Housing Model", yaxis_title="Cost (PHP)")
    st.plotly_chart(fig, use_container_width=True)
    
    # Cost per square meter
    st.subheader("Cost per Square Meter")
    
    fig = px.bar(
        housing_models,
        x='model_name',
        y='cost_per_sqm',
        title="Cost per Square Meter",
        labels={'cost_per_sqm': 'Cost per SQM (PHP)', 'model_name': 'Housing Model'},
        color='model_name',
        color_discrete_sequence=px.colors.qualitative.Pastel
    )
    fig.update_layout(xaxis_title="Housing Model", yaxis_title="Cost per SQM (PHP)")
    st.plotly_chart(fig, use_container_width=True)

# Price Forecasting Page
# Modified code for the Price Forecasting Page in app.py
elif page == "Price Forecasting":
    st.header("Container Price Forecasting")
    
    # Load data
    price_trends = load_data("container_price_trends")
    
    # Historical price trends
    st.subheader("Historical Container Price Trends")
    
    # Create time series for historical prices
    if not price_trends.empty:
        # Debug: Show the actual columns in the dataframe
        st.write("Available columns:", list(price_trends.columns))
        
        # Check if required columns exist
        if 'year' in price_trends.columns:
            # If 'quarter' doesn't exist, use alternative approach
            if 'quarter' not in price_trends.columns:
                if 'month' in price_trends.columns:
                    # If month exists, create a time label using year and month
                    price_trends['time_label'] = price_trends['year'].astype(str) + "-" + price_trends['month'].astype(str)
                    sort_columns = ['year', 'month']
                else:
                    # If neither quarter nor month exists, just use year
                    price_trends['time_label'] = price_trends['year'].astype(str)
                    sort_columns = ['year']
            else:
                # If quarter exists, use year and quarter
                price_trends['time_label'] = price_trends['year'].astype(str) + " Q" + price_trends['quarter'].astype(str)
                sort_columns = ['year', 'quarter']
            
            # Sort the data
            sorted_data = price_trends.sort_values(sort_columns)
            
            # Check which value column to use
            value_column = None
            for possible_column in ['avg_price', 'price', 'freight_index', 'avg_freight_index']:
                if possible_column in price_trends.columns:
                    value_column = possible_column
                    break
            
            if value_column:
                fig = px.line(
                    sorted_data,
                    x='time_label',
                    y=value_column,
                    title="Historical Container Prices",
                    labels={value_column: 'Price', 'time_label': 'Time Period'},
                    markers=True
                )
                fig.update_layout(xaxis_title="Time Period", yaxis_title="Price")
                st.plotly_chart(fig, use_container_width=True)
            else:
                st.warning("No price column found in the data")
        else:
            st.warning("Required column 'year' not found in the data")
    else:
        st.warning("No historical price data available")

# Efficiency Metrics Page
elif page == "Efficiency Metrics":
    st.header("Efficiency Metrics Analysis")
    
    # Load data
    efficiency_metrics = load_data("efficiency_metrics")
    housing_models = load_data("housing_models")
    
    # Create metrics dataframe
    metrics_df = housing_models.copy()
    metrics_df['cost_efficiency'] = ((housing_models[housing_models['model_name'] == 'Traditional Housing']['total_cost'].iloc[0] - 
                                      metrics_df['total_cost']) / 
                                     housing_models[housing_models['model_name'] == 'Traditional Housing']['total_cost'].iloc[0] * 100)
    metrics_df['time_efficiency'] = ((housing_models[housing_models['model_name'] == 'Traditional Housing']['construction_time_days'].iloc[0] - 
                                       metrics_df['construction_time_days']) / 
                                      housing_models[housing_models['model_name'] == 'Traditional Housing']['construction_time_days'].iloc[0] * 100)
    metrics_df['waste_reduction'] = ((housing_models[housing_models['model_name'] == 'Traditional Housing']['waste_percentage'].iloc[0] - 
                                       metrics_df['waste_percentage']) / 
                                      housing_models[housing_models['model_name'] == 'Traditional Housing']['waste_percentage'].iloc[0] * 100)
    
    # Key metrics
    st.subheader("Key Efficiency Metrics")
    
    cols = st.columns(len(metrics_df) - 1)  # Exclude traditional housing
    
    non_traditional = metrics_df[metrics_df['model_name'] != 'Traditional Housing']
    
    for i, (_, row) in enumerate(non_traditional.iterrows()):
        with cols[i]:
            st.metric(
                label=row['model_name'],
                value=f"{row['cost_efficiency']:.1f}% Cost Savings",
                delta=f"{row['time_efficiency']:.1f}% Time Savings"
            )
    
    # Radar chart for efficiency metrics
    st.subheader("Efficiency Metrics Comparison")
    
    # Prepare data for radar chart
    radar_data = metrics_df.copy()
    
    # Create efficiency metrics for radar chart
    radar_metrics = ['cost_efficiency', 'time_efficiency', 'waste_reduction']
    
    # Initialize figure
    fig = go.Figure()
    
    # Add trace for each housing model except traditional
    for _, row in radar_data[radar_data['model_name'] != 'Traditional Housing'].iterrows():
        fig.add_trace(go.Scatterpolar(
            r=[row[metric] for metric in radar_metrics],
            theta=['Cost Efficiency', 'Time Efficiency', 'Waste Reduction'],
            fill='toself',
            name=row['model_name']
        ))
    
    # Update layout
    fig.update_layout(
        polar=dict(
            radialaxis=dict(
                visible=True,
                range=[0, max(radar_data['cost_efficiency'].max(), 
                              radar_data['time_efficiency'].max(), 
                              radar_data['waste_reduction'].max()) * 1.1]
            )
        ),
        title="Efficiency Metrics Radar Chart (% Improvement over Traditional Housing)"
    )
    
    st.plotly_chart(fig, use_container_width=True)
    
    # Construction time comparison
    st.subheader("Construction Time Comparison")
    
    fig = px.bar(
        metrics_df,
        x='model_name',
        y='construction_time_days',
        title="Construction Time (Days)",
        labels={'construction_time_days': 'Days', 'model_name': 'Housing Model'},
        color='model_name'
    )
    fig.update_layout(xaxis_title="Housing Model", yaxis_title="Construction Time (Days)")
    st.plotly_chart(fig, use_container_width=True)
    
    # Waste reduction
    st.subheader("Construction Waste Comparison")
    
    fig = px.bar(
        metrics_df,
        x='model_name',
        y='waste_percentage',
        title="Construction Waste (%)",
        labels={'waste_percentage': 'Waste (%)', 'model_name': 'Housing Model'},
        color='model_name'
    )
    fig.update_layout(xaxis_title="Housing Model", yaxis_title="Waste (%)")
    st.plotly_chart(fig, use_container_width=True)
    
    # Citations
    st.subheader("Source Citations")
    st.markdown("""
    - **Waste Reduction**: "modular construction was 40-60% quicker and produced 70% less onsite waste than traditional building methods" [CE10_Proj.pdf, citation 18]
    - **Material Usage**: "a container home can be constructed of about 75% recycled materials by weight" [CE10_Proj.pdf, citation 10]
    - **Construction Timeline**: Based on data from ArchJosieDeAsisDP.pdf study comparing container housing construction with traditional methods
    """)

# Sensitivity Analysis Page
elif page == "Sensitivity Analysis":
    st.header("Sensitivity Analysis")
    
    # Load data
    sensitivity_results = load_data("sensitivity")
    optimal_scenarios = load_data("optimal_scenarios")
    
    # Simulation parameters
    st.subheader("Simulation Parameters")
    
    if not sensitivity_results.empty:
        st.markdown("""
        This analysis simulates different economic scenarios to evaluate the financial viability of each housing model.
        Parameters varied in the simulation:
        
        - **Container Price Change**: -30% to +70%
        - **Annual Rental Income**: ₱8,000 to ₱20,000
        - **Expected Lifespan**: 15 to 40 years
        - **Maintenance Costs**: 2-5% for Traditional, 2.5-6% for Container
        """)
    
        # Interactive parameters for filtering results
        st.subheader("Filter Simulation Results")
        
        col1, col2 = st.columns(2)
        
    if 'annual_roi_percentage' in sensitivity_results.columns and 'payback_years' in sensitivity_results.columns:
        # Convert columns to numeric, coercing errors to NaN
        sensitivity_results['annual_roi_percentage'] = pd.to_numeric(
            sensitivity_results['annual_roi_percentage'], 
            errors='coerce'
        )
        sensitivity_results['payback_years'] = pd.to_numeric(
            sensitivity_results['payback_years'], 
            errors='coerce'
        )
        
        # Create two columns for sliders
        col1, col2 = st.columns(2)
        
        with col1:
            min_roi = st.slider(
                "Minimum ROI (%)", 
                min_value=float(sensitivity_results['annual_roi_percentage'].min()),
                max_value=float(sensitivity_results['annual_roi_percentage'].max()),
                value=float(sensitivity_results['annual_roi_percentage'].min()),
                key="min_roi_slider"  # Unique key
            )
        
        with col2:
            max_payback = st.slider(
                "Maximum Payback Period (Years)", 
                min_value=float(sensitivity_results['payback_years'].min()),
                max_value=float(sensitivity_results['payback_years'].max()),
                value=float(sensitivity_results['payback_years'].max()),
                key="max_payback_slider"  # Unique key
            )
        
        # Apply filters
        filtered_results = sensitivity_results[
            (sensitivity_results['annual_roi_percentage'] >= min_roi) &
            (sensitivity_results['payback_years'] <= max_payback)
        ]
        
        # Display filtered results
        st.write("Filtered Results:", filtered_results)
    else:
        st.error("Required columns ('annual_roi_percentage' or 'payback_years') not found in sensitivity analysis data.")
        filtered_results = sensitivity_results
        
        # Model performance across scenarios
        st.subheader("Model Performance Across Scenarios")
        
        fig = px.box(
            filtered_results,
            x='model_name',
            y='annual_roi_percentage',
            color='model_name',
            title="Annual ROI Distribution by Housing Model",
            labels={'annual_roi_percentage': 'Annual ROI (%)', 'model_name': 'Housing Model'}
        )
        fig.update_layout(xaxis_title="Housing Model", yaxis_title="Annual ROI (%)")
        st.plotly_chart(fig, use_container_width=True)
        
        # Payback period distribution
        fig = px.box(
            filtered_results,
            x='model_name',
            y='payback_years',
            color='model_name',
            title="Payback Period Distribution by Housing Model",
            labels={'payback_years': 'Payback Period (Years)', 'model_name': 'Housing Model'}
        )
        fig.update_layout(xaxis_title="Housing Model", yaxis_title="Payback Period (Years)")
        st.plotly_chart(fig, use_container_width=True)
        
        # Parameter impact analysis
        st.subheader("Parameter Impact Analysis")
        
        # Select parameter to analyze
        parameter = st.selectbox(
            "Select Parameter to Analyze",
            ["container_price_increase", "rental_income", "expected_lifespan"]
        )
        
        # Select model to analyze
        model = st.selectbox(
            "Select Housing Model",
            sorted(filtered_results['model_name'].unique())
        )
        
        # Filter data for selected model
        model_data = filtered_results[filtered_results['model_name'] == model]
        
        # Create scatter plot
        fig = px.scatter(
            model_data,
            x=parameter,
            y='annual_roi_percentage',
            color='payback_years',
            title=f"Impact of {parameter} on ROI for {model}",
            labels={
                parameter: parameter.replace('_', ' ').title(),
                'annual_roi_percentage': 'Annual ROI (%)',
                'payback_years': 'Payback Years'
            },
            color_continuous_scale='Viridis'
        )
        fig.update_layout(
            xaxis_title=parameter.replace('_', ' ').title(),
            yaxis_title="Annual ROI (%)"
        )
        st.plotly_chart(fig, use_container_width=True)
        
        # Optimal scenarios
        st.subheader("Optimal Scenarios")
        
        if not optimal_scenarios.empty:
            # Filter optimal scenarios based on user selection
            optimal_cols = ['model_name', 'annual_roi_percentage', 'payback_years', 
                          'container_price_increase', 'rental_income', 'expected_lifespan']
            
            st.dataframe(
                optimal_scenarios[optimal_cols].sort_values('annual_roi_percentage', ascending=False),
                use_container_width=True
            )

# ROI Calculator Page
elif page == "ROI Calculator":
    st.header("ROI Calculator")
    
    # Load housing models data
    housing_models = load_data("housing_models")
    
    # ROI Calculator inputs
    st.subheader("Enter Parameters")
    
    col1, col2 = st.columns(2)
    
    with col1:
        container_price_change = st.slider(
        "Container Price Change (%)",
        min_value=-30.0,
        max_value=70.0,
        value=0.0,
        step=5.0,
        key="container_price_slider"  # Add unique key
        )
        
        rental_income = st.number_input(
            "Annual Rental Income (₱)",
            min_value=5000,
            max_value=30000,
            value=12000,
            step=1000
        )
    
    with col2:
        expected_lifespan = st.slider(
            "Expected Lifespan (Years)",
            min_value=10,
            max_value=50,
            value=25,
            step=5,
            key="lifespan_slider"  # Add unique key
        )
        
        maintenance_pct = st.slider(
            "Annual Maintenance (% of Investment)",
            min_value=1.0,
            max_value=8.0,
            value=3.0,
            step=0.5,
            key="maintenance_slider"  # Add unique key
        ) / 100

    # Calculate ROI for each housing model
    roi_results = []
    
    # Iterate through housing models
    for _, model in housing_models.iterrows():
        # Adjust investment based on container price change
        adjusted_investment = model['total_cost']
        if 'Container' in model['model_name']:
            adjusted_investment = model['total_cost'] * (1 + container_price_change/100)
        
        # Calculate annual maintenance cost
        maintenance_cost = adjusted_investment * maintenance_pct
        
        # Calculate annual net income
        annual_net_income = rental_income - maintenance_cost
        
        # Calculate payback period
        payback_years = adjusted_investment / annual_net_income if annual_net_income > 0 else float('inf')
        
        # Calculate ROI
        annual_roi = (annual_net_income / adjusted_investment) * 100 if adjusted_investment > 0 else 0
        
        # Calculate net present value (simplified)
        discount_rate = 0.05  # 5% discount rate
        npv = -adjusted_investment
        for year in range(1, expected_lifespan + 1):
            npv += annual_net_income / ((1 + discount_rate) ** year)
        
        # Add results to list
        roi_results.append({
            'model_name': model['model_name'],
            'adjusted_investment': adjusted_investment,
            'annual_maintenance': maintenance_cost,
            'annual_net_income': annual_net_income,
            'payback_years': payback_years,
            'annual_roi_percentage': annual_roi,
            'npv': npv
        })
    
    # Convert to DataFrame
    roi_df = pd.DataFrame(roi_results)
    
    # Display ROI results
    st.subheader("ROI Analysis Results")
    
    # Metrics overview
    cols = st.columns(len(roi_df))
    
    for i, (_, row) in enumerate(roi_df.iterrows()):
        with cols[i]:
            st.metric(
                label=row['model_name'],
                value=f"{row['annual_roi_percentage']:.1f}% ROI",
                delta=f"{row['payback_years']:.1f} Years Payback"
            )
    
    # ROI comparison chart
    st.subheader("ROI Comparison")
    
    fig = px.bar(
        roi_df,
        x='model_name',
        y='annual_roi_percentage',
        color='model_name',
        title="Annual ROI by Housing Model",
        labels={'annual_roi_percentage': 'Annual ROI (%)', 'model_name': 'Housing Model'}
    )
    fig.update_layout(xaxis_title="Housing Model", yaxis_title="Annual ROI (%)")
    st.plotly_chart(fig, use_container_width=True)
    
    # NPV comparison chart
    st.subheader("Net Present Value Comparison")
    
    fig = px.bar(
        roi_df,
        x='model_name',
        y='npv',
        color='model_name',
        title="Net Present Value by Housing Model",
        labels={'npv': 'NPV (₱)', 'model_name': 'Housing Model'}
    )
    fig.update_layout(xaxis_title="Housing Model", yaxis_title="Net Present Value (₱)")
    st.plotly_chart(fig, use_container_width=True)
    
    # Detailed results
    st.subheader("Detailed Results")
    
    # Format DataFrame for display
    display_df = roi_df.copy()
    display_df['adjusted_investment'] = display_df['adjusted_investment'].map('₱{:,.2f}'.format)
    display_df['annual_maintenance'] = display_df['annual_maintenance'].map('₱{:,.2f}'.format)
    display_df['annual_net_income'] = display_df['annual_net_income'].map('₱{:,.2f}'.format)
    display_df['payback_years'] = display_df['payback_years'].map('{:.2f} years'.format)
    display_df['annual_roi_percentage'] = display_df['annual_roi_percentage'].map('{:.2f}%'.format)
    display_df['npv'] = display_df['npv'].map('₱{:,.2f}'.format)
    
    st.dataframe(display_df, use_container_width=True)
    
    # Citation
    st.markdown("""
    **Source Note**: ROI calculations are based on interpolated data for demonstration purposes. 
    Actual values should be validated with real market data and contractor quotes.
    """)

# Helper functions

def format_currency(value):
    """Format a value as Philippine Pesos"""
    return f"₱{value:,.2f}"

def format_percentage(value):
    """Format a value as a percentage"""
    return f"{value:.2f}%"

def create_cost_breakdown_chart(data):
    """Create a stacked bar chart for cost breakdown"""
    # Melt the dataframe to get it in the right format for plotting
    melted_data = pd.melt(
        data,
        id_vars=['model_name'],
        value_vars=['materials_cost', 'labor_cost', 'finishings_cost'],
        var_name='cost_component',
        value_name='value'
    )
    
    # Clean up the component names
    melted_data['cost_component'] = melted_data['cost_component'].str.replace('_cost', '').str.capitalize()
    
    # Create the stacked bar chart
    fig = px.bar(
        melted_data,
        x='model_name',
        y='value',
        color='cost_component',
        title='Cost Breakdown by Component',
        labels={'value': 'Cost (PHP)', 'model_name': 'Housing Model', 'cost_component': 'Component'},
        color_discrete_sequence=px.colors.qualitative.Safe
    )
    
    fig.update_layout(
        xaxis_title='Housing Model',
        yaxis_title='Cost (PHP)',
        legend_title='Component'
    )
    
    return fig

def create_radar_chart(data, metrics, title):
    """Create a radar chart for multiple metrics"""
    fig = go.Figure()
    
    for _, row in data.iterrows():
        fig.add_trace(go.Scatterpolar(
            r=[row[m] for m in metrics],
            theta=[m.replace('_', ' ').title() for m in metrics],
            fill='toself',
            name=row['model_name']
        ))
    
    fig.update_layout(
        polar=dict(
            radialaxis=dict(
                visible=True,
                range=[0, max([data[m].max() for m in metrics]) * 1.1]
            )
        ),
        title=title
    )
    
    return fig

def create_sensitivity_scatter(data, x, y, color, title):
    """Create a scatter plot for sensitivity analysis"""
    fig = px.scatter(
        data,
        x=x,
        y=y,
        color=color,
        title=title,
        labels={
            x: x.replace('_', ' ').title(),
            y: y.replace('_', ' ').title(),
            color: color.replace('_', ' ').title()
        },
        color_continuous_scale='Viridis'
    )
    
    fig.update_layout(
        xaxis_title=x.replace('_', ' ').title(),
        yaxis_title=y.replace('_', ' ').title()
    )
    
    return fig

def create_roi_dashboard(roi_data):
    """Create a comprehensive ROI dashboard with multiple charts"""
    # Create a subplot with 2 rows and 1 column
    fig = make_subplots(
        rows=2, 
        cols=1,
        subplot_titles=("Annual ROI Percentage", "Payback Period (Years)")
    )
    
    # Add ROI percentage bar chart
    fig.add_trace(
        go.Bar(
            x=roi_data['model_name'],
            y=roi_data['annual_roi_percentage'],
            marker_color=px.colors.qualitative.Plotly,
            name="Annual ROI (%)"
        ),
        row=1, col=1
    )
    
    # Add payback period bar chart
    fig.add_trace(
        go.Bar(
            x=roi_data['model_name'],
            y=roi_data['payback_years'],
            marker_color=px.colors.qualitative.Plotly,
            name="Payback Period (Years)"
        ),
        row=2, col=1
    )
    
    # Update layout
    fig.update_layout(
        height=600,
        title_text="ROI Analysis Dashboard",
        showlegend=False
    )
    
    # Update y-axes titles
    fig.update_yaxes(title_text="Annual ROI (%)", row=1, col=1)
    fig.update_yaxes(title_text="Years", row=2, col=1)
    
    return fig