import Card from '../../components/Card';
import SectionHeader from '../../components/SectionHeader';

const languages = ['English', 'Hindi', 'Bengali', 'Spanish', 'Japanese'];

const LanguagePage = () => {
  return (
    <div className="page">
      <SectionHeader
        title="Language"
        subtitle="Pick your preferred language."
        meta="English"
      />

      <Card title="Language settings" description="Applies across the app.">
        <div className="stack">
          {languages.map((language) => (
            <label className="toggle-row" key={language}>
              <div>
                <strong>{language}</strong>
                <div className="meta">{language}</div>
              </div>
              <input
                type="radio"
                name="language"
                defaultChecked={language === 'English'}
              />
            </label>
          ))}
        </div>
      </Card>
    </div>
  );
};

export default LanguagePage;
