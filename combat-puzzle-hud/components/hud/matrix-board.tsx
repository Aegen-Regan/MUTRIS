import { BlockCell } from '@/components/hud/block-cell'
import { GlyphRow } from '@/components/hud/glyph-row'
import { buildMatrix, type BlockColor } from '@/lib/hud-data'

export function MatrixBoard({
  seed,
  signature,
  label,
  align,
}: {
  seed: number
  signature: Exclude<BlockColor, null>
  label: string
  align: 'left' | 'right'
}) {
  const rows = buildMatrix(seed, signature)

  return (
    <section
      aria-label={`${label} combat matrix`}
      className="flex min-w-0 flex-1 flex-col gap-1.5"
    >
      <GlyphRow align={align} label={label} />

      <div className="notch-panel plate bevel relative p-1.5">
        <div className="carbon scanlines notch-panel relative p-[6px]">
          <div
            className="grid aspect-[10/20] w-full grid-cols-10 gap-[3px]"
            style={{ gridTemplateRows: 'repeat(20, minmax(0, 1fr))' }}
            role="presentation"
          >
            {rows.flatMap((row, y) =>
              row.map((color, x) => (
                <BlockCell
                  key={`${y}-${x}`}
                  color={color}
                  className="aspect-auto h-full w-full"
                />
              )),
            )}
          </div>
        </div>
      </div>
    </section>
  )
}
