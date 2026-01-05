interface SectionHeaderProps {
  title: string;
  subtitle?: string;
  meta?: string;
}

const SectionHeader = ({ title, subtitle, meta }: SectionHeaderProps) => {
  return (
    <div className="section-header">
      <div>
        <h2>{title}</h2>
        {subtitle && <span>{subtitle}</span>}
      </div>
      {meta && <span className="pill">{meta}</span>}
    </div>
  );
};

export default SectionHeader;
