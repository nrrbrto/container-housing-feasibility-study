import React from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, Legend } from 'recharts';

const ConceptualModels = () => {
  const usdToPhp = 56;
  const containerCostUSD = 2229.05;
  const containerCostPhp = containerCostUSD * usdToPhp;

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

  return (
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

        <div className="mt-4 text-sm text-gray-600">
          <p>Sources:</p>
          <ul className="list-disc pl-6">
            <li>Container costs based on current market rates (₱{containerCostPhp.toLocaleString()})</li>
            <li>Fenestration costs from ArchJosieDeAsisDP.pdf: ₱10,000 per cut, 6 cuts required</li>
            <li>Alteration costs derived from Model Comparison Limitations.md</li>
          </ul>
        </div>
      </CardContent>
    </Card>
  );
};

export default ConceptualModels;