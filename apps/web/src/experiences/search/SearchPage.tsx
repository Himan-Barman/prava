import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const trendingTags = ['#prava', '#design', '#startups', '#music', '#ai'];

const suggestions = [
  {
    id: 'p1',
    name: 'Nora Singh',
    detail: 'Growth strategist',
  },
  {
    id: 'p2',
    name: 'Rio Santos',
    detail: 'Product storyteller',
  },
  {
    id: 'p3',
    name: 'Meera Das',
    detail: 'Community builder',
  },
];

const SearchPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Search"
        subtitle="Discover people, topics, and rooms."
        meta="Trending"
      />

      <Card title="Search the network" description="Type a name, topic, or tag.">
        <input className="input" placeholder="Search for people or posts" />
        <div className="chip-row" style={{ marginTop: '12px' }}>
          {trendingTags.map((tag) => (
            <span className="chip" key={tag}>
              {tag}
            </span>
          ))}
        </div>
      </Card>

      <div className="page-grid">
        <Card
          title="Trending rooms"
          description="Live conversations with high engagement."
          badge="Live"
        >
          <div className="list">
            <div className="list-item">
              <div>
                <strong>Creator strategy</strong>
                <span>120 listening now</span>
              </div>
              <button className="button button--soft" type="button">
                Join
              </button>
            </div>
            <div className="list-item">
              <div>
                <strong>AI for storytellers</strong>
                <span>68 listening now</span>
              </div>
              <button className="button button--soft" type="button">
                Join
              </button>
            </div>
          </div>
        </Card>
        <Card
          title="Suggested accounts"
          description="Creators you might want to follow."
        >
          <div className="list">
            {suggestions.map((person) => (
              <div className="list-item" key={person.id}>
                <div>
                  <strong>{person.name}</strong>
                  <span>{person.detail}</span>
                </div>
                <button className="button button--primary" type="button">
                  Follow
                </button>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
};

export default SearchPage;
