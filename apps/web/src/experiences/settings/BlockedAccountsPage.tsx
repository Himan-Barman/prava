import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const blocked = [
  { id: 'b1', name: 'Alex Morgan', reason: 'Spam reports' },
  { id: 'b2', name: 'CreatorX', reason: 'Muted and blocked' },
];

const BlockedAccountsPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Blocked accounts"
        subtitle="People you have blocked will not see your content."
        meta="2 blocked"
      />

      <Card
        title="Blocked list"
        description="Unblock anytime from this list."
      >
        <div className="list">
          {blocked.map((person) => (
            <div className="list-item" key={person.id}>
              <div>
                <strong>{person.name}</strong>
                <span>{person.reason}</span>
              </div>
              <button className="button button--ghost" type="button">
                Unblock
              </button>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
};

export default BlockedAccountsPage;
