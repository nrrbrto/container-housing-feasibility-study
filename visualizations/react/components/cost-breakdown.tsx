import React from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

const CostBreakdown = () => {
  const usdToPhp = 56;
  const containerCostUSD = 2229.05;
  const containerCostPhp = containerCostUSD * usdToPhp;

  const costBreakdown = [
    {
      category: 'Traditional Housing',
      materials: 242136,
      labor: 212400,
      finishings: 253464,
      citation: 'CLMA labor rates (30%) & NAHB finishing rates (35.8%)',
      total: 708000
    },
    {
      category: 'ODD Cubes',
      materials: 231120,
      labor: 60000,
      finishings: 128880,
      citation: 'Base unit with estimated finishing percentage + fenestration',
      total: 420000
    },
    {
      category: 'Container Base',
      materials: containerCostPhp,
      labor: 96516,
      finishings: 102000,
      citation: 'Base container cost plus modifications'
    },
    {
      category: 'Container Max',
      materials: containerCostPhp,
      labor: 164178,
      finishings: 291000,
      citation: 'Base container cost plus premium modifications'
    }
  ];

  return (
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
        <div className="mt-4 text-sm text-gray-600">
          <p>Sources and Notes:</p>
          <ul className="list-disc pl-6">
            <li>Traditional Housing breakdown:
              <ul className="pl-4">
                <li>Labor: 30% (CLMA industry average)</li>
                <li>Finishes: 35.8% total (24% internal finishes + 11.8% external finishes, NAHB standards)</li>
                <li>Materials: Remaining 34.2%</li>
              </ul>
            </li>
            <li>ODD Cubes breakdown:
              <ul className="pl-4">
                <li>Materials: ₱231,120 (Base unit cost minus estimated finishes)</li>
                <li>Labor: Fenestration costs (₱60,000)</li>
                <li>Finishes: Estimated at 35.8% of base unit cost (₱128,880)</li>
              </ul>
            </li>
            <li>Container Housing:
              <ul className="pl-4">
                <li>Materials: Base container cost</li>
                <li>Labor: Fenestration (₱60,000) plus additional labor cost (35.8% of alteration costs)</li>
                <li>Finishes: Full alteration costs maintained (Base: ₱102,000, Max: ₱291,000)</li>
                <li>Base model labor: ₱96,516 (₱60,000 fenestration + ₱36,516 calculated labor)</li>
                <li>Max model labor: ₱164,178 (₱60,000 fenestration + ₱104,178 calculated labor)</li>
              </ul>
            </li>
          </ul>
        </div>
      </CardContent>
    </Card>
  );
};

export default CostBreakdown;