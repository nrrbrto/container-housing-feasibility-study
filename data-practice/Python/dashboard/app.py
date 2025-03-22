import streamlit as st
import sys
import os
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

# Try importing from project root first (production)
try:
    from connection.db_connect import query_to_dataframe, dataframe_to_sql
except ImportError:
    # Fall back to development path
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from connection.db_connect import query_to_dataframe, dataframe_to_sql
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
    try:
        if data_type == "housing_models":
            return query_to_dataframe("SELECT * FROM housing_models")
        elif data_type == "cost_breakdown":
            return query_to_dataframe("SELECT * FROM cost_breakdown")
        elif data_type == "price_forecast":
            print("Loading price forecast data...")
            df = query_to_dataframe("SELECT * FROM container_price_forecast")
            print(f"Loaded {len(df)} price forecast records")
            return df
        elif data_type == "efficiency_metrics":
            return query_to_dataframe("SELECT * FROM cost_efficiency_analysis")
        elif data_type == "sensitivity":
            return query_to_dataframe("SELECT * FROM sensitivity_analysis_results LIMIT 1000")
        elif data_type == "optimal_scenarios":
            return query_to_dataframe("SELECT * FROM sensitivity_optimal_scenarios")
        elif data_type == "container_price_trends":
            return query_to_dataframe("SELECT * FROM container_price_trends")
        elif data_type == "historical_price_changes":
            return query_to_dataframe("SELECT * FROM historical_price_changes")
        else:
            return pd.DataFrame()
    except Exception as e:
        print(f"Error loading {data_type} data: {e}")
        import traceback
        traceback.print_exc()
        # Return empty DataFrame on error
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

    # Citations
    st.subheader("Source Citations")
    st.markdown("""
    - **[WIP] In the Model Comparison Limitations 
    """)

