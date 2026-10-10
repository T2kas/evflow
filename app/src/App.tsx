import { useCallback, useEffect, useMemo, useState } from 'react'
import { Menu as MenuIcon, Bell, Layers } from 'lucide-react'
import MapView from './MapView'
import { loadData, recommend, viewStation, type Meta, type Model, type Reco, type Station } from './data'
import { getRoute, type Route } from './route'
import { useGame } from './store'
import { Emoji, Mascot } from './icons'
import Home, { type Filter } from './screens/Home'
import StationSheet from './screens/StationSheet'
import { RoutePreview, Navigation } from './screens/Drive'
import Charging, { type Outcome } from './screens/Charging'
import Report from './screens/Report'
import { Menu, Profile } from './screens/Menu'

type Screen = 'home' | 'station' | 'route' | 'nav' | 'arrived' | 'charging' | 'report' | 'menu' | 'profile'

// Demo start: VILNIUS TECH, Saulėtekio al. (hackathon venue)
const START: [number, number] = [25.3373, 54.7225]
const inLithuania = (lon: number, lat: number) => lon > 20.9 && lon < 26.9 && lat > 53.8 && lat < 56.5

interface Celebration { title: string; text: string; pts: number; mood: 'love' | 'happy' | 'sleepy' }

export default function App() {
  const [data, setData] = useState<{ meta: Meta; stations: Station[]; model: Model } | null>(null)
  const [loadedAt] = useState(Date.now())
  const [tick, setTick] = useState(0)
  const [user, setUser] = useState<[number, number]>(START)
  const [heading, setHeading] = useState(0)
  const [screen, setScreen] = useState<Screen>('home')
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [filter, setFilter] = useState<Filter>('fast')
  const [route, setRoute] = useState<Route | null>(null)
  const [celebrate, setCelebrate] = useState<Celebration | null>(null)
  const [freeOnly, setFreeOnly] = useState(false)
  const [recenterKey, setRecenterKey] = useState(0)
  const { g, add, reset } = useGame()

  useEffect(() => { loadData().then(setData) }, [])
  useEffect(() => { const t = setInterval(() => setTick(x => x + 1), 30000); return () => clearInterval(t) }, [])
  useEffect(() => {
    navigator.geolocation?.getCurrentPosition(p => {
      if (inLithuania(p.coords.longitude, p.coords.latitude)) setUser([p.coords.longitude, p.coords.latitude])
    }, () => { /* keep demo location */ }, { timeout: 5000 })
  }, [])

  // "now" in data time: snapshot moment + time since the app opened
  const now = data ? Date.parse(data.meta.now) + (Date.now() - loadedAt) : 0

  const views = useMemo(
    () => (data ? data.stations.map(s => viewStation(s, now, data.model)) : []),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [data, tick],
  )
  const mapViews = useMemo(
    () => views.filter(v => (filter !== 'fast' || v.dc) && (!freeOnly || v.free > 0)),
    [views, filter, freeOnly],
  )

  const recos = useMemo(() => {
    const near = mapViews
      .filter(v => v.pin !== 'broken' && v.s.restr !== 'CUSTOMERS')
      .map(v => recommend(v, user))
      .filter(r => r.km < 12)
    if (filter === 'cheap') return near.filter(r => r.v.price != null && r.pArrive > 0.4).sort((a, b) => a.v.price! - b.v.price! || a.score - b.score).slice(0, 8)
    return near.sort((a, b) => a.score - b.score).slice(0, 8)
  }, [mapViews, user, filter])

  const selected: Reco | null = useMemo(() => {
    const v = views.find(x => x.s.id === selectedId)
    return v ? recommend(v, user) : null
  }, [views, selectedId, user])

  const pick = useCallback((id: string) => { setSelectedId(id); setScreen('station') }, [])

  const startRoute = async () => {
    if (!selected) return
    setRoute(null)
    setScreen('route')
    setRoute(await getRoute(user, [selected.v.s.lon, selected.v.s.lat]))
  }

  const finishCharging = (o: Outcome) => {
    const name = selected?.v.s.name ?? ''
    if (o.kind === 'ontime') {
      const bonus = g.streak >= 3 ? 10 : 0
      add({ kind: 'ontime', pts: 50 + bonus, label: `Laiku atlaisvinote vietą · ${name}` })
      setCelebrate({ title: 'Ačiū, kad atlaisvinote vietą!', text: bonus ? `+${bonus} už ${g.streak + 1} kartą iš eilės. Kitas vairuotojas jau gali krauti.` : 'Kitas vairuotojas jau gali krauti.', pts: 50 + bonus, mood: 'love' })
    } else {
      add({ kind: 'late', pts: 0, label: `Vėlavote ${o.lateMin} min · ${name}` })
      setCelebrate({ title: 'Šįkart pavėlavote', text: `Vieta buvo užimta ${o.lateMin} min per ilgai. Reputacija šiek tiek sumažėjo – kitą kartą pavyks!`, pts: 0, mood: 'sleepy' })
    }
    setScreen('home'); setRoute(null)
  }

  const mapMode = screen === 'nav' ? 'nav' : screen === 'route' ? 'route' : 'browse'
  const clock = new Date().toLocaleTimeString('lt-LT', { hour: '2-digit', minute: '2-digit' })
  const showMapChrome = screen === 'home' || screen === 'station'

  return (
    <div className="stage">
      <div className={`phone ${screen === 'nav' ? 'nav-mode' : ''}`}>
        <div className={`statusbar ${screen === 'nav' ? 'dark' : ''}`}>
          <span>{clock}</span><span className="island" />
          <span className="right">4G <span className="batt" /></span>
        </div>

        <MapView
          views={mapViews} user={user} heading={heading} selectedId={selectedId}
          route={route && (screen === 'route' || screen === 'nav') ? route.coords : null}
          mode={mapMode} recenter={recenterKey} onSelect={pick}
        />

        {!data && <div className="demo-tag" style={{ top: '45%' }}>Kraunami Via Lietuva duomenys…</div>}

        {showMapChrome && (
          <>
            <button className="fab square" style={{ top: 60, left: 22 }} onClick={() => setScreen('menu')} aria-label="Meniu">
              <MenuIcon size={32} strokeWidth={2.4} />
            </button>
            <button className="fab round sm" style={{ top: 142, left: 28 }} onClick={() => setRecenterKey(k => k + 1)} aria-label="Kompasas">
              <span className="compass" />
            </button>
            <button className="fab round" style={{ top: 60, right: 22 }} aria-label="Pranešimai">
              <Bell size={30} strokeWidth={2.3} /><span className="badge" />
            </button>
            <button className="fab round" style={{ top: 140, right: 22, background: freeOnly ? 'var(--blue)' : '#fff' }} onClick={() => setFreeOnly(x => !x)} aria-label="Tik laisvos">
              <Layers size={30} strokeWidth={2.3} color={freeOnly ? '#fff' : '#1b1b1b'} />
            </button>
          </>
        )}

        {screen === 'home' && data && (
          <Home recos={recos} all={views} filter={filter} setFilter={setFilter} onPick={pick} from={user}
            onReport={() => setScreen('report')} onRecenter={() => setRecenterKey(k => k + 1)} />
        )}
        {screen === 'station' && selected && (
          <StationSheet r={selected} onClose={() => { setSelectedId(null); setScreen('home') }} onGo={startRoute} onReport={() => setScreen('report')} />
        )}
        {screen === 'route' && selected && (
          <RoutePreview r={selected} route={route} onBack={() => setScreen('station')} onGo={() => setScreen('nav')} />
        )}
        {screen === 'nav' && selected && route && (
          <Navigation r={selected} route={route}
            onPos={(p, b) => { setUser(p); setHeading(b) }}
            onArrive={() => { setHeading(0); setScreen('arrived') }}
            onStop={() => { setHeading(0); setScreen('station') }} />
        )}
        {screen === 'arrived' && selected && (
          <div className="sheet">
            <div className="grabber" />
            <div className="pad">
              <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
                <Emoji name="party_popper" size={44} />
                <div><div style={{ fontSize: 25, fontWeight: 800 }}>Atvykote!</div><div className="muted">{selected.v.s.name}</div></div>
              </div>
              <div className="insight" style={{ marginTop: 16 }}>
                <Emoji name="electric_plug" size={22} style={{ flex: 'none' }} />
                <div>Pažymėkite „Kraunu čia“ – priminsime, kai baigsis krovimas, ir už laiku atlaisvintą vietą gausite taškų.</div>
              </div>
            </div>
            <div className="btns">
              <button className="btn secondary" onClick={() => setScreen('report')}>Užimta?</button>
              <button className="btn primary" onClick={() => setScreen('charging')}>Kraunu čia</button>
            </div>
          </div>
        )}
        {screen === 'charging' && selected && (
          <Charging r={selected} onDone={finishCharging} onCancel={() => setScreen('home')} />
        )}
        {screen === 'report' && (
          <Report r={selected ?? recos[0] ?? null} onClose={() => setScreen(selected ? 'station' : 'home')}
            onSubmitted={pts => {
              add({ kind: 'report', pts, label: `Pranešimas · ${(selected ?? recos[0])?.v.s.name ?? ''}` })
              setCelebrate({ title: 'Ačiū už pranešimą!', text: 'Jis patvirtintas ir perduotas operatoriui.', pts, mood: 'happy' })
              setScreen(selected ? 'station' : 'home')
            }} />
        )}
        {screen === 'menu' && data && (
          <Menu g={g} dataNow={data.meta.now} onClose={() => setScreen('home')} onProfile={() => setScreen('profile')} onReset={() => { reset(); setScreen('home') }} />
        )}
        {screen === 'profile' && (
          <Profile g={g} onBack={() => setScreen('menu')}
            onRedeem={(cost, t) => {
              add({ kind: 'redeem', pts: -cost, label: `Iškeista: ${t}` })
              setCelebrate({ title: 'Prizas jūsų!', text: `${t} – kodą rasite skiltyje „Pranešimai“.`, pts: -cost, mood: 'love' })
            }} />
        )}

        {celebrate && (
          <div className="celebrate" onClick={() => setCelebrate(null)}>
            <div className="box">
              <div style={{ display: 'flex', justifyContent: 'center' }}><Mascot size={110} mood={celebrate.mood} /></div>
              {celebrate.pts !== 0 && <div className="plus">{celebrate.pts > 0 ? `+${celebrate.pts}` : celebrate.pts}</div>}
              <h2>{celebrate.title}</h2>
              <div className="muted" style={{ lineHeight: 1.45 }}>{celebrate.text}</div>
              <button className="btn primary" style={{ marginTop: 20, width: '100%' }}>Puiku</button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
