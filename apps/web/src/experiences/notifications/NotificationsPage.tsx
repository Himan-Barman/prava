import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const notifications = [
  {
    id: 'n1',
    title: 'Anika mentioned you in a post',
    detail: 'Check out the onboarding preview.',
    time: '4m',
  },
  {
    id: 'n2',
    title: 'Sonia liked your update',
    detail: 'Your wellness checklist resonated.',
    time: '20m',
  },
  {
    id: 'n3',
    title: 'New follower request',
    detail: 'Kenji wants to follow you.',
    time: '2h',
  },
];

const NotificationsPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Notifications"
        subtitle="Mentions, replies, and social pings."
        meta="Today"
      />

      <Card
        title="Priority alerts"
        description="Stay on top of the conversations that matter."
      />

      <div className="list">
        {notifications.map((note) => (
          <div className="list-item" key={note.id}>
            <div>
              <strong>{note.title}</strong>
              <span>{note.detail}</span>
            </div>
            <div className="list-item__meta">
              <span>{note.time}</span>
              <button className="button button--ghost" type="button">
                View
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default NotificationsPage;
