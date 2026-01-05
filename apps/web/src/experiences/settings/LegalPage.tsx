import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const LegalPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Legal"
        subtitle="Policies and terms for using Prava."
        meta="Updated"
      />

      <Card title="Privacy policy" description="How we collect and use data.">
        <p>
          Prava collects account details, usage signals, and content you share to
          deliver core features, protect your account, and improve the service.
          You can request an export or delete your account at any time.
        </p>
      </Card>

      <Card title="Terms of service" description="Guidelines for the community.">
        <p>
          Be respectful, keep content lawful, and follow community guidelines.
          We may remove content or suspend accounts that violate these rules.
        </p>
      </Card>
    </div>
  );
};

export default LegalPage;
