import { BlockCell } from '@/components/hud/block-cell'
import type { BlockColor } from '@/lib/hud-data'
import { cn } from '@/lib/utils'

type Queue = { top: Exclude<BlockColor, null>[]; queue: Exclude<BlockColor, null>[] }

export function SideBay({
  label,
  side,
  data,
}: {
  label: string
  side: 'left' | 'right'
  data: Queue
}) {
  return (
    <aside
      aria-label={`${label} bay`}
      className="flex w-[78px] shrink-0 flex-col gap-2 sm:w-[92px]"
    >
      {/* active slot */}
      <div className="plate bevel notch-panel p-1.5">
        <div className="carbon notch-panel flex aspect-square items-center justify-center p-2">
          <div className="grid w-[60%] grid-cols-1 gap-[3px]">
            {data.top.map((c, i) => (
              <BlockCell key={i} color={c} />
            ))}
          </div>
        </div>
      </div>

      {/* label tag */}
      <div className="notch-tag plate bevel py-1 text-center">
        <span
          className="font-mono text-[11px] tracking-[0.3em] text-foreground/90"
          style={{ textShadow: '0 0 8px color-mix(in oklab, var(--cyan) 70%, transparent)' }}
        >
          {label}
        </span>
      </div>

      {/* queue column with hazard rail */}
      <div className="relative flex flex-1 gap-1.5">
        {side === 'left' && <HazardRail />}
        <div className="plate bevel notch-panel flex-1 p-1.5">
          <div className="carbon scanlines notch-panel flex h-full flex-col items-center justify-around gap-2 p-2">
            {data.queue.map((c, i) => (
              <BlockCell key={i} color={c} className="w-[70%]" />
            ))}
          </div>
        </div>
        {side === 'right' && <HazardRail />}
      </div>

      {/* status readout */}
      <div className="plate bevel notch-tag flex items-center justify-between px-2 py-1">
        <span className="font-mono text-[8px] tracking-widest text-muted-foreground">QUE</span>
        <span
          className="font-mono text-[9px] text-magenta"
          style={{ textShadow: '0 0 8px var(--magenta)' }}
        >
          {side === 'left' ? '0x1F' : '0x2C'}
        </span>
      </div>
    </aside>
  )
}

function HazardRail({ className }: { className?: string }) {
  return (
    <div className={cn('flex w-4 flex-col gap-1', className)} aria-hidden="true">
      <div className="hazard bevel h-[38%] w-full opacity-90" />
      <div className="plate bevel flex-1 w-full" />
      <div
        className="h-[18%] w-full rounded-sm"
        style={{
          background:
            'linear-gradient(180deg, transparent, color-mix(in oklab, var(--magenta) 60%, transparent))',
          boxShadow: '0 0 10px color-mix(in oklab, var(--magenta) 50%, transparent)',
        }}
      />
    </div>
  )
}
