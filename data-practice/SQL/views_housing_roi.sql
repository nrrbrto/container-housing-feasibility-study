-- views.sql for PostgreSQL
-- Create view for ROI calculations

CREATE VIEW housing_roi AS
WITH params AS (
    -- NOTE: Replace these values with your research data or reasonable assumptions
    SELECT 
        25 AS expected_lifespan_years,
        0.03 AS annual_maintenance_pct_traditional,
        0.035 AS annual_maintenance_pct_container,
        12000 AS annual_rental_income
)

SELECT 
    h.model_name,
    h.total_cost AS initial_investment,
    ROUND(h.total_cost * 
        CASE 
            WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
            ELSE p.annual_maintenance_pct_container
        END, 2) AS annual_maintenance,
    p.annual_rental_income,
    p.annual_rental_income - (h.total_cost * 
        CASE 
            WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
            ELSE p.annual_maintenance_pct_container
        END) AS annual_net_income,
    ROUND(h.total_cost / (p.annual_rental_income - (h.total_cost * 
        CASE 
            WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
            ELSE p.annual_maintenance_pct_container
        END)), 2) AS payback_years,
    ROUND(((p.annual_rental_income - (h.total_cost * 
        CASE 
            WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
            ELSE p.annual_maintenance_pct_container
        END)) / h.total_cost) * 100, 2) AS annual_roi_percentage
FROM housing_models h
CROSS JOIN params p
ORDER BY annual_roi_percentage DESC;



