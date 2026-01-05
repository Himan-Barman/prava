import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const requests = [
  { id: 'r1', name: 'Asha Verma', mutual: '3 mutual friends' },
  { id: 'r2', name: 'Kenji Ito', mutual: '1 mutual friend' },
];

const suggestions = [
  { id: 's1', name: 'Liam Chen', role: 'Product lead' },
  { id: 's2', name: 'Priya Nair', role: 'Creator' },
  { id: 's3', name: 'Zara Ali', role: 'Community host' },
];

const FriendsPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Friends"
        subtitle="Requests, followers, and people to follow."
        meta="8 new"
      />

      <div className="page-grid">
        <Card title="Connection requests" description="Approve new followers.">
          <div className="list">
            {requests.map((request) => (
              <div className="list-item" key={request.id}>
                <div>
                  <strong>{request.name}</strong>
                  <span>{request.mutual}</span>
                </div>
                <div className="list-item__actions">
                  <button className="button button--soft" type="button">
                    Accept
                  </button>
                  <button className="button button--ghost" type="button">
                    Decline
                  </button>
                </div>
              </div>
            ))}
          </div>
        </Card>
        <Card title="Follow stats" description="Your community in numbers.">
          <div className="profile-stats">
            <div className="profile-stat">
              <strong>2.4K</strong>
              <div className="meta">Followers</div>
            </div>
            <div className="profile-stat">
              <strong>418</strong>
              <div className="meta">Following</div>
            </div>
            <div className="profile-stat">
              <strong>92</strong>
              <div className="meta">Requests</div>
            </div>
          </div>
        </Card>
      </div>

      <Card
        title="People you may know"
        description="Suggested based on your activity."
      >
        <div className="list">
          {suggestions.map((person) => (
            <div className="list-item" key={person.id}>
              <div>
                <strong>{person.name}</strong>
                <span>{person.role}</span>
              </div>
              <button className="button button--primary" type="button">
                Follow
              </button>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
};

export default FriendsPage;
