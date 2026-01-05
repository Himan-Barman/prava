import { NavLink } from 'react-router-dom';

import { navItems } from '../routes/navConfig';

const Sidebar = () => {
  const core = navItems.filter((item) => item.group === 'core');
  const community = navItems.filter((item) => item.group === 'community');
  const settings = navItems.filter((item) => item.group === 'settings');

  return (
    <aside className="sidebar">
      <div className="sidebar__brand">
        <div className="sidebar__brand-icon">P</div>
        <span>Prava</span>
      </div>

      <nav className="sidebar__nav">
        {core.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) =>
              `nav-link${isActive ? ' active' : ''}`
            }
          >
            <item.icon />
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>

      <div>
        <div className="sidebar__section">Community</div>
        <nav className="sidebar__nav">
          {community.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) =>
                `nav-link${isActive ? ' active' : ''}`
              }
            >
              <item.icon />
              <span>{item.label}</span>
            </NavLink>
          ))}
        </nav>
      </div>

      <div>
        <div className="sidebar__section">Settings</div>
        <nav className="sidebar__nav">
          {settings.map((item) => (
            <NavLink
              key={item.path}
              to={item.path}
              className={({ isActive }) =>
                `nav-link${isActive ? ' active' : ''}`
              }
            >
              <item.icon />
              <span>{item.label}</span>
            </NavLink>
          ))}
        </nav>
      </div>

      <div className="sidebar__footer">
        <div className="sidebar__cta">
          <strong>Security status</strong>
          <p>Keep your account protected with 2FA and device checks.</p>
        </div>
      </div>
    </aside>
  );
};

export default Sidebar;
