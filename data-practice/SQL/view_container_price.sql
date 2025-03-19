-- Drop the view if it exists
DROP VIEW IF EXISTS container_price_trends;

-- container_price_trends view
CREATE VIEW container_price_trends AS
SELECT 
    EXTRACT(YEAR FROM ship_date) AS year,
    EXTRACT(MONTH FROM ship_date) AS month,  -- Extract month instead of quarter
    AVG(freight_index) AS avg_freight_index,
    MAX(freight_index) AS max_freight_index,
    MIN(freight_index) AS min_freight_index,
    MAX(freight_index) - MIN(freight_index) AS freight_index_range,
    AVG(base_price) AS avg_base_price,
    MAX(base_price) AS max_base_price,
    MIN(base_price) AS min_base_price,
    -- Safe division with NULLIF to prevent division by zero
    CASE 
        WHEN (MAX(freight_index) - MIN(freight_index))/NULLIF(MIN(freight_index), 0) > 0.1 THEN 'High Volatility'
        WHEN (MAX(freight_index) - MIN(freight_index))/NULLIF(MIN(freight_index), 0) > 0.05 THEN 'Moderate Volatility'
        ELSE 'Stable'
    END AS freight_index_trend
FROM shipping_container_raw
GROUP BY EXTRACT(YEAR FROM ship_date), EXTRACT(MONTH FROM ship_date)  -- Group by year and month
ORDER BY year, month;  -- Order by year and month

-- Test the view
SELECT * FROM container_price_trends;