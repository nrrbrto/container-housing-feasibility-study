-- Run basic analysis
SELECT * FROM housing_roi;

-- Run sensitivity analysis with different parameters
EXEC analyze_housing_sensitivity 20, 15000, 30;
EXEC analyze_housing_sensitivity 50, 12000, 25;
EXEC analyze_housing_sensitivity 10, 18000, 35;