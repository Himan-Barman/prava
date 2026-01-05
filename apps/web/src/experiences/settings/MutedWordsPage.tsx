import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const mutedWords = ['spoilers', 'politics', 'crypto', 'giveaway'];

const MutedWordsPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Muted words"
        subtitle="Reduce unwanted topics in your feed."
        meta="8 words"
      />

      <Card title="Muted list" description="Manage your quiet words.">
        <div className="chip-row" style={{ marginBottom: '12px' }}>
          {mutedWords.map((word) => (
            <span className="chip" key={word}>
              {word}
            </span>
          ))}
        </div>
        <div className="form-grid">
          <label className="field">
            Add a word or phrase
            <input className="input" placeholder="Add a muted word" />
          </label>
          <label className="field">
            Duration
            <select className="input" defaultValue="30">
              <option value="7">7 days</option>
              <option value="30">30 days</option>
              <option value="90">90 days</option>
              <option value="forever">Forever</option>
            </select>
          </label>
        </div>
        <div className="button-row" style={{ marginTop: '16px' }}>
          <button className="button button--soft" type="button">
            Add word
          </button>
        </div>
      </Card>
    </div>
  );
};

export default MutedWordsPage;
