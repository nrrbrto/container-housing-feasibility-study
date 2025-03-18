COPY container_prices_raw(ship_date, freight_index, base_price, source)
FROM 'C:\Users\Banette\Documents\Container Housing Feasibility\data-practice\processed\Compounded Shipping Container Data (PROCESSED).xlsx'
WITH (FORMAT CSV, HEADER true, DELIMITER ',');