type CounterMap = Map<string, number>;

const counters: CounterMap = new Map();
const timings: Map<string, number[]> = new Map();

export function incrementMetric(name: string, value = 1): void {
  counters.set(name, (counters.get(name) || 0) + value);
}

export function observeTiming(name: string, durationMs: number): void {
  const bucket = timings.get(name) || [];
  bucket.push(Math.max(0, durationMs));
  if (bucket.length > 500) {
    bucket.splice(0, bucket.length - 500);
  }
  timings.set(name, bucket);
}

function percentile(values: number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const index = Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length));
  return sorted[index] || 0;
}

export function snapshotMetrics(): Record<string, unknown> {
  const timingSummary: Record<string, unknown> = {};
  for (const [name, values] of timings.entries()) {
    timingSummary[name] = {
      count: values.length,
      p50: percentile(values, 50),
      p95: percentile(values, 95),
      p99: percentile(values, 99),
    };
  }

  return {
    counters: Object.fromEntries(counters.entries()),
    timings: timingSummary,
  };
}
