import { ChartBar, Crosshair, Radar, Zap } from 'lucide-react'

import { GlyphTile } from '@/components/hud/glyph-row'

export function CommandBar() {
  return (
    <header className="flex items-center gap-2">
      <div className="plate bevel notch-tag flex items-center gap-1.5 px-2 py-1.5">
        <GlyphTile icon={Crosshair} tone="var(--violet)" />
        <GlyphTile icon={Radar} tone="var(--cyan)" />
        <GlyphTile icon={ChartBar} tone="var(--hazard)" />
        <GlyphTile icon={Zap} tone="var(--acid)" />
      </div>

      <div className="plate bevel notch-tag flex flex-1 items-center justify-center gap-3 px-3 py-1.5">
        <span
          className="font-mono text-[10px] tracking-[0.4em] text-hazard"
          style={{ textShadow: '0 0 8px var(--hazard)' }}
        >
          NEXUS CLASH
        </span>
        <span className="hidden font-mono text-[9px] tracking-[0.3em] text-muted-foreground sm:inline">
          SECTOR 07 // DUEL PROTOCOL ACTIVE
        </span>
        <span
          className="animate-blip size-1.5 rounded-full bg-acid"
          style={{ boxShadow: '0 0 8px var(--acid)' }}
          aria-hidden="true"
        />
      </div>

      <div className="hazard bevel notch-tag h-[34px] w-[140px] shrink-0" aria-hidden="true" />
    </header>
  )
}
