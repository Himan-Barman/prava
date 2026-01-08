import { Toaster } from 'react-hot-toast';
import AppRoutes from './routes/AppRoutes';
import AppShell from './shell/AppShell';
import { ThemeProvider } from './ui-system/theme';
import { AuthProvider } from './context/auth-context';

const App = () => {
  return (
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
              background: 'var(--prava-toast-bg, #1D1D1D)',
              color: 'var(--prava-toast-text, #F2F2F2)',
              borderRadius: '16px',
              padding: '12px 16px',
              fontSize: '14px',
              fontWeight: '500',
              boxShadow: '0 8px 30px rgba(0,0,0,0.12)',
              border: '1px solid rgba(255,255,255,0.05)',
            }, // Default styles for simple toasts
            success: {
              iconTheme: { primary: '#3CCB7F', secondary: '#fff' },
              style: { border: '1px solid rgba(60, 203, 127, 0.2)' }
            },
            error: {
              iconTheme: { primary: '#E5533D', secondary: '#fff' },
              style: { border: '1px solid rgba(229, 83, 61, 0.2)' }
            },
          }}
        />
      </AuthProvider>
    </ThemeProvider>
  );
};

export default App;
