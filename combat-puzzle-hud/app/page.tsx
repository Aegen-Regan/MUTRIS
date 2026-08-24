import { CommandBar } from '@/components/hud/command-bar'
import { MatrixBoard } from '@/components/hud/matrix-board'
import { PlasmaReactor } from '@/components/hud/plasma-reactor'
import { SideBay } from '@/components/hud/side-bay'
import { TelemetryTerminal } from '@/components/hud/telemetry-terminal'

export default function Page() {
  return (
    <main className="flex min-h-svh items-center justify-center bg-background p-3 sm:p-6">
      <div
        className="w-full max-w-[1060px]"
        style={{
          filter: 'drop-shadow(0 24px 60px oklch(0.6 0.18 220 / 18%))',
        }}
      >
        {/* outer chassis */}
        <div className="notch-frame plate bevel p-2 sm:p-3">
          <div className="notch-frame carbon relative p-2 sm:p-3">
            {/* corner bolts */}
            <CornerStuds />

            <div className="flex flex-col gap-2">
              <CommandBar />

              <div className="flex items-stretch gap-2 sm:gap-3">
                <SideBay
                  label="HOLD"
                  side="left"
                  data={{
                    top: ['violet', 'cyan'],
                    queue: ['magenta', 'violet', 'violet', 'violet'],
                  }}
                />

                <MatrixBoard
                  seed={20260823}
                  signature="magenta"
                  label="PLAYER-01"
                  align="left"
                />

                <PlasmaReactor />

                <MatrixBoard
                  seed={771205}
                  signature="acid"
                  label="RIVAL-02"
                  align="right"
                />

                <SideBay
                  label="NEXT"
                  side="right"
                  data={{
                    top: ['magenta', 'acid'],
                    queue: ['cyan', 'violet', 'violet', 'violet'],
                  }}
                />
              </div>

              <TelemetryTerminal />
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}

function CornerStuds() {
  const spots = [
    'left-1.5 top-1.5',
    'right-1.5 top-1.5',
    'left-1.5 bottom-1.5',
    'right-1.5 bottom-1.5',
  ]
  return (
    <>
      {spots.map((pos) => (
        <span
          key={pos}
          className={`pointer-events-none absolute ${pos} size-2 rounded-full bg-chassis-edge/70 shadow-[inset_0_1px_0_rgba(255,255,255,0.25),0_1px_2px_#000]`}
          aria-hidden="true"
        />
      ))}
    </>
  )
}
