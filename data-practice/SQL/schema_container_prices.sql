-- Create the shipping_container_raw table if it does not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'shipping_container_raw') THEN
        CREATE TABLE shipping_container_raw (
            id SERIAL PRIMARY KEY,
            container_id VARCHAR(20),
            ship_date DATE,
            delivery_date DATE,
            producer VARCHAR(100),
            producer_type VARCHAR(50),
            container_type VARCHAR(50),
            container_qty NUMERIC(10,1),
            origin VARCHAR(50),
            destination VARCHAR(50),
            freight_index NUMERIC(10,2),
            base_price NUMERIC(12,2),
            priority VARCHAR(20),
            status VARCHAR(20),
            import_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    END IF;
END $$;

-- Create the shipping_container_prices table if it does not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'shipping_container_prices') THEN
        CREATE TABLE shipping_container_prices (
            id SERIAL PRIMARY KEY,
            ship_date DATE NOT NULL,
            freight_index NUMERIC(10,2) NOT NULL,
            base_price NUMERIC(12,2) NOT NULL,
            calculated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    END IF;
END $$;

-- Create the idx_shipping_container_raw_ship_date index if it does not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_shipping_container_raw_ship_date') THEN
        CREATE INDEX idx_shipping_container_raw_ship_date ON shipping_container_raw(ship_date);
    END IF;
END $$;

-- Create the idx_shipping_container_price_ship_date index if it does not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_shipping_container_price_ship_date') THEN
        CREATE INDEX idx_shipping_container_price_ship_date ON shipping_container_prices(ship_date);
    END IF;
END $$;


-- Create the container_price_forecast table if it does not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'container_price_forecast') THEN
        CREATE TABLE container_price_forecast (
            id SERIAL PRIMARY KEY,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            time_index INTEGER NOT NULL,
            year_fraction NUMERIC(10,2) NOT NULL,
            avg_price NUMERIC(12,2),
            lower_bound NUMERIC(12,2),
            upper_bound NUMERIC(12,2),
            avg_freight_index NUMERIC(12,2),
            freight_lower_bound NUMERIC(12,2),
            freight_upper_bound NUMERIC(12,2),
            calculated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    END IF;
END $$;

-- Create an index for faster queries
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_container_price_forecast_year_month') THEN
        CREATE INDEX idx_container_price_forecast_year_month ON container_price_forecast(year, month);
    END IF;
END $$;