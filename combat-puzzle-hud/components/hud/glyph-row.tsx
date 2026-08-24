import {
  Activity,
  ChartBar,
  Crosshair,
  Cpu,
  Radar,
  Radiation,
  Target,
  Waves,
  Zap,
} from 'lucide-react'

import { cn } from '@/lib/utils'

export function GlyphTile({
  icon: Icon,
  tone,
  size = 12,
}: {
  icon: React.ElementType
  tone: string
  size?: number
}) {
  return (
    <span
      className="notch-tag flex size-[22px] shrink-0 items-center justify-center border bg-chassis-deep/80"
      style={{
        borderColor: `color-mix(in oklab, ${tone} 45%, transparent)`,
        boxShadow: `0 0 6px color-mix(in oklab, ${tone} 30%, transparent)`,
      }}
    >
      <Icon
        size={size}
        style={{ color: tone, filter: `drop-shadow(0 0 4px ${tone})` }}
        strokeWidth={2}
      />
    </span>
  )
}

const LEFT_GLYPHS = [
  { icon: Crosshair, tone: 'var(--cyan)' },
  { icon: Radar, tone: 'var(--magenta)' },
  { icon: Waves, tone: 'var(--violet)' },
  { icon: ChartBar, tone: 'var(--cyan)' },
]

const RIGHT_GLYPHS = [
  { icon: Zap, tone: 'var(--hazard)' },
  { icon: Cpu, tone: 'var(--magenta)' },
  { icon: Activity, tone: 'var(--acid)' },
  { icon: Target, tone: 'var(--cyan)' },
]

export function GlyphRow({
  align,
  label,
}: {
  align: 'left' | 'right'
  label: string
}) {
  const glyphs = align === 'left' ? LEFT_GLYPHS : RIGHT_GLYPHS

  return (
    <div
      className={cn(
        'notch-panel plate bevel flex items-center gap-2 px-2.5 py-1.5',
        align === 'right' && 'flex-row-reverse',
      )}
    >
      <div className={cn('flex items-center gap-1.5', align === 'right' && 'flex-row-reverse')}>
        {glyphs.map((g, i) => (
          <GlyphTile key={i} icon={g.icon} tone={g.tone} />
        ))}
      </div>

      <span
        className="font-mono text-[10px] tracking-[0.22em] text-cyan/80"
        style={{ textShadow: '0 0 8px var(--cyan)' }}
      >
        {label}
      </span>

      <div
        className={cn(
          'ml-auto flex items-center gap-1',
          align === 'right' && 'mr-auto ml-0 flex-row-reverse',
        )}
      >
        <Radiation
          size={11}
          className="text-muted-foreground/70"
          aria-hidden="true"
        />
        <span className="font-mono text-[9px] tracking-widest text-muted-foreground/70">
          {align === 'left' ? 'LNK-04' : 'LNK-07'}
        </span>
        <div className="hazard h-2.5 w-8 opacity-70" aria-hidden="true" />
      </div>
    </div>
  )
}
