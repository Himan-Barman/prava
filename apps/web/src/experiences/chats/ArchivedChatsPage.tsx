import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const archived = [
  {
    id: 'a1',
    title: 'Creative club',
    preview: 'Weekly review notes are saved in the archive.',
    time: '3d',
  },
  {
    id: 'a2',
    title: 'Launch war room',
    preview: 'Campaign assets and press plan.',
    time: '1w',
  },
];

const ArchivedChatsPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Archived chats"
        subtitle="Keep quiet conversations close by."
        meta="2 chats"
      />

      <Card
        title="Archive policy"
        description="Archived chats stay hidden until you reply or restore them."
      />

      <div className="list">
        {archived.map((chat) => (
          <div className="list-item" key={chat.id}>
            <div>
              <strong>{chat.title}</strong>
              <span>{chat.preview}</span>
            </div>
            <div className="list-item__meta">
              <span>{chat.time}</span>
              <button className="button button--soft" type="button">
                Restore
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default ArchivedChatsPage;
