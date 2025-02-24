import React from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

const CostPerSqm = () => {
  const models = [
    {
      name: 'Traditional Housing',
      costPerSqm: 708000 / 24,
      total: 708000,
      citation: '2024 rates: Average of Ian Fulgar and ACDC Contractors'
    },
    {
      name: 'ODD Cubes Basic',
      costPerSqm: 420000 / 24,
      total: 420000,
      citation: 'ArchJosieDeAsisDP.pdf: ODD Cubes Inc. complete unit cost'
    },
    {
      name: 'Container Base',
      costPerSqm: 323343 / 24,
      total: 323343,
      citation: 'Sum of materials, labor, and base modifications'
    },
    {
      name: 'Container Max',
      costPerSqm: 580005 / 24,
      total: 580005,
      citation: 'Sum of materials, labor, and premium modifications'
    }
  ];

  return (
    <Card className="w-full">
      <CardHeader>
        <CardTitle>Cost per Square Meter</CardTitle>
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
        <div className="mt-4 text-sm text-gray-600">
          <p>Cost Breakdown per Model (24 sqm units):</p>
          <ul className="list-disc pl-6">
            <li>Traditional Housing: ₱29,500/sqm (₱708,000 total)</li>
            <li>ODD Cubes: ₱17,500/sqm (₱420,000 total)</li>
            <li>Container Base: ₱13,473/sqm (₱323,343 total)</li>
            <li>Container Max: ₱24,167/sqm (₱580,005 total)</li>
          </ul>
          <p className="mt-4">Notes:</p>
          <ul className="list-disc pl-6">
            <li>All models based on 24 sqm unit size (ArchJosieDeAsisDP.pdf)</li>
            <li>Totals include materials, labor, and finishing costs from detailed breakdown</li>
            <li>Container costs include base unit, fenestration, and all modifications</li>
          </ul>
        </div>
      </CardContent>
    </Card>
  );
};

export default CostPerSqm;