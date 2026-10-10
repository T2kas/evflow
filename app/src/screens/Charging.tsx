import { useEffect, useState } from 'react'
import { Bell } from 'lucide-react'
import { Emoji, Mascot } from '../icons'
import { type Reco } from '../data'

// Demo clock: 1 real second = 1 simulated minute
const SPEED = 60

export type Outcome = { kind: 'ontime' | 'late'; lateMin: number; graceLeft: number }

export default function Charging({ r, onDone, onCancel }: { r: Reco; onDone: (o: Outcome) => void; onCancel: () => void }) {
  const best = r.v.chargers.find(c => c.state === 'free') ?? r.v.chargers[0]
  const dc = best.dc
  const plannedMin = dc ? 32 : 150 // typical session for the class (median from data)
  const grace = dc ? 10 : 30
  const [start] = useState(() => Date.now())
  const [now, setNow] = useState(Date.now())
  const [remind, setRemind] = useState(true)
  const [closedToast, setClosedToast] = useState(false)

  useEffect(() => { const t = setInterval(() => setNow(Date.now()), 250); return () => clearInterval(t) }, [])

  const simMin = (now - start) / 1000 * (SPEED / 60) * (dc ? 1 : 4) // AC demo runs 4x faster still
  const done = simMin >= plannedMin
  const sinceDone = Math.max(0, simMin - plannedMin)
  const graceLeft = Math.max(0, grace - sinceDone)
  const late = sinceDone > grace
  const progress = Math.min(1, simMin / plannedMin)
  const soc = Math.round(18 + progress * (80 - 18))
  const kwh = (progress * 52).toFixed(1).replace('.', ',')
  const endAt = new Date(start + plannedMin * 60000)

  const R = 46, C = 2 * Math.PI * R
  return (
    <>
      {done && remind && !closedToast && (
        <div className="toast" onClick={() => setClosedToast(true)}>
          <div className="app"><Mascot size={30} mood="happy" /></div>
          <div>
            <b>EVFlow · {late ? 'Vieta užimta per ilgai' : 'Krovimas baigtas ⚡'}</b>
            <p>{late
              ? `Jūs stovite jau ${Math.round(sinceDone)} min po įkrovimo. Kitas vairuotojas laukia.`
              : `Patraukite automobilį per ${Math.ceil(graceLeft)} min ir gausite +50 taškų.`}</p>
          </div>
        </div>
      )}
      <div className="demo-tag">Demo laikas: 1 s = {dc ? 1 : 4} min</div>
      <div className="sheet">
        <div className="grabber" />
        <div className="pad">
          <div style={{ fontSize: 15, color: 'var(--text-2)', fontWeight: 600 }}>{r.v.s.name} · {Math.round(best.kw)} kW</div>
          <div className="ring-wrap">
            <svg width="112" height="112" viewBox="0 0 112 112">
              <circle cx="56" cy="56" r={R} stroke="#eef0f2" strokeWidth="11" fill="none" />
              <circle cx="56" cy="56" r={R} stroke={late ? 'var(--orange)' : 'var(--green)'} strokeWidth="11" fill="none" strokeLinecap="round"
                strokeDasharray={C} strokeDashoffset={C * (1 - progress)} transform="rotate(-90 56 56)" style={{ transition: 'stroke-dashoffset .25s linear' }} />
              <text x="56" y="62" textAnchor="middle" fontSize="22" fontWeight="800" fill="#1b1b1b">{soc}%</text>
            </svg>
            <div>
              <div className="n">{done ? (late ? 'Užsistovėjote' : 'Įkrauta!') : `${Math.round(simMin)} min`}</div>
              <div className="muted" style={{ fontSize: 16, marginTop: 4, lineHeight: 1.4 }}>
                {done
                  ? late ? `Vieta užimta ${Math.round(sinceDone - grace)} min per ilgai` : <>Nemokamas laikas: <b style={{ color: 'var(--text)' }}>{Math.ceil(graceLeft)} min</b></>
                  : <>{kwh} kWh · baigsite ~{endAt.toLocaleTimeString('lt-LT', { hour: '2-digit', minute: '2-digit' })}</>}
              </div>
            </div>
          </div>

          <div className="row" style={{ alignItems: 'center', borderBottom: 0, paddingBottom: 6 }}>
            <Bell size={22} />
            <div style={{ flex: 1, fontSize: 17, fontWeight: 600 }}>Priminti, kai baigsis krovimas</div>
            <button onClick={() => setRemind(x => !x)} style={{ width: 52, height: 32, borderRadius: 16, background: remind ? 'var(--green)' : '#d0d3d7', position: 'relative', transition: 'background .2s' }}>
              <span style={{ position: 'absolute', top: 3, left: remind ? 23 : 3, width: 26, height: 26, borderRadius: 13, background: '#fff', boxShadow: '0 1px 3px rgba(0,0,0,.3)', transition: 'left .2s' }} />
            </button>
          </div>
          <div className="insight" style={{ marginTop: 6 }}>
            <Emoji name="coin" size={22} style={{ flex: 'none' }} />
            <div>Atlaisvinkite vietą per {grace} min po įkrovimo – gausite <b>+50 taškų</b>, o jūsų reputacija kils.</div>
          </div>
        </div>
        <div className="btns">
          {!done && <button className="btn secondary" onClick={onCancel}>Atšaukti</button>}
          <button className={`btn ${done ? 'primary' : 'secondary'}`}
            onClick={() => onDone({ kind: late ? 'late' : 'ontime', lateMin: Math.round(Math.max(0, sinceDone - grace)), graceLeft })}>
            {done ? 'Atlaisvinau vietą' : 'Baigiau anksčiau'}
          </button>
        </div>
      </div>
    </>
  )
}
