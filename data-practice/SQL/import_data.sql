-- Insert data into cost_per_sqm table
INSERT INTO cost_per_sqm (model_name, cost_per_sqm, total_cost, citation)
VALUES
  ('Traditional Housing', 29500.00, 708000.00, '2024 rates: Total average of Ian Fulgar and ACDC Contractors'),
  ('ODD Cubes Basic', 17500.00, 420000.00, 'ODD Cubes Inc. base unit (₱360,000) + fenestration (₱60,000)'),
  ('Container (Base)', 13473.00, 323343.00, 'Sum of materials, labor, and base modifications'),
  ('Container (Max)', 24167.00, 580005.00, 'Sum of materials, labor, and premium modifications');

-- Insert data into total_cost_comparison table
INSERT INTO total_cost_comparison (model_name, total_cost, citation)
VALUES
  ('Traditional Housing', 708000.00, '2024 contractor rates: ₱29,500/sqm average for 24 sqm'),
  ('ODD Cubes Basic', 420000.00, 'ODD Cubes Inc. base unit (₱360,000) + fenestration (₱60,000)'),
  ('Container (Base)', 323343.00, 'Base estimate with modifications'),
  ('Container (Max)', 580005.00, 'Premium estimate with modifications');

-- Insert data into cost_breakdown table
INSERT INTO cost_breakdown (model_name, materials_cost, labor_cost, finishings_cost, total_cost, citation)
VALUES
  ('Traditional Housing', 242136.00, 212400.00, 253464.00, 708000.00, 'CLMA labor rates (30%) & NAHB finishing rates (35.8%)'),
  ('ODD Cubes', 231120.00, 60000.00, 128880.00, 420000.00, 'Base unit with estimated finishing percentage + fenestration'),
  ('Container (Base)', 124826.80, 96516.00, 102000.00, 323343.00, 'Base container cost + modifications'),
  ('Container (Max)', 124826.80, 164178.00, 291000.00, 580005.00, 'Base container cost + premium modifications');

-- Insert data into efficiency_metrics table
INSERT INTO efficiency_metrics (model_name, cost_efficiency, time_efficiency, waste_reduction, material_usage, citation)
VALUES
  ('Traditional Housing', 0, 0, 0, 0, 'Baseline - Traditional construction methods'),
  ('ODD Cubes', 29.41, 40.00, 50.00, 45.00, 'Cost and timeline from ODD Cubes'),
  ('Container Housing', 25.33, 54.67, 70.00, 75.00, 'CE10_Proj.pdf [18]: 70% waste reduction, 40-60% faster construction');

-- Insert data into resource_usage table
INSERT INTO resource_usage (resource_type, traditional_usage, container_usage, citation)
VALUES
  ('Construction Waste', 100, 30, 'CE10_Proj.pdf [18]: Produced 70% less onsite waste than traditional building methods'),
  ('Material Usage', 100, 25, 'CE10_Proj.pdf: A container home can be constructed of about 75% recycled materials by weight');

-- Insert data into cost_breakdown table (for conceptual-models.tsx)
INSERT INTO cost_breakdownConcMod (model_name, component_name, cost, citation)
VALUES
  -- Container (Base)
  ('Container (Base)', 'Container Cost', 124826.80, 'Current market rates'),
  ('Container (Base)', 'Fenestration', 60000, '₱10,000 per cut, 6 cuts required'),
  ('Container (Base)', 'Base Alterations', 102000, 'Base estimate for modifications'),
  -- Container (Max)
  ('Container (Max)', 'Container Cost', 124826.80, 'Current market rates'),
  ('Container (Max)', 'Fenestration', 60000, '₱10,000 per cut, 6 cuts required'),
  ('Container (Max)', 'Max Alterations', 291000, 'Max estimate for modifications');