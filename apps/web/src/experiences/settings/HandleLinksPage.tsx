import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const HandleLinksPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Handle and links"
        subtitle="Update your Prava ID and profile links."
        meta="Public"
      />

      <Card title="Prava ID" description="Choose a unique handle.">
        <div className="form-grid">
          <label className="field">
            Display name
            <input className="input" placeholder="Himan Barman" />
          </label>
          <label className="field">
            Username
            <input className="input" placeholder="himanbarman" />
          </label>
        </div>
      </Card>

      <Card title="Profile links" description="Share more about yourself.">
        <div className="form-grid">
          <label className="field">
            Bio
            <textarea
              className="input input--textarea"
              placeholder="Founder, builder, community host"
            />
          </label>
          <label className="field">
            Website
            <input className="input" placeholder="https://prava.com" />
          </label>
          <label className="field">
            Location
            <input className="input" placeholder="Kolkata, IN" />
          </label>
        </div>
        <div className="button-row" style={{ marginTop: '16px' }}>
          <button className="button button--ghost" type="button">
            Cancel
          </button>
          <button className="button button--primary" type="button">
            Save updates
          </button>
        </div>
      </Card>
    </div>
  );
};

export default HandleLinksPage;
