import React from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

const TotalCostComparison = () => {
  const usdToPhp = 56;
  const containerCostUSD = 2229.05;
  const containerCostPhp = containerCostUSD * usdToPhp;

  const models = [
    {
      name: 'Traditional Housing',
      totalCost: 708000,
      citation: '2024 contractor rates: ₱29,500/sqm average for 24 sqm'
    },
    {
      name: 'ODD Cubes Basic',
      totalCost: 420000, // 360,000 base + 60,000 fenestration
      citation: 'ArchJosieDeAsisDP.pdf: ODD Cubes Inc. base unit (₱360,000) + fenestration (₱60,000)'
    },
    {
      name: 'Container Base',
      totalCost: containerCostPhp + 60000 + 102000,
      citation: 'Container Price Changes & ArchJosieDeAsisDP.pdf: Base configuration'
    },
    {
      name: 'Container Max',
      totalCost: containerCostPhp + 60000 + 291000,
      citation: 'Container Price Changes & ArchJosieDeAsisDP.pdf: Premium configuration'
    }
  ];

  return (
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
                contentStyle={{ whiteSpace: 'pre-wrap' }}
                wrapperStyle={{ maxWidth: '300px' }}
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
          <p>Data sources:</p>
          <ul className="list-disc pl-6">
            <li>Traditional housing: Average of Ian Fulgar Construction (₱27,000/sqm) and ACDC Contractors (₱32,000/sqm) 2024 rates</li>
            <li>ODD Cubes: Base unit (₱360,000) plus standard fenestration costs (₱60,000)</li>
            <li>Container costs include base container (₱{containerCostPhp.toLocaleString()}), fenestration (₱60,000), and alterations</li>
          </ul>
        </div>
      </CardContent>
    </Card>
  );
};

export default TotalCostComparison;