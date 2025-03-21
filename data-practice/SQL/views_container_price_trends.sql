-- Drop the view if it exists
DROP VIEW IF EXISTS container_price_trends;

-- container_price_trends view with both price and freight index
CREATE VIEW container_price_trends AS
SELECT 
    EXTRACT(YEAR FROM ship_date) AS year,
    EXTRACT(month FROM ship_date) AS month,
    -- Price metrics
    AVG(base_price) AS avg_price,
    MAX(base_price) AS max_price,
    MIN(base_price) AS min_price,
    MAX(base_price) - MIN(base_price) AS price_range,
    -- Freight index metrics
    AVG(freight_index) AS avg_freight_index,
    MAX(freight_index) AS max_freight_index,
    MIN(freight_index) AS min_freight_index,
    MAX(freight_index) - MIN(freight_index) AS freight_index_range,
    -- Classification for trend analysis
    CASE 
        WHEN LAG(AVG(base_price)) OVER (ORDER BY EXTRACT(YEAR FROM ship_date), EXTRACT(month FROM ship_date)) IS NULL THEN 'Initial'
        WHEN (AVG(base_price) - LAG(AVG(base_price)) OVER (ORDER BY EXTRACT(YEAR FROM ship_date), EXTRACT(month FROM ship_date))) / 
            NULLIF(LAG(AVG(base_price)) OVER (ORDER BY EXTRACT(YEAR FROM ship_date), EXTRACT(month FROM ship_date)), 0) * 100 > 10 
        THEN 'Sharp Increase'
        WHEN (AVG(base_price) - LAG(AVG(base_price)) OVER (ORDER BY EXTRACT(YEAR FROM ship_date), EXTRACT(month FROM ship_date))) / 
            NULLIF(LAG(AVG(base_price)) OVER (ORDER BY EXTRACT(YEAR FROM ship_date), EXTRACT(month FROM ship_date)), 0) * 100 BETWEEN 2 AND 10 
        THEN 'Moderate Increase'
        WHEN (AVG(base_price) - LAG(AVG(base_price)) OVER (ORDER BY EXTRACT(YEAR FROM ship_date), EXTRACT(month FROM ship_date))) / 
            NULLIF(LAG(AVG(base_price)) OVER (ORDER BY EXTRACT(YEAR FROM ship_date), EXTRACT(month FROM ship_date)), 0) * 100 BETWEEN -2 AND 2 
        THEN 'Stable'
        WHEN (AVG(base_price) - LAG(AVG(base_price)) OVER (ORDER BY EXTRACT(YEAR FROM ship_date), EXTRACT(month FROM ship_date))) / 
            NULLIF(LAG(AVG(base_price)) OVER (ORDER BY EXTRACT(YEAR FROM ship_date), EXTRACT(month FROM ship_date)), 0) * 100 BETWEEN -10 AND -2 
        THEN 'Moderate Decrease'
        ELSE 'Sharp Decrease'
    END AS trend_classification
FROM shipping_container_prices
GROUP BY EXTRACT(YEAR FROM ship_date), EXTRACT(month FROM ship_date)
ORDER BY year, month;