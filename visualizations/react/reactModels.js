import React, { useState } from 'react';
import { 
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
  LineChart, Line, PieChart, Pie, Cell, RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar
} from 'recharts';

// Simple Card components to replace the shadcn UI components
const Card = ({ children, className }) => (
  <div className={`rounded-lg border shadow-sm p-4 ${className || ''}`}>
    {children}
  </div>
);

const CardHeader = ({ children }) => <div className="mb-4">{children}</div>;
const CardTitle = ({ children }) => <h3 className="text-xl font-semibold">{children}</h3>;
const CardContent = ({ children }) => <div>{children}</div>;

const CombinedVisualizations = () => {
  const [activeChart, setActiveChart] = useState('totalCost');
  
  // Constants for calculations
  const usdToPhp = 56;
  const containerCostUSD = 2229.05;
  const containerCostPhp = containerCostUSD * usdToPhp;

  // ===== TOTAL COST COMPARISON DATA =====
  const models = [
    {
      name: 'Traditional Housing',
      totalCost: 708000,
      citation: '2024 contractor rates: ₱29,500/sqm average for 24 sqm'
    },
    {
      name: 'ODD Cubes Basic',
      totalCost: 420000, // 360,000 base + 60,000 fenestration
      citation: 'ArchJosieDeAsisDP.pdf: ODD Cubes Inc.'
    },
    {
      name: 'Container Base',
      totalCost: containerCostPhp + 60000 + 102000,
      citation: 'Container Price + Base configuration'
    },
    {
      name: 'Container Max',
      totalCost: containerCostPhp + 60000 + 291000,
      citation: 'Container Price + Premium configuration'
    }
  ];

  // ===== CONCEPTUAL MODELS DATA =====
  const conceptualBase = [
    { name: 'Container Cost', value: containerCostPhp },
    { name: 'Fenestration', value: 60000 },
    { name: 'Base Alterations', value: 102000 }
  ];

  const conceptualMax = [
    { name: 'Container Cost', value: containerCostPhp },
    { name: 'Fenestration', value: 60000 },
    { name: 'Premium Alterations', value: 291000 }
  ];

  const COLORS = ['#8884d8', '#82ca9d', '#ffc658'];

  // ===== COST BREAKDOWN DATA =====
  const costBreakdown = [
    {
      category: 'Traditional Housing',
      materials: 242136,
      labor: 212400,
      finishings: 253464,
      citation: 'CLMA labor rates & NAHB finishing rates',
      total: 708000
    },
    {
      category: 'ODD Cubes',
      materials: 231120,
      labor: 60000,
      finishings: 128880,
      citation: 'Base unit with estimated finishing',
      total: 420000
    },
    {
      category: 'Container Base',
      materials: containerCostPhp,
      labor: 96516,
      finishings: 102000,
      citation: 'Base container plus modifications'
    },
    {
      category: 'Container Max',
      materials: containerCostPhp,
      labor: 164178,
      finishings: 291000,
      citation: 'Base container plus premium mods'
    }
  ];

  // ===== COST PER SQM DATA =====
  const sqmModels = [
    {
      name: 'Traditional Housing',
      costPerSqm: 708000 / 24,
      total: 708000,
      citation: '2024 rates: Avg of contractors'
    },
    {
      name: 'ODD Cubes Basic',
      costPerSqm: 420000 / 24,
      total: 420000,
      citation: 'ODD Cubes Inc. unit cost'
    },
    {
      name: 'Container Base',
      costPerSqm: 323343 / 24,
      total: 323343,
      citation: 'Base modifications'
    },
    {
      name: 'Container Max',
      costPerSqm: 580005 / 24,
      total: 580005,
      citation: 'Premium modifications'
    }
  ];

  // ===== EFFICIENCY COMPARISON DATA =====
  const efficiencyData = [
    {
      subject: 'Traditional Housing',
      'Cost Efficiency': 0,
      'Time Efficiency': 0,
      'Waste Reduction': 0,
      'Material Usage': 0,
      citation: 'Baseline - Traditional methods'
    },
    {
      subject: 'ODD Cubes',
      'Cost Efficiency': ((510000 - 360000) / 510000) * 100,
      'Time Efficiency': ((150 - 90) / 150) * 100,
      'Waste Reduction': 50,
      'Material Usage': 45,
      citation: 'ArchJosieDeAsisDP.pdf data'
    },
    {
      subject: 'Container Housing',
      'Cost Efficiency': ((510000 - (124826.80 + 60000 + 196500)) / 510000) * 100,
      'Time Efficiency': ((150 - 68) / 150) * 100,
      'Waste Reduction': 70,
      'Material Usage': 75,
      citation: 'CE10_Proj.pdf citation [18]'
    }
  ];

  // ===== RESOURCE USAGE DATA =====
  const resourceData = [
    {
      resource: 'Construction Waste',
      traditional: 100,
      container: 30,
      citation: "CE10_Proj.pdf [18]"
    },
    {
      resource: 'Material Usage',
      traditional: 100,
      container: 25,
      citation: "CE10_Proj.pdf citation [10]"
    }
  ];

  // Render function for Total Cost Comparison
  const renderTotalCostComparison = () => (
    <Card className="w-full">
      <CardHeader>
        <CardTitle>Total Cost Comparison</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="h-80">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={models}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis 
                dataKey="name" 
                angle={-45} 
                textAnchor="end" 
                height={80}
              />
              <YAxis 
                label={{ 
                  value: 'Cost (PHP)', 
                  angle: -90, 
                  position: 'insideLeft' 
                }} 
              />
              <Tooltip 
                formatter={(value) => `₱${value.toLocaleString()}`}
                labelFormatter={(label) => `Model: ${label}`}
              />
              <Bar 
                dataKey="totalCost" 
                fill="#8884d8"
                name="Total Cost"
              />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="mt-4 text-sm text-gray-600">
          <p>Data sources from ArchJosieDeAsisDP.pdf and CE10_Proj.pdf</p>
        </div>
      </CardContent>
    </Card>
  );

  // Render function for Conceptual Models
  const renderConceptualModels = () => (
    <Card className="w-full">
      <CardHeader>
        <CardTitle>Container Housing Cost Breakdown Models</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="h-64">
            <h3 className="text-center font-semibold mb-4">Base Model</h3>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={conceptualBase}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  label={({name, percent}) => `${name}: ${(percent * 100).toFixed(0)}%`}
                >
                  {conceptualBase.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(value) => `₱${value.toLocaleString()}`} />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>
          
          <div className="h-64">
            <h3 className="text-center font-semibold mb-4">Premium Model</h3>
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={conceptualMax}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  label={({name, percent}) => `${name}: ${(percent * 100).toFixed(0)}%`}
                >
                  {conceptualMax.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(value) => `₱${value.toLocaleString()}`} />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>
      </CardContent>
    </Card>
  );

  // Render function for Cost Breakdown
  const renderCostBreakdown = () => (
    <Card className="w-full">
      <CardHeader>
        <CardTitle>Cost Breakdown Comparison</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="h-80">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={costBreakdown}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis 
                dataKey="category" 
                angle={-45} 
                textAnchor="end" 
                height={80} 
              />
              <YAxis 
                label={{ 
                  value: 'Cost (PHP)', 
                  angle: -90, 
                  position: 'insideLeft' 
                }} 
              />
              <Tooltip 
                formatter={(value) => `₱${value.toLocaleString()}`}
                labelFormatter={(label) => `Category: ${label}`}
              />
              <Legend />
              <Bar dataKey="materials" stackId="a" fill="#8884d8" name="Materials" />
              <Bar dataKey="labor" stackId="a" fill="#82ca9d" name="Labor" />
              <Bar dataKey="finishings" stackId="a" fill="#ffc658" name="Finishings" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </CardContent>
    </Card>
  );

  // Render function for Cost Per Sqm
  const renderCostPerSqm = () => (
    <Card className="w-full">
      <CardHeader>
        <CardTitle>Cost per Square Meter</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="h-80">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={sqmModels}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis 
                dataKey="name" 
                angle={-45} 
                textAnchor="end" 
                height={80} 
              />
              <YAxis 
                label={{ 
                  value: 'Cost per sqm (PHP)', 
                  angle: -90, 
                  position: 'insideLeft' 
                }} 
              />
              <Tooltip 
                formatter={(value) => `₱${value.toLocaleString()}`}
                labelFormatter={(label) => `Model: ${label}`}
              />
              <Bar 
                dataKey="costPerSqm" 
                fill="#82ca9d" 
                name="Cost per sqm"
              />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </CardContent>
    </Card>
  );

  // Render function for Efficiency Comparison
  const renderEfficiencyComparison = () => (
    <Card className="w-full">
      <CardHeader>
        <CardTitle>Housing Model Efficiency Comparison</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="h-96">
          <ResponsiveContainer width="100%" height="100%">
            <RadarChart data={efficiencyData}>
              <PolarGrid />
              <PolarAngleAxis dataKey="subject" />
              <PolarRadiusAxis angle={30} domain={[0, 100]} />
              <Radar 
                name="Cost Efficiency" 
                dataKey="Cost Efficiency" 
                stroke="#8884d8" 
                fill="#8884d8" 
                fillOpacity={0.6} 
              />
              <Radar 
                name="Time Efficiency" 
                dataKey="Time Efficiency" 
                stroke="#82ca9d" 
                fill="#82ca9d" 
                fillOpacity={0.6} 
              />
              <Radar 
                name="Waste Reduction" 
                dataKey="Waste Reduction" 
                stroke="#ffc658" 
                fill="#ffc658" 
                fillOpacity={0.6} 
              />
              <Radar 
                name="Material Usage" 
                dataKey="Material Usage" 
                stroke="#ff8042" 
                fill="#ff8042" 
                fillOpacity={0.6} 
              />
              <Legend />
              <Tooltip />
            </RadarChart>
          </ResponsiveContainer>
        </div>
        <div className="mt-4 text-sm space-y-2">
          <p className="text-gray-600 italic">Citations from CE10_Proj.pdf [18] and ArchJosieDeAsisDP.pdf</p>
        </div>
      </CardContent>
    </Card>
  );

  // Render function for Resource Usage
  const renderResourceUsage = () => (
    <Card className="w-full">
      <CardHeader>
        <CardTitle>Resource Usage Comparison (% of Traditional Housing)</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="h-80">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={resourceData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="resource" />
              <YAxis 
                label={{ 
                  value: 'Percentage of Traditional Usage', 
                  angle: -90, 
                  position: 'insideLeft' 
                }} 
              />
              <Tooltip 
                formatter={(value) => `${value}%`}
                labelFormatter={(label) => `Resource: ${label}`}
              />
              <Legend />
              <Bar dataKey="traditional" name="Traditional" fill="#8884d8" />
              <Bar dataKey="container" name="Container" fill="#ffc658" />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="mt-4 text-sm text-gray-600">
          <p>Source: CE10_Proj.pdf [18]: "produced 70% less onsite waste than traditional building methods"</p>
        </div>
      </CardContent>
    </Card>
  );

  // Navigation buttons
  const renderNavigation = () => (
    <div className="flex flex-wrap gap-2 mb-4">
      <button 
        className={`px-3 py-1 rounded ${activeChart === 'totalCost' ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
        onClick={() => setActiveChart('totalCost')}
      >
        Total Cost
      </button>
      <button 
        className={`px-3 py-1 rounded ${activeChart === 'conceptual' ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
        onClick={() => setActiveChart('conceptual')}
      >
        Conceptual Models
      </button>
      <button 
        className={`px-3 py-1 rounded ${activeChart === 'breakdown' ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
        onClick={() => setActiveChart('breakdown')}
      >
        Cost Breakdown
      </button>
      <button 
        className={`px-3 py-1 rounded ${activeChart === 'costPerSqm' ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
        onClick={() => setActiveChart('costPerSqm')}
      >
        Cost per SQM
      </button>
      <button 
        className={`px-3 py-1 rounded ${activeChart === 'efficiency' ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
        onClick={() => setActiveChart('efficiency')}
      >
        Efficiency
      </button>
      <button 
        className={`px-3 py-1 rounded ${activeChart === 'resource' ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
        onClick={() => setActiveChart('resource')}
      >
        Resource Usage
      </button>
    </div>
  );

  // Main render
  return (
    <div className="container mx-auto p-4">
      <h1 className="text-2xl font-bold mb-6">Container Housing Visualizations</h1>
      {renderNavigation()}
      
      {activeChart === 'totalCost' && renderTotalCostComparison()}
      {activeChart === 'conceptual' && renderConceptualModels()}
      {activeChart === 'breakdown' && renderCostBreakdown()}
      {activeChart === 'costPerSqm' && renderCostPerSqm()}
      {activeChart === 'efficiency' && renderEfficiencyComparison()}
      {activeChart === 'resource' && renderResourceUsage()}
      
      <footer className="mt-6 pt-4 border-t text-center text-sm text-gray-500">
        <p>Data sourced from CE10_Proj.pdf and ArchJosieDeAsisDP.pdf research studies</p>
      </footer>
    </div>
  );
};

export default CombinedVisualizations;