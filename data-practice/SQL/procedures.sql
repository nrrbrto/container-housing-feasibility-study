-- Create stored procedure for sensitivity analysis
CREATE OR ALTER PROCEDURE analyze_housing_sensitivity
    @p_container_price_increase DECIMAL,
    @p_rental_income DECIMAL,
    @p_expected_lifespan_years INT
AS
BEGIN
    WITH params AS (
        SELECT 
            @p_expected_lifespan_years AS expected_lifespan_years,
            0.03 AS annual_maintenance_pct_traditional,
            0.035 AS annual_maintenance_pct_container,
            @p_rental_income AS annual_rental_income
    )
    SELECT 
        h.model_name,
        CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + @p_container_price_increase/100)
            ELSE h.total_cost
        END AS adjusted_investment,
        ROUND(CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + @p_container_price_increase/100)
            ELSE h.total_cost
        END * 
            CASE 
                WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
                ELSE p.annual_maintenance_pct_container
            END, 2) AS annual_maintenance,
        p.annual_rental_income,
        p.annual_rental_income - (CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + @p_container_price_increase/100)
            ELSE h.total_cost
        END * 
            CASE 
                WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
                ELSE p.annual_maintenance_pct_container
            END) AS annual_net_income,
        ROUND((CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + @p_container_price_increase/100)
            ELSE h.total_cost
        END) / (p.annual_rental_income - (CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + @p_container_price_increase/100)
            ELSE h.total_cost
        END * 
            CASE 
                WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
                ELSE p.annual_maintenance_pct_container
            END)), 2) AS payback_years,
        ROUND(((p.annual_rental_income - (CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + @p_container_price_increase/100)
            ELSE h.total_cost
        END * 
            CASE 
                WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
                ELSE p.annual_maintenance_pct_container
            END)) / (CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + @p_container_price_increase/100)
            ELSE h.total_cost
        END)) * 100, 2) AS annual_roi_percentage
    FROM housing_models h
    CROSS JOIN params p
    ORDER BY annual_roi_percentage DESC;
END;
