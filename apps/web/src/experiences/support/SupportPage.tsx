import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const SupportPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Help and feedback"
        subtitle="Support, reports, and product ideas."
        meta="Support"
      />

      <div className="page-grid">
        <Card
          title="Help center"
          description="Guides, FAQs, and troubleshooting."
          badge="Live"
        >
          <div className="button-row" style={{ marginTop: '12px' }}>
            <button className="button button--soft" type="button">
              Browse guides
            </button>
            <button className="button button--ghost" type="button">
              Safety tips
            </button>
          </div>
        </Card>
        <Card
          title="Contact support"
          description="Reach the Prava team directly."
        >
          <div className="button-row" style={{ marginTop: '12px' }}>
            <button className="button button--primary" type="button">
              Start chat
            </button>
            <button className="button button--ghost" type="button">
              Email us
            </button>
          </div>
        </Card>
      </div>

      <Card title="Report an issue" description="Let us know what happened.">
        <div className="form-grid">
          <label className="field">
            Category
            <select className="input" defaultValue="bug">
              <option value="bug">Bug</option>
              <option value="abuse">Abuse</option>
              <option value="other">Other</option>
            </select>
          </label>
          <label className="field">
            Include logs
            <select className="input" defaultValue="yes">
              <option value="yes">Yes</option>
              <option value="no">No</option>
            </select>
          </label>
        </div>
        <label className="field" style={{ marginTop: '16px' }}>
          Details
          <textarea className="input input--textarea" placeholder="Describe the issue" />
        </label>
        <div className="button-row" style={{ marginTop: '16px' }}>
          <button className="button button--soft" type="button">
            Send report
          </button>
        </div>
      </Card>

      <Card title="Product feedback" description="Share what we should build next.">
        <label className="field">
          Feedback
          <textarea className="input input--textarea" placeholder="Your ideas" />
        </label>
        <div className="button-row" style={{ marginTop: '16px' }}>
          <button className="button button--primary" type="button">
            Send feedback
          </button>
          <button className="button button--ghost" type="button">
            Schedule call
          </button>
        </div>
      </Card>
    </div>
  );
};

export default SupportPage;
