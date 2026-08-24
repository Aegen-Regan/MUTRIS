export function PlasmaReactor() {
  return (
    <div
      className="relative flex w-[46px] shrink-0 flex-col items-center sm:w-[58px]"
      aria-label="Plasma clash reactor"
      role="img"
    >
      {/* housing */}
      <div className="plate bevel notch-panel relative flex h-full w-full flex-col items-center overflow-hidden py-2">
        {/* upper + lower collars */}
        <ReactorCollar />
        <div className="relative flex-1 w-full">
          {/* core tube */}
          <div className="absolute inset-x-0 top-0 bottom-0 mx-auto w-[14px] rounded-full bg-chassis-deep shadow-[inset_0_0_10px_#000]" />
          <div
            className="animate-reactor absolute inset-y-2 left-1/2 w-[7px] -translate-x-1/2 rounded-full"
            style={{
              background:
                'linear-gradient(180deg, color-mix(in oklab, var(--cyan) 30%, transparent), var(--cyan) 18%, oklch(0.98 0.03 220) 50%, var(--cyan) 82%, color-mix(in oklab, var(--cyan) 30%, transparent))',
              boxShadow:
                '0 0 10px var(--cyan), 0 0 28px color-mix(in oklab, var(--cyan) 60%, transparent), 0 0 60px color-mix(in oklab, var(--cyan) 35%, transparent)',
            }}
          />

          {/* mid-tube containment rings */}
          {[18, 34, 50, 66, 82].map((t) => (
            <div
              key={t}
              className="absolute left-1/2 h-[3px] w-[22px] -translate-x-1/2 rounded-sm bg-chassis-edge/80 shadow-[0_0_6px_rgba(0,0,0,0.8)]"
              style={{ top: `${t}%` }}
            />
          ))}

          {/* clash flare */}
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2">
            <div
              className="animate-flare size-[54px]"
              style={{
                background:
                  'conic-gradient(from 0deg, transparent 0deg, color-mix(in oklab, var(--cyan) 70%, transparent) 6deg, transparent 12deg, transparent 84deg, oklch(0.98 0.02 220) 90deg, transparent 96deg, transparent 174deg, color-mix(in oklab, var(--cyan) 70%, transparent) 180deg, transparent 186deg, transparent 264deg, oklch(0.98 0.02 220) 270deg, transparent 276deg)',
                maskImage: 'radial-gradient(circle, black 0%, transparent 72%)',
              }}
            />
            <div
              className="absolute top-1/2 left-1/2 size-3 -translate-x-1/2 -translate-y-1/2 rounded-full bg-white"
              style={{
                boxShadow:
                  '0 0 12px #fff, 0 0 26px var(--cyan), 0 0 56px color-mix(in oklab, var(--cyan) 70%, transparent)',
              }}
            />
          </div>

          {/* travelling sparks */}
          {[12, 30, 62, 78].map((t, i) => (
            <span
              key={t}
              className="animate-spark absolute left-1/2 size-[3px] -translate-x-1/2 rounded-full bg-white"
              style={{
                top: `${t}%`,
                animationDelay: `${i * 0.6}s`,
                boxShadow: '0 0 8px #fff, 0 0 16px var(--cyan)',
              }}
            />
          ))}
        </div>
        <ReactorCollar flipped />
      </div>

      {/* ambient bloom bleeding onto both matrices */}
      <div
        className="pointer-events-none absolute inset-y-6 left-1/2 w-[120px] -translate-x-1/2"
        style={{
          background:
            'radial-gradient(ellipse at center, color-mix(in oklab, var(--cyan) 22%, transparent), transparent 70%)',
        }}
        aria-hidden="true"
      />
    </div>
  )
}

function ReactorCollar({ flipped }: { flipped?: boolean }) {
  return (
    <div
      className={`relative flex w-full flex-col items-center gap-1 py-1 ${
        flipped ? 'rotate-180' : ''
      }`}
    >
      <div className="h-1.5 w-[70%] rounded-sm bg-chassis-edge/70" />
      <div
        className="size-2 rounded-full bg-cyan"
        style={{ boxShadow: '0 0 10px var(--cyan), 0 0 22px var(--cyan)' }}
      />
      <div className="h-1 w-[50%] rounded-sm bg-chassis-edge/50" />
    </div>
  )
}