# Price Forecasting Page
elif page == "Price Forecasting":
    st.header("Container Price and Freight Index Forecasting")
    
    # Load data
    price_trends = load_data("container_price_trends")
    price_forecast = load_data("price_forecast")
    
    historical_changes = load_data("historical_price_changes")
    

    # Create tabs for different visualizations
    price_tabs = st.tabs(["Container Prices", "Freight Index"])
    
    with price_tabs[0]:  # Container Price forecast
        st.subheader("Container Price Historical Data and Forecast")
        
        if not price_trends.empty and not price_forecast.empty:
            # Convert year and month to integers and format the time_label
            price_trends['time_label'] = price_trends['year'].astype(int).astype(str) + "-M" + price_trends['month'].astype(int).astype(str)
            price_forecast['time_label'] = price_forecast['year'].astype(int).astype(str) + "-M" + price_forecast['month'].astype(int).astype(str)
            
            # Create plot
            fig = px.line(
                price_trends,
                x='time_label',
                y='avg_price',
                title="Historical Container Prices",
                labels={'avg_price': 'Price', 'time_label': 'Time Period'},
                markers=True
            )
            
            # Add forecast line
            fig.add_trace(
                go.Scatter(
                    x=price_forecast['time_label'],
                    y=price_forecast['avg_price'],
                    mode='lines+markers',
                    name='Price Forecast',
                    line=dict(color='red', dash='dash')
                )
            )
            
            # Add confidence interval
            fig.add_trace(
                go.Scatter(
                    x=price_forecast['time_label'],
                    y=price_forecast['upper_bound'],
                    mode='lines',
                    name='Upper Bound',
                    line=dict(width=0),
                    showlegend=False
                )
            )
            
            fig.add_trace(
                go.Scatter(
                    x=price_forecast['time_label'],
                    y=price_forecast['lower_bound'],
                    mode='lines',
                    name='Lower Bound',
                    line=dict(width=0),
                    fill='tonexty',
                    fillcolor='rgba(255, 0, 0, 0.1)',
                    showlegend=False
                )
            )
            
            fig.update_layout(
                xaxis_title="Time Period",
                yaxis_title="Container Price",
                hovermode="x unified"
            )

            #Historical and Forecasted Price Percentage Changes
            st.subheader("Historical and Forecasted Price Percentage Changes")

            # Create time labels if not already done
            historical_changes['time_label'] = historical_changes['year'].astype(int).astype(str) + "-M" + historical_changes['month'].astype(int).astype(str)
            price_forecast['time_label'] = price_forecast['year'].astype(int).astype(str) + "-M" + price_forecast['month'].astype(int).astype(str)

            # Create a combined dataframe for plotting
            historical_subset = historical_changes[['time_label', 'price_pct_change', 'year', 'month']]
            historical_subset.loc[:, 'data_type'] = 'Historical'

            forecast_subset = price_forecast[['time_label', 'price_pct_change', 'year', 'month']]
            forecast_subset['data_type'] = 'Forecast'

            combined_changes = pd.concat([historical_subset, forecast_subset])
            combined_changes = combined_changes.sort_values(by=['year', 'month'])

            # Create combined chart
            fig_pct = px.line(
                combined_changes,
                x='time_label',
                y='price_pct_change',
                color='data_type',
                title="Monthly Container Price Percentage Changes (Historical and Forecast)",
                labels={'price_pct_change': 'Monthly Change (%)', 'time_label': 'Time Period'},
                markers=True
            )

            st.plotly_chart(fig_pct, use_container_width=True)
            st.plotly_chart(fig, use_container_width=True)

            # Calculate overall average bounds for container prices
            avg_price_pct_change = price_forecast['price_pct_change'].mean()
            avg_price_lower_pct = price_forecast['price_lower_pct'].mean()
            avg_price_upper_pct = price_forecast['price_upper_pct'].mean()

            # Display overall percent changes
            st.subheader("Overall Price Forecast Percent Changes")
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Avg Lower Bound %", f"{avg_price_lower_pct:.2f}%")
            with col2:
                st.metric("Avg Price Change %", f"{avg_price_pct_change:.2f}%")
            with col3:
                st.metric("Avg Upper Bound %", f"{avg_price_upper_pct:.2f}%")

        else:
            st.warning("No historical price data or forecast available")
    
    with price_tabs[1]:  # Freight Index forecast
        st.subheader("Freight Index Historical Data and Forecast")
        
        if not price_trends.empty and not price_forecast.empty:
            # Prepare time labels
            price_trends['time_label'] = price_trends['year'].astype(int).astype(str) + "-M" + price_trends['month'].astype(int).astype(str)
            price_forecast['time_label'] = price_forecast['year'].astype(int).astype(str) + "-M" + price_forecast['month'].astype(int).astype(str)
  
            
            # Create plot
            fig = px.line(
                price_trends,
                x='time_label',
                y='avg_freight_index',
                title="Historical Freight Index",
                labels={'avg_freight_index': 'Freight Index', 'time_label': 'Time Period'},
                markers=True
            )
            
            # Add forecast line
            fig.add_trace(
                go.Scatter(
                    x=price_forecast['time_label'],
                    y=price_forecast['avg_freight_index'],
                    mode='lines+markers',
                    name='Freight Index Forecast',
                    line=dict(color='red', dash='dash')
                )
            )
            
            # Add confidence interval
            fig.add_trace(
                go.Scatter(
                    x=price_forecast['time_label'],
                    y=price_forecast['freight_upper_bound'],
                    mode='lines',
                    name='Upper Bound',
                    line=dict(width=0),
                    showlegend=False
                )
            )
            
            fig.add_trace(
                go.Scatter(
                    x=price_forecast['time_label'],
                    y=price_forecast['freight_lower_bound'],
                    mode='lines',
                    name='Lower Bound',
                    line=dict(width=0),
                    fill='tonexty',
                    fillcolor='rgba(255, 0, 0, 0.1)',
                    showlegend=False
                )
            )
            
            fig.update_layout(
                xaxis_title="Time Period",
                yaxis_title="Freight Index",
                hovermode="x unified"
            )

            # Historical and Forecasted Freight Index Percentage Changes
            st.subheader("Historical and Forecasted Freight Index Percentage Changes")

            # Create a combined dataframe for plotting
            historical_subset = historical_changes[['time_label', 'freight_pct_change', 'year', 'month']]
            forecast_subset.loc[:, 'data_type'] = 'Forecast'

            forecast_subset = price_forecast[['time_label', 'freight_pct_change', 'year', 'month']]
            forecast_subset['data_type'] = 'Forecast'

            combined_changes = pd.concat([historical_subset, forecast_subset])
            combined_changes = combined_changes.sort_values(by=['year', 'month'])

            # Create combined chart
            fig_pct = px.line(
                combined_changes,
                x='time_label',
                y='freight_pct_change',
                color='data_type',
                title="Monthly Freight Index Percentage Changes (Historical and Forecast)",
                labels={'freight_pct_change': 'Monthly Change (%)', 'time_label': 'Time Period'},
                markers=True
            )

            st.plotly_chart(fig_pct, use_container_width=True)
            st.plotly_chart(fig, use_container_width=True)

            # Calculate overall average bounds for freight index
            avg_freight_pct_change = price_forecast['freight_pct_change'].mean()
            avg_freight_lower_pct = price_forecast['freight_lower_pct'].mean()
            avg_freight_upper_pct = price_forecast['freight_upper_pct'].mean()

            # Display overall percent changes
            st.subheader("Overall Freight Index Forecast Percent Changes")
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Avg Lower Bound %", f"{avg_freight_lower_pct:.2f}%")
            with col2:
                st.metric("Avg Change %", f"{avg_freight_pct_change:.2f}%")
            with col3:
                st.metric("Avg Upper Bound %", f"{avg_freight_upper_pct:.2f}%")
        else:
            st.warning("No historical freight data or forecast available")

    # Citations
    st.subheader("Source Citations")
    st.markdown("""
    - **[4] Shipped.com. (n.d.). Shipping container price indexes. Retrieved January 13, 2025, from https://shipped.com/shipping-container-price-indexes.php
    - **[5] Trading Economics. (n.d.). Containerized freight index. Retrieved January 13, 2025, from https://tradingeconomics.com/commodity/containerized-freight-index
    """)

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
    - **Waste Reduction**: "modular construction was 40-60% quicker and produced 70% less onsite waste than traditional building methods" [2]
    - **Material Usage**: "a container home can be constructed of about 75% recycled materials by weight" [3]
    - **Construction Timeline**: Based on data from ArchJosieDeAsisDP.pdf study comparing container housing construction with traditional methods [1]
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

        - **Container Price Change**: -5% to 5% (Based on market forecasts)
        - **Annual Rental Income**: 
        - Low Income: ₱15,460-16,000
        - Middle Income: ₱30,000-31,000  
        - Upper Income: ₱59,000-60,000
        - **Expected Lifespan**: 
        - Traditional Housing: 80 to 150 years (Based on Krull's research)
        - Container Housing: 40 to 150 years (Based on Krull's research)
        - **Maintenance Costs**: 
        - Traditional Housing: 1-3% of property value
        - Container Housing: 0.8-2.5% (Lower due to durability but includes rust protection)
        - **Government Subsidies**: 15-30% of initial cost
        - **Interest Subsidies**: 3-5% reduction in interest rates
        """)
    
        # Clean and prepare data for visualization
        if 'annual_roi_percentage' in sensitivity_results.columns and 'payback_years' in sensitivity_results.columns:
            # Convert columns to numeric, coercing errors to NaN
            for col in ['annual_roi_percentage', 'payback_years']:
                sensitivity_results[col] = pd.to_numeric(sensitivity_results[col], errors='coerce')
            
            # Round values to 2 decimal places for cleaner display
            sensitivity_results['annual_roi_percentage'] = sensitivity_results['annual_roi_percentage'].round(2)
            sensitivity_results['payback_years'] = sensitivity_results['payback_years'].round(2)
            
            # Filter out invalid values (NaN, infinite, etc.)
            valid_data = sensitivity_results[
                (sensitivity_results['annual_roi_percentage'].notna()) &
                (sensitivity_results['payback_years'].notna()) &
                (np.isfinite(sensitivity_results['annual_roi_percentage'])) &
                (np.isfinite(sensitivity_results['payback_years'])) &
                (sensitivity_results['payback_years'] > 0) &
                (sensitivity_results['payback_years'] < 100)  # Cap at 100 years
            ]
            
            if valid_data.empty:
                st.warning("No valid analysis data available. Please check your simulation parameters.")
            else:
                # Interactive parameters for filtering results with industry standard defaults
                st.subheader("Filter Simulation Results")
                
                # Investment standards information
                st.info("""
                **Investment Standards Reference:**
                - **Minimum ROI:** Industry standard for real estate investments typically ranges from 8-12% annually
                - **Maximum Payback Period:** Residential real estate investors typically target 20-30 years
                """)
                
                col1, col2 = st.columns(2)
                
                with col1:
                    roi_min = valid_data['annual_roi_percentage'].min()
                    roi_max = valid_data['annual_roi_percentage'].max()

                    # Set as 1% cause it shows all the models (yay)
                    default_min_roi = 1.0
                    if roi_min > default_min_roi:
                        default_min_roi = roi_min
                    
                    min_roi = st.slider(
                        "Minimum ROI (%)", 
                        min_value=float(roi_min),
                        max_value=float(roi_max),
                        value=float(default_min_roi),
                        key="min_roi_slider"
                    )
                
                with col2:
                    payback_min = valid_data['payback_years'].min()
                    payback_max = min(valid_data['payback_years'].max(), 100)  # Cap at 100 years
                    # Set 30 years as the default maximum payback period (industry standard)
                    default_max_payback = 30.0
                    if payback_max < default_max_payback:
                        default_max_payback = payback_max
                    
                    max_payback = st.slider(
                        "Maximum Payback Period (Years)", 
                        min_value=float(payback_min),
                        max_value=float(payback_max),
                        value=float(default_max_payback),
                        key="max_payback_slider"
                    )
                
                # Apply filters
                filtered_results = valid_data[
                    (valid_data['annual_roi_percentage'] >= min_roi) &
                    (valid_data['payback_years'] <= max_payback)
                ]
                
                # Model performance across scenarios
                st.subheader("Model Performance Across Scenarios")
                
                if filtered_results.empty:
                    st.warning("No results match the current filter criteria.")
                else:
                    # Find the best performing model based on average ROI
                    model_summary = filtered_results.groupby('model_name').agg({
                        'annual_roi_percentage': ['mean', 'min', 'max'],
                        'payback_years': ['mean', 'min', 'max']
                    })
                    
                    # Flatten multi-index columns
                    model_summary.columns = [f"{col[0]}_{col[1]}" for col in model_summary.columns]
                    model_summary = model_summary.reset_index()
                    
                    # Find best model based on ROI
                    best_roi_model = model_summary.loc[model_summary['annual_roi_percentage_mean'].idxmax()]
                    
                    # Summary box with key insights
                    st.success(f"""
                    ### Key Insights

                    **Best Performing Model: {best_roi_model['model_name']}**
                    - Average ROI: {best_roi_model['annual_roi_percentage_mean']:.2f}%
                    - Average Payback Period: {best_roi_model['payback_years_mean']:.2f} years

                    **Investment Assessment:**
                    {best_roi_model['model_name']} outperforms other housing models with an average ROI of {best_roi_model['annual_roi_percentage_mean']:.2f}%, 
                    which {'exceeds' if best_roi_model['annual_roi_percentage_mean'] > 10 else 'is close to'} the 10% industry benchmark.

                    The payback period of {best_roi_model['payback_years_mean']:.2f} years is 
                    {'well within' if best_roi_model['payback_years_mean'] < 25 else 'slightly above' if best_roi_model['payback_years_mean'] < 30 else 'beyond'} 
                    the typical 20-30 year target range for real estate investments.
                    """)
                    
                    # Add ROI classification to model summary
                    model_summary['roi_classification'] = pd.cut(
                        model_summary['annual_roi_percentage_mean'],
                        bins=[-float('inf'), 6, 10, 15, float('inf')],
                        labels=['Poor', 'Acceptable', 'Good', 'Excellent']
                    )

                    # Display ROI classification details
                    st.subheader("ROI Classification")
                    st.info("""
                    **Investment Standards Reference:**
                    - **Poor ROI:** Less than 6% (below industry minimum)
                    - **Acceptable ROI:** 6-10% (meets basic investment standards)
                    - **Good ROI:** 10-15% (strong performance)
                    - **Excellent ROI:** 15%+ (exceptional performance)
                    """)

                    # Display classification results
                    st.dataframe(
                        model_summary[['model_name', 'annual_roi_percentage_mean', 'roi_classification']]
                        .sort_values('annual_roi_percentage_mean', ascending=False)
                        .rename(columns={
                            'model_name': 'Housing Model',
                            'annual_roi_percentage_mean': 'Average ROI (%)',
                            'roi_classification': 'Classification'
                        }),
                        use_container_width=True
                    )
                    
                    # ROI distribution by model with clearer formatting
                    fig = px.box(
                        filtered_results,
                        x='model_name',
                        y='annual_roi_percentage',
                        color='model_name',
                        title="Annual ROI Distribution by Housing Model",
                        labels={'annual_roi_percentage': 'Annual ROI (%)', 'model_name': 'Housing Model'}
                    )
                    fig.update_layout(
                        xaxis_title="Housing Model", 
                        yaxis_title="Annual ROI (%)",
                        yaxis=dict(tickformat=".2f")  # Format y-axis to 2 decimal places
                    )
                    # Add a horizontal line for the 10% ROI benchmark
                    fig.add_shape(
                        type="line",
                        x0=-0.5,
                        y0=10,
                        x1=len(filtered_results['model_name'].unique()) - 0.5,
                        y1=10,
                        line=dict(color="red", width=2, dash="dash"),
                    )
                    fig.add_annotation(
                        x=0,
                        y=10,
                        xref="x",
                        yref="y",
                        text="Industry Standard (10%)",
                        showarrow=True,
                        arrowhead=2,
                        ax=50,
                        ay=-30,
                    )
                    st.plotly_chart(fig, use_container_width=True)
                    
                    # Add explanation about how to read the boxplot
                    st.info("""
                    **How to Read the ROI Boxplot:**
                    - The **box** shows the middle 50% of ROI values
                    - The **horizontal line** inside the box shows the median ROI
                    - The **whiskers** extend to the minimum and maximum values (excluding outliers)
                    - The **red dashed line** represents the 10% industry standard benchmark for ROI
                    - Higher ROI values are better (higher return on investment)
                    """)
                    
                    # Payback period distribution
                    fig = px.box(
                        filtered_results,
                        x='model_name',
                        y='payback_years',
                        color='model_name',
                        title="Payback Period Distribution by Housing Model",
                        labels={'payback_years': 'Payback Period (Years)', 'model_name': 'Housing Model'}
                    )
                    fig.update_layout(
                        xaxis_title="Housing Model", 
                        yaxis_title="Payback Period (Years)",
                        yaxis=dict(tickformat=".2f")  # Format y-axis to 2 decimal places
                    )
                    # Add a horizontal line for the 30-year payback benchmark
                    fig.add_shape(
                        type="line",
                        x0=-0.5,
                        y0=30,
                        x1=len(filtered_results['model_name'].unique()) - 0.5,
                        y1=30,
                        line=dict(color="red", width=2, dash="dash"),
                    )
                    fig.add_annotation(
                        x=0,
                        y=30,
                        xref="x",
                        yref="y",
                        text="Industry Standard (30 years)",
                        showarrow=True,
                        arrowhead=2,
                        ax=50,
                        ay=30,
                    )
                    st.plotly_chart(fig, use_container_width=True)
                    
                    # Add explanation about how to read the boxplot
                    st.info("""
                    **How to Read the Payback Period Boxplot:**
                    - The **box** shows the middle 50% of payback period values
                    - The **horizontal line** inside the box shows the median payback period
                    - The **whiskers** extend to the minimum and maximum values (excluding outliers)
                    - The **red dashed line** represents the 30-year industry standard maximum payback period
                    - Lower payback period values are better (quicker return on investment)
                    """)
                    
                    # Parameter impact analysis
                    st.subheader("Parameter Impact Analysis")
                    
                    # Select parameter to analyze
                    parameter = st.selectbox(
                        "Select Parameter to Analyze",
                        ["container_price_increase", "rental_income", "expected_lifespan"]
                    )
                    
                    # Select model to analyze if available
                    available_models = filtered_results['model_name'].unique()
                    if len(available_models) > 0:
                        model = st.selectbox(
                            "Select Housing Model",
                            options=available_models
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
                            yaxis_title="Annual ROI (%)",
                            xaxis=dict(tickformat=".2f"),
                            yaxis=dict(tickformat=".2f")
                        )
                        st.plotly_chart(fig, use_container_width=True)
                        
                        # Add explanation for the scatter plot
                        parameter_explanation = {
                            "container_price_increase": """
                                - Each point represents a simulation scenario with different parameters
                                - The x-axis shows the percentage increase in container prices
                                - Higher ROI (y-axis) values are better
                                - Points are colored by payback period (darker blue = longer payback period)
                                - If points trend downward as container price increases, it means higher prices reduce ROI
                            """,
                            "rental_income": """
                                - Each point represents a simulation scenario with different parameters
                                - The x-axis shows the annual rental income in PHP
                                - Higher ROI (y-axis) values are better
                                - Points are colored by payback period (darker blue = longer payback period)
                                - If points trend upward as rental income increases, it means higher rental income improves ROI
                            """,
                            "expected_lifespan": """
                                - Each point represents a simulation scenario with different parameters
                                - The x-axis shows the expected lifespan of the housing unit in years
                                - Higher ROI (y-axis) values are better
                                - Points are colored by payback period (darker blue = longer payback period)
                                - If points trend upward as lifespan increases, it means longer lifespans improve ROI
                            """
                        }
                        
                        st.info(f"""
                        **How to Read This Scatter Plot:**
                        {parameter_explanation.get(parameter, "Each point represents a different simulation scenario.")}
                        """)
                        
                        # Calculate correlation to provide insights
                        correlation = model_data[[parameter, 'annual_roi_percentage']].corr().iloc[0, 1]
                        
                        correlation_interpretation = ""
                        if abs(correlation) < 0.3:
                            correlation_interpretation = f"has a weak impact on"
                        elif abs(correlation) < 0.7:
                            correlation_interpretation = f"moderately impacts"
                        else:
                            correlation_interpretation = f"strongly impacts"
                            
                        direction = "increases" if correlation > 0 else "decreases"
                        
                        st.success(f"""
                        **Key Insight:**
                        For the {model} model, {parameter.replace('_', ' ')} {correlation_interpretation} the ROI.
                        As {parameter.replace('_', ' ')} increases, ROI generally {direction}.
                        Correlation coefficient: {correlation:.2f}
                        """)
                    else:
                        st.warning("No models available for analysis with current filters.")
                    
                    # Optimal scenarios section
                    st.subheader("Best Performance Scenarios")
                    
                    if not optimal_scenarios.empty:
                        # Format and display the optimal scenarios
                        display_cols = ['model_name', 'annual_roi_percentage', 'payback_years', 
                                      'container_price_increase', 'rental_income', 'expected_lifespan']
                        
                        # Make a copy to avoid SettingWithCopyWarning
                        display_df = optimal_scenarios[display_cols].copy()
                        
                        # Round values
                        for col in ['annual_roi_percentage', 'payback_years', 'container_price_increase']:
                            if col in display_df.columns:
                                display_df[col] = display_df[col].round(2)
                        
                        st.dataframe(
                            display_df.sort_values('annual_roi_percentage', ascending=False),
                            use_container_width=True
                        )
                    
                    # Citations
                    st.info("""
                    **Citations**:
                    [WIP]
                    [6] Krull, L. R. (2022). Comparison between shipping container homes and regular stick-built homes in California. California Polytechnic State University, San Luis Obispo, California.
                    - Traditional stick-built homes typically last 80 to 150 years: "A typical stick-built home can last anywhere from eighty to one hundred fifty years" (p. 1)
                    - Container homes "if not taken care of can last as short as 40-50 years, although have the potential with proper care to last as long as a regular home" (p. 11)

                    [7] Assistance.PH. (2024, May 14). Government provides subsidies for 4PH Pambansang Pabahay borrowers. Retrieved from https://assistance.ph/government-subsidies-4ph-pambansang-pabahay-borrowers/
                    - DHSUD subsidizes up to 5% of loan interest rates for affordable housing programs

                    [8] Events2HVAC. (2018, November 29). Energy projects payback comparison. Retrieved from https://www.events2hvac.com/post/energy-projects-payback-comparison
                    - Public housing facilities HVAC projects have payback periods of 7.7 years (major) and 8.6 years (minor)

                    [9] Mashvisor. (2019, November 26). What is the average real estate return on investment in the US? Retrieved from https://www.mashvisor.com/blog/real-estate-return-on-investment-average/
                    - Good ROI ranges from 6% to 8% nationally in the US

                    [10] Mashvisor. (2023, May 4). What is a realistic return on investment in real estate? Retrieved from https://www.mashvisor.com/blog/realistic-return-on-investment/
                    - Different property types have varying ROI: residential rentals (10.6%), REITs (11.8%), commercial properties (9.5%)
                    """)
        else:
            st.error("Required columns not found in sensitivity analysis data.")
    else:
        st.warning("No sensitivity analysis data available. Please run the sensitivity analysis first.")

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
        
        # Add income segment selection
        income_segment = st.radio(
            "Income Segment",
            ["Low Income", "Middle Income", "Upper Income"],
            index=0,  # Default to Low Income
            key="income_segment_radio"
        )
        
        # Set rental income based on selected segment
        if income_segment == "Low Income":
            rental_income = st.number_input(
                "Annual Rental Income (₱)",
                min_value=5000,
                max_value=20000,
                value=15460,  # Default based on research
                step=1000,
                help="Based on 8.68% of annual income for low-income households (₱178,107)"
            )
        elif income_segment == "Middle Income":
            rental_income = st.number_input(
                "Annual Rental Income (₱)",
                min_value=20000,
                max_value=40000,
                value=30358,  # Default based on research
                step=1000,
                help="Based on 11.08% of annual income for middle-income households (₱273,987)"
            )
        else:  # Upper Income
            rental_income = st.number_input(
                "Annual Rental Income (₱)",
                min_value=40000,
                max_value=70000,
                value=59295,  # Default based on research
                step=1000,
                help="Based on 10.90% of annual income for upper-income households (₱543,993)"
            )
    
    with col2:
        # Update lifespan slider to match research parameters
        expected_lifespan = st.slider(
            "Expected Lifespan (Years)",
            min_value=40,
            max_value=150,
            value=80,
            step=10,
            key="lifespan_slider",  # Add unique key
            help="Traditional housing: 80-150 years, Container housing: 40-150 years (Krull's research)"
        )
        
        # Add housing type selection for maintenance
        housing_type = st.radio(
            "Housing Type",
            ["Traditional", "Container"],
            index=0,  # Default to Traditional
            key="housing_type_radio"
        )
        
        # Set maintenance % based on housing type
        if housing_type == "Traditional":
            maintenance_pct = st.slider(
                "Annual Maintenance (% of Investment)",
                min_value=1.0,
                max_value=3.0,
                value=2.0,
                step=0.1,
                key="maintenance_slider",  # Add unique key
                help="Traditional housing maintenance is typically 1-3% annually"
            ) / 100
        else:
            maintenance_pct = st.slider(
                "Annual Maintenance (% of Investment)",
                min_value=0.8,
                max_value=2.5,
                value=1.5,
                step=0.1,
                key="maintenance_slider",  # Add unique key
                help="Container housing maintenance is typically 0.8-2.5% annually"
            ) / 100

    # Add subsidy options
    st.subheader("Government Support Options")
    col1, col2 = st.columns(2)
    
    with col1:
        include_subsidy = st.checkbox("Include Government Subsidy", value=True)
        if include_subsidy:
            subsidy_pct = st.slider(
                "Government Subsidy (%)",
                min_value=15.0,
                max_value=30.0,
                value=20.0,
                step=1.0,
                help="Government subsidies for affordable housing range from 15-30%"
            )
        else:
            subsidy_pct = 0.0
    
    with col2:
        include_interest_subsidy = st.checkbox("Include Interest Rate Subsidy", value=True)
        if include_interest_subsidy:
            interest_subsidy = st.slider(
                "Interest Rate Subsidy (%)",
                min_value=3.0,
                max_value=5.0,
                value=4.0,
                step=0.5,
                help="DHSUD subsidizes up to 5% of loan interest rates"
            )
        else:
            interest_subsidy = 0.0

    # Calculate ROI for each housing model
    roi_results = []
    
    # Iterate through housing models
    for _, model in housing_models.iterrows():
        # Adjust investment based on container price change
        adjusted_investment = model['total_cost']
        if 'Container' in model['model_name']:
            adjusted_investment = model['total_cost'] * (1 + container_price_change/100)
        
        # Apply government subsidy if enabled
        if include_subsidy:
            adjusted_investment = adjusted_investment * (1 - subsidy_pct/100)
        
        # Calculate annual maintenance cost
        maintenance_cost = adjusted_investment * maintenance_pct
        
        # Calculate annual net income
        annual_net_income = rental_income - maintenance_cost
        
        # Apply interest subsidy effect if enabled (simplified)
        base_discount_rate = 0.05  # 5% base discount rate
        if include_interest_subsidy:
            discount_rate = base_discount_rate - (interest_subsidy/100)
            # Discount rate cannot be negative
            discount_rate = max(0.01, discount_rate)
        else:
            discount_rate = base_discount_rate
        
        # Calculate payback period
        payback_years = adjusted_investment / annual_net_income if annual_net_income > 0 else float('inf')
        
        # Calculate ROI
        annual_roi = (annual_net_income / adjusted_investment) * 100 if adjusted_investment > 0 else 0
        
        # Calculate net present value (simplified)
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
    
    # Add ROI classification
    roi_df['roi_classification'] = pd.cut(
        roi_df['annual_roi_percentage'],
        bins=[-float('inf'), 6, 10, 15, float('inf')],
        labels=['Poor', 'Acceptable', 'Good', 'Excellent']
    )
    
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
        color='roi_classification',
        title="Annual ROI by Housing Model",
        labels={'annual_roi_percentage': 'Annual ROI (%)', 'model_name': 'Housing Model'},
        color_discrete_map={
            'Poor': '#FF9999',
            'Acceptable': '#FFCC99',
            'Good': '#99CC99', 
            'Excellent': '#66BB66'
        }
    )
    
    # Add ROI benchmark lines
    fig.add_shape(
        type="line",
        x0=-0.5,
        y0=6,
        x1=len(roi_df['model_name'].unique()) - 0.5,
        y1=6,
        line=dict(color="red", width=1, dash="dash"),
    )
    fig.add_shape(
        type="line",
        x0=-0.5,
        y0=10,
        x1=len(roi_df['model_name'].unique()) - 0.5,
        y1=10,
        line=dict(color="green", width=1, dash="dash"),
    )
    fig.add_shape(
        type="line",
        x0=-0.5,
        y0=15,
        x1=len(roi_df['model_name'].unique()) - 0.5,
        y1=15,
        line=dict(color="blue", width=1, dash="dash"),
    )
    
    fig.update_layout(xaxis_title="Housing Model", yaxis_title="Annual ROI (%)")
    st.plotly_chart(fig, use_container_width=True)
    
    # ROI classification info
    st.info("""
    **ROI Classification:**
    - **Poor:** Less than 6% (below industry minimum)
    - **Acceptable:** 6-10% (meets basic investment standards)
    - **Good:** 10-15% (strong performance)
    - **Excellent:** 15%+ (exceptional performance)
    """)
    
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
    
    # Payback feasibility check
    feasible_models = []
    for _, row in roi_df.iterrows():
        if 'Container' in row['model_name']:
            min_lifespan = 40  # Minimum container lifespan per Krull's research
        else:
            min_lifespan = 80  # Minimum traditional housing lifespan
            
        if row['payback_years'] < min_lifespan:
            feasible_models.append(row['model_name'])
    
    if feasible_models:
        st.success(f"Models with feasible payback periods (less than their minimum expected lifespan): {', '.join(feasible_models)}")
    else:
        st.warning("No models have payback periods less than their minimum expected lifespan. Consider adjusting parameters.")
    
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
    **Sources:**
    - ROI classifications based on real estate investment industry standards
    - Rental income values based on Philippine Statistics Authority data
                Philippine Statistics Authority. (2024, August 15). Average annual family income in 2023 is estimated at PhP 353.23 thousand. 
                Family Income and Expenditure Survey. Retrieved [insert retrieval date], from https://psa.gov.ph/statistics/income-expenditure/fies
    - Lifespan ranges from [6]
    - Interest subsidies based on DHSUD housing programs
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