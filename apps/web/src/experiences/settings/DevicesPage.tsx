import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const devices = [
  {
    id: 'd1',
    name: 'SM G990E',
    detail: 'Android · Kolkata, IN',
    time: 'Active now',
  },
  {
    id: 'd2',
    name: 'Windows Chrome',
    detail: 'Web · Kolkata, IN',
    time: '2 hours ago',
  },
];

const DevicesPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Devices"
        subtitle="Review and manage active sessions."
        meta="2 active"
      />

      <Card title="Signed-in devices" description="Sign out of any device."
      >
        <div className="list">
          {devices.map((device) => (
            <div className="list-item" key={device.id}>
              <div>
                <strong>{device.name}</strong>
                <span>{device.detail}</span>
              </div>
              <div className="list-item__meta">
                <span>{device.time}</span>
                <button className="button button--ghost" type="button">
                  Sign out
                </button>
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
};

export default DevicesPage;
