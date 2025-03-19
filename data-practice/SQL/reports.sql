-- Run basic analysis
SELECT * FROM housing_roi;

-- Run sensitivity analysis with different parameters
SELECT * FROM analyze_housing_sensitivity(20, 15000, 30);
SELECT * FROM analyze_housing_sensitivity(50, 12000, 25);
SELECT * FROM analyze_housing_sensitivity(10, 18000, 35);