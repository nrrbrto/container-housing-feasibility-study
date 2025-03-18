-- Efficiency Metrics Table
CREATE TABLE efficiency_metrics (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL,
    cost_efficiency DECIMAL(5,2) NOT NULL,  -- %
    time_efficiency DECIMAL(5,2) NOT NULL,  -- %
    waste_reduction DECIMAL(5,2) NOT NULL,  -- %
    material_usage DECIMAL(5,2) NOT NULL,   -- %
    citation TEXT                           
);

-- Resource Usage Table
CREATE TABLE resource_usage (
    id SERIAL PRIMARY KEY,
    resource_type VARCHAR(50) NOT NULL,     -- e.g., Construction Waste, Material Usage
    traditional_usage INTEGER NOT NULL,     -- % (baseline = 100)
    container_usage INTEGER NOT NULL,       -- % (baseline = 100)
    citation TEXT                          
);

-- Cost Breakdown Table for Conceptual Models
CREATE TABLE cost_breakdownConcMod (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL,        -- e.g., Container (Base), Container (Max)
    component_name VARCHAR(50) NOT NULL,    -- e.g., Container Cost, Fenestration, Alterations
    cost DECIMAL(12,2) NOT NULL,            -- Cost in PHP
    citation TEXT                           
);

----------------------------------------------------------------------------------------------------------------------------

-- Cost per Square Meter Table
CREATE TABLE cost_per_sqm (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL,
    cost_per_sqm DECIMAL(10,2) NOT NULL,  -- Cost per square meter in PHP
    total_cost DECIMAL(12,2) NOT NULL,    -- Total cost in PHP
    citation TEXT                         
);

-- Total Cost Comparison Table
CREATE TABLE total_cost_comparison (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL,
    total_cost DECIMAL(12,2) NOT NULL,    -- Total cost in PHP
    citation TEXT                         
);

-- Cost Breakdown Table
CREATE TABLE cost_breakdown (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL,        -- Name of the model (e.g., Traditional Housing, ODD Cubes, Container (Base), Container (Max))
    materials_cost DECIMAL(12,2) NOT NULL,  -- Cost of materials in PHP
    labor_cost DECIMAL(12,2) NOT NULL,      -- Cost of labor in PHP
    finishings_cost DECIMAL(12,2) NOT NULL, -- Cost of finishings in PHP
    total_cost DECIMAL(12,2) NOT NULL,      -- Total cost in PHP
    citation TEXT                           
);

-- Housing Models Table
CREATE TABLE housing_models (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL,
    total_cost DECIMAL(12,2) NOT NULL,
    cost_per_sqm DECIMAL(10,2) NOT NULL,
    construction_time_days INTEGER NOT NULL,
    waste_percentage DECIMAL(5,2) NOT NULL
);

-- Data for the housing_models table
INSERT INTO housing_models (model_name, total_cost, cost_per_sqm, construction_time_days, waste_percentage) 
VALUES 
    ('Traditional Housing', 708000, 29500, 150, 30),
    ('ODD Cubes Basic', 420000, 17500, 90, 15),
    ('Container (Base)', 323343, 13473, 68, 9),
    ('Container (Max)', 580005, 24167, 68, 9);