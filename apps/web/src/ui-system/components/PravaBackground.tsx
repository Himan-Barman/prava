interface PravaBackgroundProps {
  className?: string;
}

export function PravaBackground({ className = '' }: PravaBackgroundProps) {
  return (
    <div className={`fixed inset-0 -z-10 ${className}`}>
      <div className="absolute inset-0 bg-prava-light-bg dark:bg-prava-dark-bg" />
      <div className="absolute inset-0 prava-gradient-bg opacity-60 dark:opacity-40" />
    </div>
  );
}
