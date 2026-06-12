/**
 * Lightweight route-loading fallback.
 * Shows a subtle branded spinner while lazy-loaded routes are fetched.
 */
export function PageLoader() {
  return (
    <div style={{
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '60vh',
    }}>
      <div className="p-spinner" />
    </div>
  );
}
