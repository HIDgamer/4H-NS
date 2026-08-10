import { Component, ErrorInfo, ReactNode } from 'react';

type Props = {
  readonly children: ReactNode;
};

type State = {
  error: Error | null;
};

// Without this, a render error anywhere in an interface unmounts the entire React tree, leaving
// a genuinely blank window with zero indication anything went wrong — indistinguishable from the
// window never having opened at all. This shows the actual error instead, so a broken interface
// is at least diagnosable from a screenshot rather than reported as "nothing happens."
export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // eslint-disable-next-line no-console
    console.error('Interface crashed:', error, info.componentStack);
  }

  render() {
    const { error } = this.state;
    if (!error) {
      return this.props.children;
    }
    return (
      <div
        style={{
          padding: '12px',
          fontFamily: 'monospace',
          fontSize: '12px',
          color: '#ff6060',
          background: '#1a1a1a',
          height: '100%',
          overflow: 'auto',
          whiteSpace: 'pre-wrap',
        }}
      >
        <div style={{ fontWeight: 'bold', marginBottom: '8px' }}>
          This interface crashed while rendering.
        </div>
        <div>
          {error.name}: {error.message}
        </div>
        <div style={{ marginTop: '8px', opacity: 0.7 }}>{error.stack}</div>
      </div>
    );
  }
}
