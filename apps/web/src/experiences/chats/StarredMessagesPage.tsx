import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const starred = [
  {
    id: 's1',
    title: 'Design squad',
    body: 'Pinned the new brand narrative draft.',
    time: 'Yesterday',
  },
  {
    id: 's2',
    title: 'Founders room',
    body: 'Metrics snapshot: retention is up 6 percent.',
    time: '2d',
  },
];

const StarredMessagesPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Starred messages"
        subtitle="Your saved highlights across chats."
        meta="2 saved"
      />

      <Card
        title="Pinned moments"
        description="Star important notes to keep them accessible."
      />

      <div className="list">
        {starred.map((item) => (
          <div className="list-item" key={item.id}>
            <div>
              <strong>{item.title}</strong>
              <span>{item.body}</span>
            </div>
            <div className="list-item__meta">
              <span>{item.time}</span>
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

export default StarredMessagesPage;
