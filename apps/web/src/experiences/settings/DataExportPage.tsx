import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const DataExportPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Data export"
        subtitle="Request a copy of your account data."
        meta="Ready"
      />

      <Card
        title="Export status"
        description="Your latest export will be ready within 24 hours."
      >
        <div className="progress" style={{ margin: '12px 0' }}>
          <span />
        </div>
        <div className="button-row">
          <button className="button button--soft" type="button">
            Request new export
          </button>
          <button className="button button--ghost" type="button">
            Download latest
          </button>
        </div>
      </Card>

      <Card
        title="Included data"
        description="What you will receive in your export."
      >
        <div className="list">
          <div className="list-item">
            <div>
              <strong>Profile data</strong>
              <span>Username, bio, and links</span>
            </div>
            <span className="pill">Included</span>
          </div>
          <div className="list-item">
            <div>
              <strong>Posts and media</strong>
              <span>Feed posts, comments, and shares</span>
            </div>
            <span className="pill">Included</span>
          </div>
          <div className="list-item">
            <div>
              <strong>Messages</strong>
              <span>Chat history and attachments</span>
            </div>
            <span className="pill">Included</span>
          </div>
        </div>
      </Card>
    </div>
  );
};

export default DataExportPage;
