import { Toaster } from 'react-hot-toast';
import AppRoutes from './routes/AppRoutes';
import AppShell from './shell/AppShell';
import { ThemeProvider } from './ui-system/theme';
import { AuthProvider } from './context/auth-context';
import { ErrorBoundary } from './components/ErrorBoundary';

const App = () => {
  return (
    <ErrorBoundary>
      <ThemeProvider>
        <AuthProvider>
          <AppShell>
            <AppRoutes />
          </AppShell>
          <Toaster
            position="top-center"
            toastOptions={{
              duration: 4000,
              style: {
                background: 'var(--p-bg-surface-elevated)',
                color: 'var(--p-text-primary)',
                borderRadius: 'var(--p-radius-lg)',
                padding: '12px 16px',
                fontSize: '14px',
                fontWeight: '500',
                boxShadow: 'var(--p-shadow-lg)',
                border: '1px solid var(--p-border)',
              },
              success: {
                iconTheme: { primary: 'var(--p-success)', secondary: '#fff' },
                style: { borderColor: 'rgba(46, 204, 113, 0.2)' }
              },
              error: {
                iconTheme: { primary: 'var(--p-danger)', secondary: '#fff' },
                style: { borderColor: 'rgba(231, 76, 60, 0.2)' }
              },
            }}
          />
        </AuthProvider>
      </ThemeProvider>
    </ErrorBoundary>
  );
};

export default App;
