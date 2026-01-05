import { ReactNode } from 'react';

interface CardProps {
  title?: string;
  description?: string;
  badge?: string;
  children?: ReactNode;
  className?: string;
}

const Card = ({ title, description, badge, children, className }: CardProps) => {
  return (
    <div className={className ? `card ${className}` : 'card'}>
      {badge && <span className="pill">{badge}</span>}
      {title && <h3>{title}</h3>}
      {description && <p>{description}</p>}
      {children}
    </div>
  );
};

export default Card;
