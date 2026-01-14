import React from 'react';

interface CardProps {
  title: string;
  description?: string;
  children?: React.ReactNode;
  variant?: 'default' | 'highlighted';
  onClick?: () => void;
}

export const Card: React.FC<CardProps> = ({
  title,
  description,
  children,
  variant = 'default',
  onClick
}) => {
  const baseStyles: React.CSSProperties = {
    border: '1px solid #e5e7eb',
    borderRadius: '0.5rem',
    padding: '1.5rem',
    backgroundColor: '#ffffff',
    boxShadow: variant === 'highlighted'
      ? '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)'
      : '0 1px 3px 0 rgba(0, 0, 0, 0.1)',
    transition: 'all 0.2s ease',
    cursor: onClick ? 'pointer' : 'default',
  };

  const defaultShadow = variant === 'highlighted'
    ? '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)'
    : '0 1px 3px 0 rgba(0, 0, 0, 0.1)';

  return (
    <div
      style={baseStyles}
      onClick={onClick}
      onMouseEnter={(e) => {
        if (onClick) {
          e.currentTarget.style.transform = 'translateY(-2px)';
          e.currentTarget.style.boxShadow = '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)';
        }
      }}
      onMouseLeave={(e) => {
        if (onClick) {
          e.currentTarget.style.transform = 'translateY(0)';
          e.currentTarget.style.boxShadow = defaultShadow;
        }
      }}
    >
      <h3 style={{ margin: '0 0 0.5rem 0', fontSize: '1.25rem', fontWeight: '600', color: '#111827' }}>
        {title}
      </h3>
      {description && (
        <p style={{ margin: '0 0 1rem 0', color: '#6b7280', fontSize: '0.875rem' }}>
          {description}
        </p>
      )}
      {children && <div>{children}</div>}
    </div>
  );
};

export default Card;
