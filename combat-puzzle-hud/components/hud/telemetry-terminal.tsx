import {
  Activity,
  ChartBar,
  Cpu,
  Crosshair,
  Infinity as InfinityIcon,
  Radar,
  Radiation,
  ShieldHalf,
  Waves,
  Zap,
} from 'lucide-react'

import { GlyphTile } from '@/components/hud/glyph-row'
import { buildSpectrum, buildWaveform } from '@/lib/hud-data'

const READOUTS = [
  { k: 'SYNC', v: '98.412', tone: 'var(--hazard)' },
  { k: 'DMG', v: '00734', tone: 'var(--cyan)' },
  { k: 'CMB', v: '16x', tone: 'var(--magenta)' },
  { k: 'FREQ', v: '440.02', tone: 'var(--cyan)' },
  { k: 'LOAD', v: '112090', tone: 'var(--acid)' },
  { k: 'ENT', v: '7.000', tone: 'var(--hazard)' },
  { k: 'PRS', v: '210', tone: 'var(--magenta)' },
]

export function TelemetryTerminal() {
  const left = buildWaveform(9713, 46)
  const right = buildWaveform(4471, 40)
  const spectrum = buildSpectrum(2286, 22)

  return (
    <section
      aria-label="Telemetry terminal and audio synthesizer"
      className="plate bevel notch-panel mt-2 flex items-stretch gap-2 p-2"
    >
      {/* left glyph cluster */}
      <div className="carbon notch-panel hidden shrink-0 flex-col justify-between gap-1.5 p-2 md:flex">
        <div className="flex gap-1.5">
          <GlyphTile icon={ChartBar} tone="var(--acid)" />
          <GlyphTile icon={Cpu} tone="var(--acid)" />
          <GlyphTile icon={Radar} tone="var(--cyan)" />
        </div>
        <div className="flex items-center gap-1.5">
          <GlyphTile icon={ShieldHalf} tone="var(--hazard)" />
          <span className="font-mono text-[9px] tracking-widest text-muted-foreground">
            38R
          </span>
        </div>
      </div>

      {/* central scope */}
      <div className="carbon scanlines notch-panel relative flex min-w-0 flex-1 flex-col gap-1 p-2">
        {/* readout ticker */}
        <div className="flex items-center justify-between gap-3 overflow-hidden">
          {READOUTS.map((r) => (
            <span key={r.k} className="flex shrink-0 items-baseline gap-1 font-mono">
              <span className="text-[8px] tracking-widest text-muted-foreground/80">{r.k}</span>
              <span
                className="text-[11px] leading-none"
                style={{ color: r.tone, textShadow: `0 0 8px ${r.tone}` }}
              >
                {r.v}
              </span>
            </span>
          ))}
        </div>

        {/* synthesizer */}
        <div className="flex flex-1 items-center gap-2">
          <WaveBars values={left} tone="var(--hazard)" mix="var(--cyan)" />
          <Spectrum values={spectrum} />
          <WaveBars values={right} tone="var(--cyan)" mix="var(--magenta)" reverse />
        </div>

        {/* baseline glyph strip */}
        <div className="flex items-center justify-center gap-2">
          <GlyphTile icon={Waves} tone="var(--cyan)" size={10} />
          <GlyphTile icon={Activity} tone="var(--acid)" size={10} />
          <GlyphTile icon={Zap} tone="var(--magenta)" size={10} />
          <span className="font-mono text-[9px] tracking-[0.3em] text-cyan/70">
            OSC-01 // STEREO CLASH BUS
          </span>
          <GlyphTile icon={Radiation} tone="var(--hazard)" size={10} />
          <GlyphTile icon={Crosshair} tone="var(--violet)" size={10} />
        </div>
      </div>

      {/* right control cluster */}
      <div className="carbon notch-panel hidden shrink-0 flex-col justify-between gap-1.5 p-2 md:flex">
        <div className="flex gap-1.5">
          <GlyphTile icon={Radar} tone="var(--cyan)" />
          <GlyphTile icon={Activity} tone="var(--magenta)" />
        </div>
        <div className="flex items-center gap-1.5">
          <GlyphTile icon={InfinityIcon} tone="var(--cyan)" />
          <span
            className="font-mono text-[10px] text-hazard"
            style={{ textShadow: '0 0 8px var(--hazard)' }}
          >
            19
          </span>
        </div>
      </div>
    </section>
  )
}

function WaveBars({
  values,
  tone,
  mix,
  reverse,
}: {
  values: number[]
  tone: string
  mix: string
  reverse?: boolean
}) {
  return (
    <div className="flex h-10 min-w-0 flex-1 items-center gap-[2px]">
      {values.map((v, i) => {
        const c = i % 5 === 0 ? mix : tone
        return (
          <span
            key={i}
            className="animate-wave flex-1 rounded-[1px]"
            style={{
              height: `${Math.max(8, v * 100)}%`,
              background: `linear-gradient(180deg, transparent, ${c} 22%, ${c} 78%, transparent)`,
              boxShadow: `0 0 6px color-mix(in oklab, ${c} 70%, transparent)`,
              animationDelay: `${((reverse ? values.length - i : i) % 9) * 0.09}s`,
            }}
          />
        )
      })}
    </div>
  )
}

function Spectrum({ values }: { values: number[] }) {
  const tones = ['var(--cyan)', 'var(--magenta)', 'var(--violet)', 'var(--acid)']
  return (
    <div className="flex h-10 shrink-0 items-end gap-[3px]">
      {values.map((v, i) => {
        const c = tones[i % tones.length]
        return (
          <span
            key={i}
            className="animate-wave w-[5px] rounded-[1px]"
            style={{
              height: `${Math.max(14, v * 100)}%`,
              background: c,
              boxShadow: `0 0 6px ${c}, 0 0 12px color-mix(in oklab, ${c} 55%, transparent)`,
              animationDelay: `${(i % 7) * 0.11}s`,
              transformOrigin: 'bottom',
            }}
          />
        )
      })}
    </div>
  )
}
