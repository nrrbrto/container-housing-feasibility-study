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

-- Analyze price trends by year and quarter
SELECT 
    EXTRACT(YEAR FROM date) AS year,
    EXTRACT(QUARTER FROM date) AS quarter,
    AVG(price_usd) AS avg_price,
    MAX(price_usd) - MIN(price_usd) AS price_range,
    ROUND(AVG(percent_change), 2) AS avg_percent_change
FROM container_prices
GROUP BY EXTRACT(YEAR FROM date), EXTRACT(QUARTER FROM date)
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