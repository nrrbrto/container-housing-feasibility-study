

-- Analysis views for shipping container data (processed .csv files)


-- 1. Route Analysis View
DROP VIEW IF EXISTS route_analysis;

CREATE VIEW route_analysis AS
SELECT 
    origin,
    destination,
    COUNT(*) AS shipment_count,
    AVG(freight_index) AS avg_freight_index,
    AVG(base_price) AS avg_base_price,
    AVG(base_price / NULLIF(container_qty, 0)) AS avg_price_per_container,
    -- Calculate average transit days (only for delivered shipments)
    AVG(
        CASE 
            WHEN status = 'delivered' OR status = 'dlvrd' OR status = 'DELIVERED' 
            THEN (delivery_date - ship_date)
            ELSE NULL
        END
    ) AS avg_transit_days
FROM shipping_container_raw
WHERE origin IS NOT NULL AND destination IS NOT NULL
GROUP BY origin, destination
ORDER BY shipment_count DESC;

-- 2. Producer Performance View
DROP VIEW IF EXISTS producer_performance;

CREATE VIEW producer_performance AS
SELECT 
    producer,
    producer_type,
    COUNT(*) AS shipment_count,
    SUM(container_qty) AS total_containers,
    AVG(container_qty) AS avg_containers_per_shipment,
    AVG(base_price) AS avg_base_price,
    COALESCE(
        AVG(
            CASE 
                WHEN status = 'delivered' OR status = 'dlvrd' OR status = 'DELIVERED' 
                THEN (delivery_date - ship_date)
                ELSE NULL
            END
        ), 0  -- Default value if the average is null
    ) AS avg_delivery_days
FROM shipping_container_raw
WHERE producer IS NOT NULL
GROUP BY producer, producer_type
ORDER BY shipment_count DESC;

-- 3. Priority Impact Analysis
DROP VIEW IF EXISTS priority_impact;

CREATE VIEW priority_impact AS
SELECT 
    priority,
    COUNT(*) AS shipment_count,
    AVG(base_price) AS avg_base_price,
    AVG(
        CASE 
            WHEN status = 'delivered' OR status = 'dlvrd' OR status = 'DELIVERED' 
            THEN (delivery_date - ship_date)
            ELSE NULL
        END
    ) AS avg_delivery_days,
    -- Analyze price premium over overall average base price
    (AVG(base_price) / 
        COALESCE(
            NULLIF(
                (SELECT AVG(base_price) FROM shipping_container_raw), 0
            ), 1  -- Default value if the overall average is 0 or null
        )
    ) * 100 - 100 AS price_premium_percent
FROM shipping_container_raw
WHERE priority IS NOT NULL
GROUP BY priority
ORDER BY avg_delivery_days;

-- 4. Monthly Shipping Volume Analysis
DROP VIEW IF EXISTS monthly_shipping_volume;

CREATE VIEW monthly_shipping_volume AS
SELECT 
    DATE_TRUNC('month', ship_date)::DATE AS month,
    COUNT(*) AS shipment_count,
    SUM(container_qty) AS total_containers,
    AVG(freight_index) AS avg_freight_index,
    SUM(base_price) AS total_shipping_cost
FROM shipping_container_raw
WHERE ship_date IS NOT NULL  -- Exclude rows with null ship_date
GROUP BY DATE_TRUNC('month', ship_date)
ORDER BY month;


-- Views
SELECT * FROM route_analysis;
SELECT * FROM producer_performance;
SELECT * FROM priority_impact;
SELECT * FROM monthly_shipping_volume ORDER BY month DESC;