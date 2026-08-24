import { BLOCK_COLORS, type BlockColor } from '@/lib/hud-data'
import { cn } from '@/lib/utils'

export function BlockCell({
  color,
  className,
}: {
  color: BlockColor
  className?: string
}) {
  if (!color) {
    return (
      <div
        className={cn(
          'aspect-square rounded-[2px] border border-cyan/5 bg-chassis-deep/70',
          className,
        )}
      />
    )
  }

  const c = BLOCK_COLORS[color]

  return (
    <div
      className={cn('relative aspect-square rounded-[3px]', className)}
      style={{
        border: `2px solid ${c}`,
        backgroundColor: 'color-mix(in oklab, var(--chassis-deep) 78%, black)',
        boxShadow: `0 0 4px ${c}, 0 0 12px color-mix(in oklab, ${c} 55%, transparent), inset 0 0 6px color-mix(in oklab, ${c} 35%, transparent)`,
      }}
    >
      <div
        className="absolute inset-[2px] rounded-[1px]"
        style={{
          background: `color-mix(in oklab, ${c} 16%, transparent)`,
        }}
      />
    </div>
  )
}
