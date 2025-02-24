import React from 'react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar, Legend, Tooltip, ResponsiveContainer } from 'recharts';

const EfficiencyComparison = () => {
  const efficiencyData = [
    {
      subject: 'Traditional Housing',
      'Cost Efficiency': 0,
      'Time Efficiency': 0,
      'Waste Reduction': 0,
      'Material Usage': 0,
      citation: 'Baseline - Traditional construction methods'
    },
    {
      subject: 'ODD Cubes',
      'Cost Efficiency': ((510000 - 360000) / 510000) * 100,
      'Time Efficiency': ((150 - 90) / 150) * 100,
      'Waste Reduction': 50,
      'Material Usage': 45,
      citation: 'Cost and timeline from ArchJosieDeAsisDP.pdf - ODD Cubes Inc. data'
    },
    {
      subject: 'Container Housing',
      'Cost Efficiency': ((510000 - (124826.80 + 60000 + 196500)) / 510000) * 100,
      'Time Efficiency': ((150 - 68) / 150) * 100,
      'Waste Reduction': 70,
      'Material Usage': 75,
      citation: 'CE10_Proj.pdf [18]: 70% waste reduction, 40-60% faster construction'
    }
  ];

  return (
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
          <h3 className="font-semibold">Citations:</h3>
          <ul className="list-disc pl-6 space-y-1">
            <li><strong>Cost Efficiency:</strong> Based on ArchJosieDeAsisDP.pdf cost comparisons and current container prices</li>
            <li><strong>Time Efficiency:</strong> "modular construction was 40-60% quicker" [CE10_Proj.pdf, citation 18]</li>
            <li><strong>Waste Reduction:</strong> "produced 70% less onsite waste than traditional building methods" [CE10_Proj.pdf, citation 18]</li>
            <li><strong>Material Usage:</strong> "a container home can be constructed of about 75% recycled materials by weight" [CE10_Proj.pdf, citation 10]</li>
          </ul>
          <p className="mt-4 text-gray-600 italic">Note: All metrics are relative to traditional housing (baseline = 0)</p>
        </div>
      </CardContent>
    </Card>
  );
};

export default EfficiencyComparison;