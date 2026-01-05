import { ReactNode } from 'react';

import Sidebar from './Sidebar';
import TopNav from './TopNav';

interface AppShellProps {
  children: ReactNode;
}

const AppShell = ({ children }: AppShellProps) => {
  return (
    <div className="app-shell">
      <Sidebar />
      <div className="main">
        <TopNav />
        <div className="content">{children}</div>
      </div>
    </div>
  );
};

export default AppShell;
