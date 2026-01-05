import { Headphones, MessageSquare, Users } from 'lucide-react';

import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const activeNow = ['AR', 'DP', 'SK', 'JT', 'MA'];

const conversations = [
  {
    id: 'c1',
    title: 'Design squad',
    preview: 'Deck is ready for tomorrow. Sync later?',
    time: '2m',
    unread: 3,
  },
  {
    id: 'c2',
    title: 'Founders room',
    preview: 'Demo day checklist updated in the drive.',
    time: '18m',
    unread: 1,
  },
  {
    id: 'c3',
    title: 'Prava crew',
    preview: 'Lunch meetup at 1:00 PM near the studio.',
    time: '1h',
    unread: 0,
  },
];

const ChatsPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Chats"
        subtitle="Conversations, group rooms, and live spaces."
        meta="12 active"
      />

      <div className="page-grid">
        <Card title="Active now" description="Jump back in with your circles.">
          <div className="avatar-row">
            {activeNow.map((initials) => (
              <div
                className="avatar avatar--soft avatar--xs"
                key={initials}
              >
                {initials}
              </div>
            ))}
          </div>
        </Card>
        <Card title="Quick actions" description="Start a new conversation.">
          <div className="button-row">
            <button className="button button--primary" type="button">
              <Users size={14} /> New group
            </button>
            <button className="button button--soft" type="button">
              <Headphones size={14} /> Start room
            </button>
            <button className="button button--ghost" type="button">
              <MessageSquare size={14} /> New chat
            </button>
          </div>
        </Card>
      </div>

      <div className="list">
        {conversations.map((chat) => (
          <div className="list-item" key={chat.id}>
            <div>
              <strong>{chat.title}</strong>
              <span>{chat.preview}</span>
            </div>
            <div className="list-item__meta">
              <span>{chat.time}</span>
              {chat.unread > 0 ? (
                <span className="badge">{chat.unread} new</span>
              ) : (
                <span className="pill">Read</span>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default ChatsPage;
