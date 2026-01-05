import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const toggles = [
  {
    id: 'two-factor',
    title: 'Two factor authentication',
    description: 'Require a code on login.',
    enabled: true,
  },
  {
    id: 'login-alerts',
    title: 'Login alerts',
    description: 'Notify on new device sign-ins.',
    enabled: true,
  },
  {
    id: 'app-lock',
    title: 'App passcode',
    description: 'Require a passcode to open.',
    enabled: false,
  },
  {
    id: 'biometrics',
    title: 'Biometric unlock',
    description: 'Use face or fingerprint unlock.',
    enabled: true,
  },
];

const SecurityCenterPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Security center"
        subtitle="Protect your account and devices."
        meta="Secure"
      />

      <Card title="Security preferences" description="Manage your safety tools.">
        <div className="stack">
          {toggles.map((toggle) => (
            <label className="toggle-row" key={toggle.id}>
              <div>
                <strong>{toggle.title}</strong>
                <div className="meta">{toggle.description}</div>
              </div>
              <input type="checkbox" defaultChecked={toggle.enabled} />
            </label>
          ))}
        </div>
      </Card>

      <Card title="Security status" description="Recent activity overview.">
        <div className="list">
          <div className="list-item">
            <div>
              <strong>Last login</strong>
              <span>Chrome on Windows · 2 hours ago</span>
            </div>
            <span className="pill">Verified</span>
          </div>
          <div className="list-item">
            <div>
              <strong>Recovery email</strong>
              <span>himanbarman@gmail.com</span>
            </div>
            <button className="button button--ghost" type="button">
              Update
            </button>
          </div>
        </div>
      </Card>
    </div>
  );
};

export default SecurityCenterPage;
