import { Heart, MessageCircle, Repeat2, Sparkles, TrendingUp } from 'lucide-react';

import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const highlights = [
  {
    title: 'Daily pulse',
    description: 'Your engagement is up 18 percent this week.',
    badge: 'Today',
  },
  {
    title: 'Live rooms',
    description: 'Three broadcasts match your interests right now.',
    badge: 'Live',
  },
  {
    title: 'Creator spotlight',
    description: 'Follow Anika for product and design deep dives.',
    badge: 'New',
  },
];

const posts = [
  {
    id: 'post-1',
    name: 'Anika Roy',
    handle: 'anikar',
    time: '2m',
    body: 'Shipping a new onboarding flow today. Looking for feedback and beta testers.',
    likes: 128,
    comments: 34,
    shares: 12,
  },
  {
    id: 'post-2',
    name: 'Dev Patel',
    handle: 'devp',
    time: '12m',
    body: 'Just joined Prava. Excited to build community around indie games.',
    likes: 56,
    comments: 9,
    shares: 4,
  },
  {
    id: 'post-3',
    name: 'Sonia Khan',
    handle: 'soniak',
    time: '1h',
    body: 'Morning run done. Sharing a quick checklist for creator wellness.',
    likes: 214,
    comments: 44,
    shares: 22,
  },
];

const FeedPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Your feed"
        subtitle="For you and following updates across Prava."
        meta="For you"
      />

      <div className="segmented">
        <button className="active" type="button">
          For you
        </button>
        <button type="button">Following</button>
      </div>

      <Card className="card--glass composer">
        <div className="composer__row">
          <div className="avatar avatar--soft avatar--sm">HB</div>
          <div className="composer__input">
            <textarea
              className="input input--textarea"
              placeholder="Share an update with your community"
            />
            <div className="chip-row">
              <span className="chip">#product</span>
              <span className="chip">#design</span>
              <span className="chip">#community</span>
            </div>
          </div>
        </div>
        <div className="composer__actions">
          <span className="meta">Visible to followers and friends</span>
          <div className="button-row">
            <button className="button button--ghost" type="button">
              Add media
            </button>
            <button className="button button--primary" type="button">
              Post update
            </button>
          </div>
        </div>
      </Card>

      <div className="page-grid">
        {highlights.map((item) => (
          <Card
            key={item.title}
            title={item.title}
            description={item.description}
            badge={item.badge}
          />
        ))}
      </div>

      <div className="stack">
        {posts.map((post) => (
          <div className="card post-card" key={post.id}>
            <div className="post-header">
              <div className="post-author">
                <div className="avatar avatar--soft avatar--sm">
                  {post.name
                    .split(' ')
                    .map((part) => part[0])
                    .join('')}
                </div>
                <div>
                  <strong>{post.name}</strong>
                  <div className="post-meta">
                    @{post.handle} · {post.time}
                  </div>
                </div>
              </div>
              <button className="button button--soft" type="button">
                Follow
              </button>
            </div>
            <div>{post.body}</div>
            <div className="post-actions">
              <button className="icon-button active" type="button">
                <Heart /> {post.likes}
              </button>
              <button className="icon-button" type="button">
                <MessageCircle /> {post.comments}
              </button>
              <button className="icon-button" type="button">
                <Repeat2 /> {post.shares}
              </button>
              <button className="icon-button" type="button">
                <Sparkles /> Boost
              </button>
              <button className="icon-button" type="button">
                <TrendingUp /> Trends
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default FeedPage;
