import { useEffect, useRef, useState } from 'react'
import { ChevronLeft, ArrowRight, ArrowUp, CornerUpLeft, CornerUpRight, MoveUpLeft, MoveUpRight, RotateCcw, Search, Split, Flag } from 'lucide-react'
import { Emoji } from '../icons'
import { fmtKm, pct, type Reco } from '../data'
import { along, type Route } from '../route'

// ---------- route preview (Waze "Leave later / Go now")
export function RoutePreview({ r, route, onBack, onGo }: { r: Reco; route: Route | null; onBack: () => void; onGo: () => void }) {
  return (
    <>
      <div className="topbar">
        <button onClick={onBack}><ChevronLeft size={30} /></button>
        <div className="from" style={{ flex: 1, display: 'flex', alignItems: 'center', gap: 8 }}>
          Jūsų vieta <ArrowRight size={16} /> <span style={{ color: 'var(--text)', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.v.s.name}</span>
        </div>
      </div>
      {route && (
        <div style={{ position: 'absolute', zIndex: 6, top: 132, right: 18 }} className="eta-bubble">
          {route.min} min<small>Geriausias</small>
        </div>
      )}
      <div className="sheet">
        <div className="grabber" />
        <div className="pad">
          {route ? (
            <>
              <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
                <div style={{ fontSize: 30, fontWeight: 800 }}>{route.min} min</div>
                <div className="muted" style={{ fontSize: 17 }}>{fmtKm(route.km)}</div>
              </div>
              <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {route.via ? `Per ${route.via}` : r.v.s.addr}
              </div>
              <div className="big-status" style={{ background: r.v.free > 0 ? '#e3f7ea' : '#fff0dc', marginTop: 14 }}>
                <Emoji name={r.v.free > 0 ? 'high_voltage' : 'hourglass_not_done'} size={34} />
                <div>
                  <div style={{ fontWeight: 800, fontSize: 18 }}>{pct(r.pArrive)} tikimybė, kad atvykus bus laisva</div>
                  <div className="d">{r.v.free > 0 ? `Dabar laisvos ${r.v.free} iš ${r.v.total}` : `Visos užimtos · ${r.wait > 0 ? `laukti ~${r.wait} min` : 'turėtų atsilaisvinti, kol važiuosite'}`}</div>
                </div>
              </div>
            </>
          ) : <div className="muted" style={{ padding: '20px 0' }}>Skaičiuojamas maršrutas…</div>}
        </div>
        <div className="btns" style={{ borderTop: '1px solid var(--line)', marginTop: 18 }}>
          <button className="btn secondary" onClick={onBack}>Vėliau</button>
          <button className="btn primary" disabled={!route} onClick={onGo}>Važiuojam</button>
        </div>
      </div>
    </>
  )
}

function ManeuverIcon({ type, modifier, size = 56 }: { type: string; modifier?: string; size?: number }) {
  const p = { size, strokeWidth: 2.6 }
  if (type === 'arrive') return <Flag {...p} />
  if (modifier === 'uturn') return <RotateCcw {...p} />
  if (modifier === 'right' || modifier === 'sharp right') return <CornerUpRight {...p} />
  if (modifier === 'left' || modifier === 'sharp left') return <CornerUpLeft {...p} />
  if (modifier === 'slight right') return <MoveUpRight {...p} />
  if (modifier === 'slight left') return <MoveUpLeft {...p} />
  return <ArrowUp {...p} />
}

// ---------- turn-by-turn simulation (drives the route at ~8x speed)
export function Navigation({ r, route, onPos, onArrive, onStop }: {
  r: Reco; route: Route; onPos: (p: [number, number], bearing: number) => void; onArrive: () => void; onStop: () => void
}) {
  const [d, setD] = useState(0) // km travelled
  const total = route.cum[route.cum.length - 1]
  const raf = useRef(0)
  const speedKmh = 38
  const factor = 8

  useEffect(() => {
    let last = performance.now()
    let travelled = 0
    let lastEmit = 0
    const tick = (t: number) => {
      const dt = (t - last) / 1000; last = t
      travelled = Math.min(total, travelled + (speedKmh * factor / 3600) * dt)
      if (t - lastEmit > 250 || travelled >= total) {
        lastEmit = t
        setD(travelled)
        const a = along(route, travelled)
        onPos(a.pos, a.bearing)
      }
      if (travelled < total) raf.current = requestAnimationFrame(tick)
      else setTimeout(onArrive, 700)
    }
    raf.current = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf.current)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [route])

  // next maneuver = first step whose location lies ahead of us
  const stepDist = route.steps.map(s => {
    let best = 0, bi = 0
    route.coords.forEach((c, i) => { const q = -(Math.abs(c[0] - s.at[0]) + Math.abs(c[1] - s.at[1])); if (i === 0 || q > best) { best = q; bi = i } })
    return route.cum[bi]
  })
  let ni = stepDist.findIndex((sd, i) => i > 0 && sd > d + 0.01)
  if (ni < 0) ni = route.steps.length - 1
  const next = route.steps[ni], then = route.steps[ni + 1]
  const toNext = Math.max(0, (stepDist[ni] ?? total) - d)
  const remainKm = Math.max(0, total - d)
  const remainMin = Math.max(1, Math.round(route.min * remainKm / Math.max(total, 0.01)))
  const eta = new Date(Date.now() + remainMin * 60000)

  return (
    <>
      <div className="navbar">
        <ManeuverIcon type={next.type} modifier={next.modifier} />
        <div style={{ minWidth: 0 }}>
          <div className="dist">{toNext < 1 ? `${Math.round(toNext * 1000 / 10) * 10} m` : fmtKm(toNext)}</div>
          <div className="street" style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {next.type === 'arrive' ? r.v.s.name : next.name || 'Tęskite'}
          </div>
        </div>
        {then && (
          <div className="navbar-then">
            ir tada <ManeuverIcon type={then.type} modifier={then.modifier} size={22} />
          </div>
        )}
      </div>
      <div className="speedo" style={{ bottom: 120 }}><b>{d >= total ? 0 : speedKmh}</b><small>km/h</small></div>
      <div className="navfoot">
        <button className="circ" onClick={onStop}><Search size={24} /></button>
        <div className="mid">
          <b>{eta.toLocaleTimeString('lt-LT', { hour: '2-digit', minute: '2-digit' })}</b>
          <div>{remainMin} min • {fmtKm(remainKm)}</div>
        </div>
        <button className="circ" onClick={onStop}><Split size={24} style={{ transform: 'rotate(180deg)' }} /></button>
      </div>
    </>
  )
}
