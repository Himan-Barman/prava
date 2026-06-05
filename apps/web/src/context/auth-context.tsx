import { createContext, useContext, useEffect, useState, useCallback, type ReactNode } from 'react';
import { authService, AuthSession } from '../services/auth-service';
import { profileService } from '../services/profile-service';
import { webSocketService } from '../services/websocket-service';

interface User {
  id: string;
  email: string;
  username: string;
  displayName: string;
  isVerified: boolean;
}

interface AuthContextValue {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<AuthSession>;
  register: (email: string, password: string, username?: string) => Promise<AuthSession>;
  logout: () => Promise<void>;
  setUser: (user: User | null) => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check if user is already logged in
    const checkAuth = async () => {
      try {
        if (authService.isLoggedIn()) {
          const userId = authService.getUserId();
          if (userId) {
            try {
              const profile = await profileService.fetchMyProfile(0);
              setUser({
                id: userId,
                email: '',
                username: profile.user?.username || '',
                displayName: profile.user?.displayName || '',
                isVerified: profile.user?.isVerified ?? true,
              });
            } catch {
              setUser({ id: userId, email: '', username: '', displayName: '', isVerified: true });
            }
          }
        }
      } catch (error) {
        console.error('Auth check failed:', error);
      } finally {
        setIsLoading(false);
      }
    };

    checkAuth();
  }, []);

  useEffect(() => {
    if (user && authService.isLoggedIn()) {
      webSocketService.connect();
      return () => {
        webSocketService.disconnect();
      };
    }

    webSocketService.disconnect();
    return undefined;
  }, [user]);

  const login = useCallback(async (email: string, password: string) => {
    const session = await authService.login(email, password);
    setUser({
      id: session.userId,
      email: session.email,
      username: session.username || '',
      displayName: session.displayName || '',
      isVerified: session.isVerified,
    });
    return session;
  }, []);

  const register = useCallback(async (email: string, password: string, username?: string) => {
    const session = await authService.register(email, password, username);
    setUser({
      id: session.userId,
      email: session.email,
      username: session.username || username || '',
      displayName: session.displayName || username || '',
      isVerified: session.isVerified,
    });
    return session;
  }, []);

  const logout = useCallback(async () => {
    await authService.logout();
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        isLoading,
        login,
        register,
        logout,
        setUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
