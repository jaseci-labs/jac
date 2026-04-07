import React from "react";

export const CustomButton: React.FC = () => {
  return (
    <button
      style={{
        padding: "0.6rem 1.2rem",
        borderRadius: "6px",
        border: "1px solid #ccc",
        background: "#f5f5f5",
        cursor: "pointer"
      }}
    >
      Custom Button
    </button>
  );
};
