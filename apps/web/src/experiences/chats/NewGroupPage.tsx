import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const suggested = ['Anika Roy', 'Dev Patel', 'Sonia Khan', 'Maya Lee'];

const NewGroupPage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="New group"
        subtitle="Create a space for your closest people."
        meta="Step 1"
      />

      <Card
        title="Group details"
        description="Give your group a name and a short description."
      >
        <div className="form-grid">
          <label className="field">
            Group name
            <input className="input" placeholder="Creative crew" />
          </label>
          <label className="field">
            Group privacy
            <select className="input" defaultValue="private">
              <option value="private">Private</option>
              <option value="public">Public</option>
              <option value="invite">Invite only</option>
            </select>
          </label>
        </div>
        <label className="field" style={{ marginTop: '16px' }}>
          Description
          <textarea
            className="input input--textarea"
            placeholder="Tell members what the group is about."
          />
        </label>
        <div className="button-row" style={{ marginTop: '16px' }}>
          <button className="button button--ghost" type="button">
            Save draft
          </button>
          <button className="button button--primary" type="button">
            Create group
          </button>
        </div>
      </Card>

      <Card
        title="Suggested members"
        description="Invite people you interact with the most."
      >
        <div className="list">
          {suggested.map((person) => (
            <div className="list-item" key={person}>
              <div>
                <strong>{person}</strong>
                <span>Active today</span>
              </div>
              <button className="button button--soft" type="button">
                Add
              </button>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
};

export default NewGroupPage;
