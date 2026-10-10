import { Camera, Clock3, X } from 'lucide-react'
import { Emoji } from '../icons'
import { fmtKm, fmtMin, pct, pFreeWithin, type ChargerView, type Reco } from '../data'
import { PIN_COLORS } from '../MapView'

const STATE_COLOR = { free: PIN_COLORS.free, busy: PIN_COLORS.busy, overstay: PIN_COLORS.overstay, broken: PIN_COLORS.broken, unknown: PIN_COLORS.stale }

function chargerLine(c: ChargerView) {
  switch (c.state) {
    case 'free': return <span style={{ color: '#0f7a37', fontWeight: 700 }}>Laisva</span>
    case 'busy': return <span>Kraunama {c.elapsedMin != null ? fmtMin(c.elapsedMin) : ''}{c.censored ? '+' : ''} · <b>{pct(c.pFree15)}</b> atsilaisvins per 15 min</span>
    case 'overstay': return <span style={{ color: '#b35c00', fontWeight: 700 }}>Užsistovėjęs: užimta {fmtMin(c.elapsedMin ?? 0)} ({c.dc ? 'DC įprastai iki 60 min' : 'įkrovimas jau turėjo baigtis'})</span>
    case 'broken': return <span className="muted">Neveikia</span>
    default: return <span className="muted">Būsena nežinoma</span>
  }
}

interface Props { r: Reco; onClose: () => void; onGo: () => void; onReport: () => void }

export default function StationSheet({ r, onClose, onGo, onReport }: Props) {
  const v = r.v
  const usable = v.chargers.filter(c => c.state !== 'broken' && c.state !== 'unknown')
  const p15 = 1 - usable.reduce((a, c) => a * (1 - pFreeWithin(c, 15)), 1)
  const types = [...new Set(v.chargers.flatMap(c => c.types))]

  let hero
  if (v.free > 0) {
    hero = (
      <div className="big-status" style={{ background: '#e3f7ea' }}>
        <Emoji name="check_mark_button" size={40} />
        <div><div className="n" style={{ color: '#0f7a37' }}>{v.free} iš {v.total} laisvos</div>
          <div className="d">Atvažiuosite per {r.drive} min · tikimybė rasti laisvą {pct(r.pArrive)}</div></div>
      </div>
    )
  } else if (usable.length) {
    hero = (
      <div className="big-status" style={{ background: v.overstays ? '#fff0dc' : '#fde7e5' }}>
        <Emoji name="hourglass_not_done" size={40} />
        <div><div className="n" style={{ color: v.overstays ? '#b35c00' : '#b4241b' }}>Visos užimtos</div>
          <div className="d"><b>{pct(p15)}</b> tikimybė, kad atsilaisvins per 15 min · atvykus <b>{pct(r.pArrive)}</b>
            {r.wait > 0 && <> · laukti ~{fmtMin(r.wait)}</>}</div></div>
      </div>
    )
  } else {
    hero = (
      <div className="big-status" style={{ background: '#f1f2f4' }}>
        <Emoji name="hammer_and_wrench" size={40} />
        <div><div className="n">Neveikia</div><div className="d">Šiuo metu įkrauti nepavyks</div></div>
      </div>
    )
  }

  return (
    <div className="sheet" style={{ maxHeight: '72%' }}>
      <div className="grabber" />
      <div className="scroll">
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 25, fontWeight: 800, lineHeight: 1.15 }}>{v.s.name}</div>
            <div className="muted" style={{ marginTop: 6, fontSize: 16 }}>{v.s.addr}{v.s.city ? `, ${v.s.city}` : ''} · {fmtKm(r.km)}</div>
          </div>
          <button onClick={onClose} style={{ width: 40, height: 40, borderRadius: 20, background: 'var(--field)', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' }}><X size={22} /></button>
        </div>
        <div className="pill-row">
          <span className="pill">{v.s.op.replace(/,? ?UAB/, '')}</span>
          <span className="pill">⚡ iki {Math.round(v.maxKw)} kW</span>
          <span className="pill">{types.join(' · ')}</span>
          <span className="pill">{v.priceText}</span>
          {v.s.restr === 'CUSTOMERS' && <span className="pill orange">Tik klientams</span>}
          {v.s.restr === 'DISABLED' && <span className="pill grey">♿ Neįgaliųjų vieta</span>}
        </div>

        {hero}

        {v.stale && (
          <div className="insight" style={{ background: '#f1f2f4' }}>
            <Clock3 size={20} style={{ flex: 'none', marginTop: 1 }} />
            <div>Operatorius duomenis atnaujino prieš {fmtMin(v.s.feedAgeMin ?? 0)} – būsena gali būti netiksli.</div>
          </div>
        )}

        <div className="section-title">Įkrovikliai</div>
        {v.chargers.map(c => (
          <div key={c.id} className="row" style={{ padding: '14px 0', alignItems: 'center' }}>
            <span className="dot" style={{ background: STATE_COLOR[c.state] }} />
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 700, fontSize: 17 }}>{Math.round(c.kw)} kW · {c.types.join(' / ')}</div>
              <div className="s" style={{ fontSize: 14.5 }}>{chargerLine(c)}</div>
            </div>
          </div>
        ))}

        {v.s.stats && v.s.stats.sessions >= 5 && (
          <div className="insight">
            <Emoji name="light_bulb" size={22} style={{ flex: 'none' }} />
            <div>
              Per pastarąsias dienas čia {pct(v.s.stats.overstayShare)} sesijų užsitęsė ilgiau nei reikia įkrovimui
              {v.s.stats.lostHoursPerDay >= 0.3 && <> – prarandama ~{String(v.s.stats.lostHoursPerDay).replace('.', ',')} val. per parą</>}.
            </div>
          </div>
        )}
        <div className="spacer" />
      </div>
      <div className="btns">
        <button className="btn secondary" onClick={onReport}><Camera size={22} /> Pranešti</button>
        <button className="btn primary" onClick={onGo}>Važiuojam</button>
      </div>
    </div>
  )
}
