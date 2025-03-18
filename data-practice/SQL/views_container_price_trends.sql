-- Container price trend analysis view
CREATE VIEW container_price_trends AS
SELECT 
    EXTRACT(YEAR FROM date) AS year,
    EXTRACT(QUARTER FROM date) AS quarter,
    AVG(price_usd) AS avg_price,
    MAX(price_usd) AS max_price,
    MIN(price_usd) AS min_price,
    MAX(price_usd) - MIN(price_usd) AS price_range,
    ROUND(AVG(percent_change), 2) AS avg_percent_change,
    CASE 
        WHEN AVG(percent_change) > 10 THEN 'Sharp Increase'
        WHEN AVG(percent_change) BETWEEN 2 AND 10 THEN 'Moderate Increase'
        WHEN AVG(percent_change) BETWEEN -2 AND 2 THEN 'Stable'
        WHEN AVG(percent_change) BETWEEN -10 AND -2 THEN 'Moderate Decrease'
        ELSE 'Sharp Decrease'
    END AS trend_classification
-- FROM container_prices
GROUP BY EXTRACT(YEAR FROM date), EXTRACT(QUARTER FROM date)
ORDER BY year, quarter;