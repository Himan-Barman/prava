import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const broadcasts = [
  {
    id: 'b1',
    title: 'Launch AMA',
    time: 'Today, 6:00 PM',
    host: 'Prava team',
  },
  {
    id: 'b2',
    title: 'Creator town hall',
    time: 'Tomorrow, 4:30 PM',
    host: 'Community ops',
  },
];

const BroadcastPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Broadcast"
        subtitle="Host live updates and community rooms."
        meta="Live"
      />

      <div className="page-grid">
        <Card
          title="Start a broadcast"
          description="Go live with audio or video in seconds."
        >
          <div className="button-row" style={{ marginTop: '12px' }}>
            <button className="button button--primary" type="button">
              Go live now
            </button>
            <button className="button button--ghost" type="button">
              Schedule
            </button>
          </div>
        </Card>
        <Card
          title="Studio checklist"
          description="Set a title, co-hosts, and audience filters."
          badge="Guide"
        />
      </div>

      <Card title="Upcoming broadcasts" description="Your scheduled rooms.">
        <div className="list">
          {broadcasts.map((item) => (
            <div className="list-item" key={item.id}>
              <div>
                <strong>{item.title}</strong>
                <span>{item.host}</span>
              </div>
              <div className="list-item__meta">
                <span>{item.time}</span>
                <button className="button button--soft" type="button">
                  Edit
                </button>
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
};

export default BroadcastPage;
