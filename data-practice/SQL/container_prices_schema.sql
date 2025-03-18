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