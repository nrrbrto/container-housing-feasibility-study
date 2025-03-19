-- Dashboard view combining multiple metrics for visualization
CREATE VIEW housing_dashboard AS
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