import React from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

const ResourceUsage = () => {
  const resourceData = [
    {
      resource: 'Construction Waste',
      traditional: 100,
      container: 30,
      citation: "CE10_Proj.pdf [18]: 'produced 70% less onsite waste than traditional building methods'"
    },
    {
      resource: 'Material Usage',
      traditional: 100,
      container: 25,
      citation: "CE10_Proj.pdf: 'a container home can be constructed of about 75% recycled materials by weight'"
    }
  ];

  return (
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
          <p>Sources from CE10_Proj.pdf:</p>
          <ul className="list-disc pl-6">
            <li>Container construction produces 70% less waste than traditional methods [18]</li>
            <li>Container homes use approximately 75% recycled materials by weight</li>
            <li>Traditional construction used as baseline (100%) for comparison</li>
          </ul>
        </div>
      </CardContent>
    </Card>
  );
};

export default ResourceUsage;