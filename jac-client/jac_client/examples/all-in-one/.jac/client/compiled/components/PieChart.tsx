import React from "react";
import {
  PieChart as RechartsPie,
  Pie,
  Cell,
  Legend,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

interface ChartData {
  name: string;
  value: number;
  color?: string;
  [key: string]: string | number | undefined;
}

interface PieChartProps {
  data: ChartData[];
  title?: string;
  colors?: Record<string, string>;
}

const DEFAULT_COLORS: Record<string, string> = {
  FOOD: "#f59e0b",
  TRANSPORT: "#3b82f6",
  UTILITIES: "#8b5cf6",
  ENTERTAINMENT: "#ec4899",
  OTHER: "#6b7280",
};

export const PieChart: React.FC<PieChartProps> = ({
  data,
  title = "Expenses by Category",
  colors = DEFAULT_COLORS,
}) => {
  if (!data || data.length === 0) {
    return (
      <div className="chart-empty">
        <p>No expense data to display</p>
        <p>Add some expenses to see the breakdown</p>
      </div>
    );
  }

  const getColor = (name: string): string => {
    return colors[name] || DEFAULT_COLORS[name] || "#6b7280";
  };

  const formatTooltip = (value: number | undefined): string => {
    if (typeof value !== "number") return "$0.00";
    return `$${value.toFixed(2)}`;
  };

  const total = data.reduce((sum, item) => sum + item.value, 0);

  const renderLabel = ({ percent }: { percent?: number }): string => {
    if (typeof percent !== "number") return "";
    return `${(percent * 100).toFixed(0)}%`;
  };

  return (
    <div className="chart-container">
      {title && <h3 className="chart-title">{title}</h3>}

      <ResponsiveContainer width="100%" height={280}>
        <RechartsPie>
          <Pie
            data={data}
            dataKey="value"
            nameKey="name"
            cx="50%"
            cy="50%"
            outerRadius={80}
            innerRadius={40}
            paddingAngle={2}
            label={renderLabel}
            labelLine={false}
          >
            {data.map((entry, index) => (
              <Cell
                key={`cell-${index}`}
                fill={getColor(entry.name)}
                stroke="#fff"
                strokeWidth={2}
              />
            ))}
          </Pie>
          <Tooltip
            formatter={formatTooltip}
            contentStyle={{
              backgroundColor: "#fff",
              border: "1px solid #e5e7eb",
              borderRadius: "8px",
              boxShadow: "0 4px 6px -1px rgba(0, 0, 0, 0.1)",
            }}
          />
          <Legend
            verticalAlign="bottom"
            height={36}
            formatter={(value: string) => (
              <span style={{ color: "#374151", fontSize: "12px" }}>
                {value}
              </span>
            )}
          />
        </RechartsPie>
      </ResponsiveContainer>

      <div className="chart-total">
        <span>Total Expenses:</span>
        <strong>${total.toFixed(2)}</strong>
      </div>
    </div>
  );
};

export default PieChart;

// export const PieChart = () => {
//   return <div>Pie Chart Placeholder</div>;
// };
