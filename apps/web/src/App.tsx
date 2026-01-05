import AppRoutes from './routes/AppRoutes';
import AppShell from './shell/AppShell';

const App = () => {
  return (
    <AppShell>
      <AppRoutes />
    </AppShell>
  );
};

export default App;
