import { Link } from 'react-router-dom';

import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const sections = [
  {
    title: 'Account',
    description: 'Identity and profile controls.',
    items: [
      {
        label: 'Account information',
        description: 'Email, phone, and profile status',
        path: '/settings/account',
        meta: 'Profile',
      },
      {
        label: 'Handle and links',
        description: 'Update your Prava ID and bio links',
        path: '/settings/handle',
        meta: 'Public',
      },
    ],
  },
  {
    title: 'Privacy and safety',
    description: 'Control who can reach you.',
    items: [
      {
        label: 'Security center',
        description: 'Two factor, login alerts, and devices',
        path: '/settings/security',
        meta: 'Secure',
      },
      {
        label: 'Devices',
        description: 'Review signed-in devices',
        path: '/settings/devices',
        meta: '3 active',
      },
      {
        label: 'Blocked accounts',
        description: 'Manage blocked people',
        path: '/settings/blocked',
        meta: '3 blocked',
      },
      {
        label: 'Muted words',
        description: 'Filter unwanted topics',
        path: '/settings/muted',
        meta: '8 words',
      },
    ],
  },
  {
    title: 'Preferences',
    description: 'Language, data, and legal tools.',
    items: [
      {
        label: 'Language',
        description: 'Choose your preferred language',
        path: '/settings/language',
        meta: 'English',
      },
      {
        label: 'Data export',
        description: 'Request a copy of your data',
        path: '/settings/export',
        meta: 'Ready',
      },
      {
        label: 'Legal',
        description: 'Terms and privacy policy',
        path: '/settings/legal',
      },
    ],
  },
];

const SettingsPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Settings"
        subtitle="Personalize your Prava experience."
        meta="Account"
      />

      {sections.map((section) => (
        <Card
          key={section.title}
          title={section.title}
          description={section.description}
        >
          <div className="list">
            {section.items.map((item) => (
              <Link className="list-item" key={item.label} to={item.path}>
                <div>
                  <strong>{item.label}</strong>
                  <span>{item.description}</span>
                </div>
                {item.meta ? <span className="pill">{item.meta}</span> : null}
              </Link>
            ))}
          </div>
        </Card>
      ))}

      <Card
        title="Support"
        description="Need help or want to share feedback?"
      >
        <Link className="list-item" to="/support">
          <div>
            <strong>Help and feedback</strong>
            <span>Contact support or report issues</span>
          </div>
          <span className="pill">Open</span>
        </Link>
      </Card>
    </div>
  );
};

export default SettingsPage;
