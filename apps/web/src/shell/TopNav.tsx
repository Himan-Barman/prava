import { Bell, Sparkles } from 'lucide-react';
import { useLocation } from 'react-router-dom';

import { pageTitles } from '../routes/navConfig';

const TopNav = () => {
  const location = useLocation();
  const meta = pageTitles[location.pathname] ?? {
    title: 'Prava',
    subtitle: 'Stay connected across every room.'
  };

  return (
    <header className="topbar">
      <div className="topbar__title">
        <h1>{meta.title}</h1>
        <span>{meta.subtitle}</span>
      </div>
      <div className="topbar__actions">
        <label className="search-input">
          <Sparkles size={16} />
          <input placeholder="Search people, topics, or chats" />
        </label>
        <button className="pill" type="button">
          <Bell size={14} />
          Live alerts
        </button>
        <div className="avatar">HB</div>
      </div>
    </header>
  );
};

export default TopNav;
