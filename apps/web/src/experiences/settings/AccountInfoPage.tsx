import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const AccountInfoPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Account information"
        subtitle="Update your email, name, and contact info."
        meta="Verified"
      />

      <Card title="Contact details" description="Keep your info current.">
        <div className="form-grid">
          <label className="field">
            Email address
            <input className="input" placeholder="you@prava.com" />
          </label>
          <label className="field">
            Phone number
            <input className="input" placeholder="+91 00000 00000" />
          </label>
          <label className="field">
            First name
            <input className="input" placeholder="Himan" />
          </label>
          <label className="field">
            Last name
            <input className="input" placeholder="Barman" />
          </label>
        </div>
        <div className="button-row" style={{ marginTop: '16px' }}>
          <button className="button button--ghost" type="button">
            Reset
          </button>
          <button className="button button--primary" type="button">
            Save changes
          </button>
        </div>
      </Card>

      <Card
        title="Verification"
        description="Confirm your email to keep the account secure."
      >
        <div className="button-row" style={{ marginTop: '12px' }}>
          <button className="button button--soft" type="button">
            Send verification email
          </button>
          <button className="button button--ghost" type="button">
            Update password
          </button>
        </div>
      </Card>
    </div>
  );
};

export default AccountInfoPage;
