import { X, ChevronLeft, Zap, Gift, MessageSquareText, Settings, CircleHelp, RotateCcw } from 'lucide-react'
import { Emoji, Mascot, type EmojiName } from '../icons'
import { reputation, type Game } from '../store'
const ago = (ms: number) => {
  const m = Math.round(ms / 60000)
  return m < 60 ? `prieš ${m} min` : m < 1440 ? `prieš ${Math.round(m / 60)} val.` : `prieš ${Math.round(m / 1440)} d.`
}

export function Menu({ g, onClose, onProfile, onReset, dataNow }: { g: Game; onClose: () => void; onProfile: () => void; onReset: () => void; dataNow: string }) {
  return (
    <div className="screen">
      <button className="close" onClick={onClose}><X size={28} /></button>
      <div className="hello">
        <Mascot size={100} />
        <div>
          <h1>Labas, vairuotojau!</h1>
          <button className="soft-btn" onClick={onProfile}>Peržiūrėti profilį</button>
        </div>
      </div>
      <div style={{ paddingTop: 10 }}>
        <button className="menu-item" onClick={onProfile}><Zap size={26} />Mano krovimai</button>
        <button className="menu-item" onClick={onProfile}><Gift size={26} />Taškai ir prizai <span style={{ marginLeft: 'auto', fontWeight: 700, color: 'var(--purple)' }}>{g.points}</span></button>
        <button className="menu-item"><MessageSquareText size={26} />Pranešimai <span className="red-dot" /></button>
        <button className="menu-item"><Settings size={26} />Nustatymai</button>
        <button className="menu-item"><CircleHelp size={26} />Pagalba ir atsiliepimai</button>
        <button className="menu-item" onClick={onReset} style={{ color: 'var(--text-3)' }}><RotateCcw size={26} />Atstatyti demo</button>
      </div>
      <div className="version">EVFlow v0.1 · Via Lietuva duomenys {new Date(dataNow).toLocaleString('lt-LT', { dateStyle: 'short', timeStyle: 'short' })}</div>
    </div>
  )
}

const REWARDS: { icon: EmojiName; t: string; s: string; cost: number }[] = [
  { icon: 'high_voltage', t: '−20 % kitam įkrovimui', s: 'Partnerio operatoriaus stotelėse', cost: 300 },
  { icon: 'hot_beverage', t: 'Nemokama kava', s: 'Partnerių degalinėse ir kavinėse', cost: 150 },
  { icon: 'p_button', t: '1 val. nemokamo parkavimo', s: 'Miesto aikštelėse', cost: 400 },
  { icon: 'wrapped_gift', t: '10 kWh dovanų', s: 'Bet kuriame partnerio DC įkroviklyje', cost: 900 },
]

export function Profile({ g, onBack, onRedeem }: { g: Game; onBack: () => void; onRedeem: (cost: number, t: string) => void }) {
  const rep = reputation(g)
  return (
    <div className="screen">
      <button className="back" onClick={onBack}><ChevronLeft size={26} /> Atgal</button>
      <div style={{ display: 'flex', gap: 16, alignItems: 'center', marginTop: 18 }}>
        <Mascot size={74} mood="happy" />
        <div>
          <div style={{ fontSize: 26, fontWeight: 800 }}>Vairuotojas</div>
          <div style={{ display: 'flex', gap: 2, marginTop: 4 }}>
            {[1, 2, 3, 4, 5].map(i => <span key={i} style={{ opacity: i <= rep.stars ? 1 : .2 }}><Emoji name="glowing_star" size={20} /></span>)}
            <span className="muted" style={{ marginLeft: 8, fontWeight: 600 }}>{rep.level}</span>
          </div>
        </div>
      </div>

      <div className="points-hero">
        <div style={{ opacity: .85, fontWeight: 600 }}>Taškai</div>
        <div className="big">{g.points}</div>
        <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 8, fontWeight: 600 }}>
          <Emoji name="fire" size={20} /> {g.streak} kartus iš eilės atlaisvinote laiku
        </div>
        <div style={{ position: 'absolute', right: -6, bottom: -10, opacity: .95 }}><Emoji name="trophy" size={92} /></div>
      </div>

      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 700 }}>
          <span>Reputacija</span><span>{Math.round(rep.score * 100)} %</span>
        </div>
        <div className="bar" style={{ marginTop: 10 }}><div style={{ width: `${rep.score * 100}%`, background: rep.score > .85 ? 'var(--green)' : 'var(--orange)' }} /></div>
        <div className="muted" style={{ fontSize: 14, marginTop: 8 }}>Aukšta reputacija = prioritetas rezervuojant ir didesni prizai. Vėluojant ji krenta.</div>
        <div className="grid3">
          <div className="stat"><b>{g.onTime}</b><span>laiku</span></div>
          <div className="stat"><b>{g.late}</b><span>vėluota</span></div>
          <div className="stat"><b>{g.reports}</b><span>pranešimai</span></div>
        </div>
      </div>

      <div className="section-title" style={{ fontSize: 18, color: 'var(--text)', fontWeight: 800 }}>Prizai</div>
      {REWARDS.map(rw => (
        <div className="reward" key={rw.t}>
          <Emoji name={rw.icon} size={38} />
          <div><div style={{ fontWeight: 700, fontSize: 17 }}>{rw.t}</div><div className="muted" style={{ fontSize: 14 }}>{rw.s}</div></div>
          <button className={`cost ${g.points < rw.cost ? 'off' : ''}`} disabled={g.points < rw.cost} onClick={() => onRedeem(rw.cost, rw.t)}>{rw.cost} tšk.</button>
        </div>
      ))}

      <div className="section-title" style={{ fontSize: 18, color: 'var(--text)', fontWeight: 800 }}>Istorija</div>
      {g.events.map((e, i) => (
        <div className="reward" key={i}>
          <Emoji name={e.kind === 'ontime' ? 'check_mark_button' : e.kind === 'report' ? 'camera_with_flash' : e.kind === 'redeem' ? 'wrapped_gift' : 'hourglass_not_done'} size={30} />
          <div><div style={{ fontWeight: 600, fontSize: 16 }}>{e.label}</div><div className="muted" style={{ fontSize: 13 }}>{ago(Date.now() - e.at)}</div></div>
          <span className="cost" style={{ color: e.pts > 0 ? 'var(--green)' : e.pts < 0 ? 'var(--text-2)' : 'var(--orange)' }}>{e.pts > 0 ? `+${e.pts}` : e.pts === 0 ? '0' : e.pts}</span>
        </div>
      ))}
    </div>
  )
}
