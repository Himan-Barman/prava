import { Component, type ReactNode, type ErrorInfo } from 'react';

interface ErrorBoundaryProps {
  children: ReactNode;
  fallback?: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('[ErrorBoundary]', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) return this.props.fallback;

      return (
        <div style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          justifyContent: 'center', minHeight: '60vh', padding: 32,
          textAlign: 'center', fontFamily: 'var(--p-font-sans)',
        }}>
          <div style={{
            width: 52, height: 52, borderRadius: 14,
            background: 'var(--p-danger-subtle)', color: 'var(--p-danger)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            marginBottom: 16, fontSize: 24,
          }}>!</div>
          <h2 style={{
            fontSize: 18, fontWeight: 700,
            color: 'var(--p-text-primary)', marginBottom: 6,
          }}>Something went wrong</h2>
          <p style={{
            fontSize: 14, color: 'var(--p-text-secondary)',
            maxWidth: 400, marginBottom: 20,
          }}>
            {this.state.error?.message || 'An unexpected error occurred.'}
          </p>
          <button
            onClick={() => { this.setState({ hasError: false, error: null }); window.location.reload(); }}
            style={{
              height: 40, padding: '0 20px', borderRadius: 10,
              background: 'var(--p-brand)', color: '#fff',
              border: 'none', fontWeight: 600, fontSize: 14,
              cursor: 'pointer', fontFamily: 'inherit',
            }}
          >
            Reload
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
