export type BlockColor = 'cyan' | 'magenta' | 'violet' | 'acid' | null

export const BLOCK_COLORS: Record<Exclude<BlockColor, null>, string> = {
  cyan: 'var(--cyan)',
  magenta: 'var(--magenta)',
  violet: 'var(--violet)',
  acid: 'var(--acid)',
}

/** deterministic PRNG so server + client render identical matrices */
function mulberry32(seed: number) {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

export const MATRIX_COLS = 10
export const MATRIX_ROWS = 20

/**
 * Builds a 10x20 combat matrix: dense mid/lower stack with a thinning crown,
 * weighted toward the board's signature hue.
 */
export function buildMatrix(seed: number, signature: Exclude<BlockColor, null>) {
  const rand = mulberry32(seed)
  const palette: Exclude<BlockColor, null>[] = [
    'cyan',
    'cyan',
    'violet',
    'violet',
    'magenta',
    signature,
    'acid',
  ]

  const rows: BlockColor[][] = []
  for (let y = 0; y < MATRIX_ROWS; y++) {
    const depth = y / (MATRIX_ROWS - 1)
    const density = 0.5 + depth * 0.42
    const row: BlockColor[] = []
    for (let x = 0; x < MATRIX_COLS; x++) {
      row.push(rand() < density ? palette[Math.floor(rand() * palette.length)] : null)
    }
    rows.push(row)
  }
  return rows
}

/** small 2x2-ish tetromino previews for the hold / next bays */
export const PREVIEW_PIECES: { cells: [number, number][]; color: Exclude<BlockColor, null> }[] = [
  { cells: [[0, 0]], color: 'violet' },
  { cells: [[0, 0]], color: 'cyan' },
  { cells: [[0, 0]], color: 'magenta' },
  { cells: [[0, 0]], color: 'acid' },
]

export function buildWaveform(seed: number, count: number) {
  const rand = mulberry32(seed)
  return Array.from({ length: count }, (_, i) => {
    const envelope = Math.abs(Math.sin((i / count) * Math.PI * 3.2)) * 0.7 + 0.25
    const jitter = 0.35 + rand() * 0.85
    return Math.min(1, envelope * jitter)
  })
}

export function buildSpectrum(seed: number, count: number) {
  const rand = mulberry32(seed)
  return Array.from({ length: count }, () => 0.25 + rand() * 0.75)
}
