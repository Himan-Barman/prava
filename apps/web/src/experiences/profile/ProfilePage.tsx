import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const recentPosts = [
  {
    id: 'p1',
    body: 'Building a new onboarding guide for creators.',
    time: '1d',
  },
  {
    id: 'p2',
    body: 'Hosting a live room on product storytelling tomorrow.',
    time: '3d',
  },
];

const ProfilePage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Profile"
        subtitle="Your presence, stats, and latest posts."
        meta="Verified"
      />

      <div className="card profile-card">
        <div className="profile-hero">
          <div className="avatar avatar--soft avatar--lg">HB</div>
          <div className="profile-meta">
            <strong>Himan Barman</strong>
            <span>@himanbarman</span>
            <span>Founder and community host</span>
          </div>
        </div>
        <div className="profile-stats">
          <div className="profile-stat">
            <strong>128</strong>
            <div className="meta">Posts</div>
          </div>
          <div className="profile-stat">
            <strong>2.4K</strong>
            <div className="meta">Followers</div>
          </div>
          <div className="profile-stat">
            <strong>418</strong>
            <div className="meta">Following</div>
          </div>
        </div>
        <div className="button-row">
          <button className="button button--primary" type="button">
            Edit profile
          </button>
          <button className="button button--ghost" type="button">
            Share profile
          </button>
        </div>
      </div>

      <div className="page-grid">
        <Card
          title="Creator insights"
          description="Audience growth and engagement stats."
          badge="Weekly"
        />
        <Card
          title="Pinned links"
          description="Update the links featured on your profile."
        />
      </div>

      <Card title="Recent posts" description="Latest updates from your feed.">
        <div className="list">
          {recentPosts.map((post) => (
            <div className="list-item" key={post.id}>
              <div>
                <strong>{post.body}</strong>
                <span>Prava feed</span>
              </div>
              <div className="list-item__meta">
                <span>{post.time}</span>
                <button className="button button--ghost" type="button">
                  View
                </button>
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
};

export default ProfilePage;
