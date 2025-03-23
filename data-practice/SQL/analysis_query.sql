-- Compare housing models by cost efficiency
SELECT 
    model_name,
    total_cost,
    (SELECT total_cost FROM housing_models WHERE model_name = 'Traditional Housing') - total_cost AS cost_savings,
    ROUND(((SELECT total_cost FROM housing_models WHERE model_name = 'Traditional Housing') - total_cost) / 
    (SELECT total_cost FROM housing_models WHERE model_name = 'Traditional Housing') * 100, 2) AS savings_percentage,
    ROUND(total_cost / (SELECT total_cost FROM housing_models WHERE model_name = 'Traditional Housing') * 100, 2) AS percent_of_traditional,
    construction_time_days
FROM housing_models
ORDER BY total_cost;

SELECT 
    EXTRACT(YEAR FROM ship_date) AS year,
    EXTRACT(QUARTER FROM ship_date) AS quarter,
    AVG(base_price) AS avg_price,
    MAX(base_price) - MIN(base_price) AS price_range,
    (MAX(base_price) - MIN(base_price))/MIN(base_price) * 100 AS price_range_pct
FROM shipping_container_prices
GROUP BY EXTRACT(YEAR FROM ship_date), EXTRACT(QUARTER FROM ship_date)
ORDER BY year, quarter;

-- Create comprehensive dashboard query
SELECT 
    m.model_name,
    m.total_cost,
    m.cost_per_sqm,
    m.construction_time_days,
    m.waste_percentage,
    ROUND(((SELECT total_cost FROM housing_models WHERE model_name = 'Traditional Housing') - m.total_cost) / 
        (SELECT total_cost FROM housing_models WHERE model_name = 'Traditional Housing') * 100, 2) AS cost_efficiency,
    ROUND(((SELECT construction_time_days FROM housing_models WHERE model_name = 'Traditional Housing') - m.construction_time_days) / 
        (SELECT construction_time_days FROM housing_models WHERE model_name = 'Traditional Housing') * 100, 2) AS time_efficiency,
    ROUND(((SELECT waste_percentage FROM housing_models WHERE model_name = 'Traditional Housing') - m.waste_percentage) / 
        (SELECT waste_percentage FROM housing_models WHERE model_name = 'Traditional Housing') * 100, 2) AS waste_reduction,
    r.annual_roi_percentage,
    r.payback_years
FROM housing_models m
JOIN housing_roi r ON m.model_name = r.model_name
ORDER BY cost_efficiency DESC;