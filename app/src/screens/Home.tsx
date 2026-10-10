import { useState } from 'react'
import { Search, Mic, X, LocateFixed } from 'lucide-react'
import { Emoji, ReportGlyph } from '../icons'
import { fmtKm, fmtMin, pct, type Reco, type StationView } from '../data'
import { PIN_COLORS } from '../MapView'

export type Filter = 'fast' | 'all' | 'cheap'

interface Props {
  recos: Reco[]
  all: StationView[]
  filter: Filter
  setFilter: (f: Filter) => void
  onPick: (id: string) => void
  from: [number, number]
  onReport: () => void
  onRecenter: () => void
}

export function RecoRow({ r, onPick }: { r: Reco; onPick: (id: string) => void }) {
  const v = r.v
  const color = PIN_COLORS[v.pin]
  const status =
    v.free > 0 ? <span style={{ color: '#0f7a37', fontWeight: 700 }}>{v.free} laisv{v.free === 1 ? 'a' : 'os'}</span>
      : r.wait > 0 ? <span style={{ color: '#b4241b', fontWeight: 700 }}>~{fmtMin(r.wait)} laukti</span>
        : <span style={{ color: '#b35c00', fontWeight: 700 }}>{pct(r.pArrive)} atsilaisvins</span>
  return (
    <button className="row" onClick={() => onPick(v.s.id)}>
      <div className="ico">
        <div style={{ width: 34, height: 34, borderRadius: 17, background: color, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 0 0 2px #fff, 0 1px 4px rgba(0,0,0,.25)' }}>
          <svg width="16" height="18" viewBox="0 0 16 18"><path d="M9.5 0 1 10h5.5L4.5 18 15 7H9z" fill="#fff" /></svg>
        </div>
      </div>
      <div style={{ minWidth: 0, flex: 1 }}>
        <div className="t" style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{v.s.name}</div>
        <div className="s">{v.s.op.replace(/,? ?UAB/, '')} · {Math.round(v.maxKw)} kW · {v.priceText}</div>
        <div className="s">{status} · {fmtKm(r.km)}</div>
      </div>
      <div className="r">
        <div style={{ fontWeight: 800, fontSize: 19 }}>{r.drive + r.wait} min</div>
        <div className="s" style={{ fontSize: 13 }}>iki krovimo</div>
      </div>
    </button>
  )
}

export default function Home({ recos, all, filter, setFilter, onPick, onReport, onRecenter }: Props) {
  const [q, setQ] = useState('')
  const [full, setFull] = useState(false)
  const needle = q.trim().toLowerCase()
  const found = needle
    ? all.filter(v => `${v.s.name} ${v.s.addr} ${v.s.op} ${v.s.city}`.toLowerCase().includes(needle)).slice(0, 30)
    : []

  return (
    <div className={`sheet ${full ? 'full' : ''}`}>
      {!full && (
        <>
          <button className="fab round sm" style={{ top: -74, left: 20, background: '#55595e' }} onClick={onRecenter}>
            <LocateFixed size={28} color="#fff" />
          </button>
          <button className="fab report" style={{ top: -100, right: 20 }} onClick={onReport} aria-label="Pranešti">
            <ReportGlyph size={50} />
          </button>
        </>
      )}
      <div className="grabber" onClick={() => setFull(f => !f)} />
      <div className="pad">
        <div className="search" onClick={() => setFull(true)}>
          <Search size={26} strokeWidth={2.2} />
          <input placeholder="Kur krausime?" value={q} onChange={e => setQ(e.target.value)} />
          {full ? <X size={24} onClick={e => { e.stopPropagation(); setQ(''); setFull(false) }} /> : <Mic size={24} color="#1b1b1b" />}
        </div>
        {!needle && (
          <div className="chips">
            <button className={`chip ${filter === 'fast' ? 'on' : ''}`} onClick={() => setFilter('fast')}><Emoji name="high_voltage" size={28} />Greitas</button>
            <button className={`chip ${filter === 'all' ? 'on' : ''}`} onClick={() => setFilter('all')}><Emoji name="electric_plug" size={28} />Visi</button>
            <button className={`chip ${filter === 'cheap' ? 'on' : ''}`} onClick={() => setFilter('cheap')}><Emoji name="coin" size={28} />Pigiausi</button>
          </div>
        )}
      </div>
      <div className="scroll" style={{ maxHeight: full ? undefined : 300 }}>
        {needle ? (
          found.length ? found.map(v => (
            <button key={v.s.id} className="row" onClick={() => onPick(v.s.id)}>
              <div className="ico"><span className="dot" style={{ background: PIN_COLORS[v.pin], width: 14, height: 14, marginTop: 6 }} /></div>
              <div><div className="t">{v.s.name}</div><div className="s">{v.s.addr}, {v.s.city} · {v.free}/{v.total} laisvos</div></div>
            </button>
          )) : <div className="section-title">Nieko nerasta</div>
        ) : (
          <>
            <div className="section-title">Rekomenduojama dabar · mažiausiai laukti</div>
            {recos.map(r => <RecoRow key={r.v.s.id} r={r} onPick={onPick} />)}
          </>
        )}
      </div>
    </div>
  )
}
