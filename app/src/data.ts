// Data model + scoring logic for the driver app.
// Input comes from analysis/build_app_data.py -> public/data/*.json

export type Status = 'Laisva' | 'Užimta' | 'Neveikia' | 'Nežinoma'
export type Cls = 'AC' | 'DC50' | 'DC100' | 'DC150'

export interface Plug {
  id: string; type: string; kw: number; dc: boolean; cls: Cls
  tariff: string; status: Status; since: string | null; censored: boolean
}
export interface Charger { id: string; plugs: Plug[] }
export interface StationStats {
  sessions: number; overstays: number; overstayShare: number; lostHoursPerDay: number; occupancy: number
}
export interface Station {
  id: string; name: string; op: string; addr: string; city: string
  lat: number; lon: number; restr: string; h24: boolean
  chargers: Charger[]; feedAgeMin: number | null; stats?: StationStats
}
export interface Meta { now: string; from_: string; hours: number; sessions: number; staleMin: number; dcRuleMin: number }
export interface ClassModel {
  n: number; p15: number[]; p30: number[]; remaining: number[]
  median: number; p90: number; overstay_after: number
}
export interface Model { step: number; max: number; classes: Record<Cls, ClassModel> }

export type ChargerState = 'free' | 'busy' | 'overstay' | 'broken' | 'unknown'
export type PinState = 'free' | 'busy' | 'overstay' | 'broken' | 'stale'

export interface ChargerView {
  id: string; state: ChargerState; kw: number; dc: boolean; cls: Cls
  types: string[]; tariff: string; elapsedMin: number | null; censored: boolean
  pFree15: number; pFree30: number; remainingMin: number | null; overstayMin: number
}
export interface StationView {
  s: Station; chargers: ChargerView[]; free: number; total: number
  maxKw: number; dc: boolean; pin: PinState; overstays: number; stale: boolean
  price: number | null; priceText: string
}

export async function loadData() {
  const [st, model] = await Promise.all([
    fetch('/data/stations.json').then(r => r.json()),
    fetch('/data/model.json').then(r => r.json()),
  ])
  return { meta: st.meta as Meta, stations: st.stations as Station[], model: model as Model }
}

// ---------- helpers
export const plugName = (t: string) =>
  t.includes('COMBO') ? 'CCS' : t.includes('CHADEMO') ? 'CHAdeMO' : t.includes('T2') ? 'Type 2' : t

export function parsePrice(t: string): number | null {
  const m = t.replace(',', '.').match(/([\d.]+)\s*€\s*\/\s*kWh/)
  return m ? parseFloat(m[1]) : null
}

export function haversineKm(a: [number, number], b: [number, number]) {
  const R = 6371, rad = Math.PI / 180
  const dLat = (b[1] - a[1]) * rad, dLon = (b[0] - a[0]) * rad
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(a[1] * rad) * Math.cos(b[1] * rad) * Math.sin(dLon / 2) ** 2
  return 2 * R * Math.asin(Math.sqrt(x))
}

/** City driving estimate: road factor 1.35, 28 km/h average, +2 min parking. */
export const driveMinutes = (km: number) => Math.round(km * 1.35 / 28 * 60 + 2)

function lookup(m: Model, cls: Cls, elapsed: number) {
  const c = m.classes[cls]
  const i = Math.min(c.p15.length - 1, Math.max(0, Math.floor(elapsed / m.step)))
  return { p15: c.p15[i], p30: c.p30[i], remaining: c.remaining[i] }
}

/** P(charger is free within t minutes) for an occupied charger. */
export function pFreeWithin(cv: ChargerView, t: number) {
  if (cv.state === 'free') return 1
  if (cv.state === 'broken' || cv.state === 'unknown') return 0
  if (t <= 15) return cv.pFree15 * (t / 15) ** 0.7
  if (t <= 30) return cv.pFree15 + (cv.pFree30 - cv.pFree15) * ((t - 15) / 15)
  return 1 - (1 - cv.pFree30) ** (t / 30)
}

export function viewStation(s: Station, now: number, model: Model): StationView {
  const chargers: ChargerView[] = s.chargers.map(ch => {
    const sts = ch.plugs.map(p => p.status)
    const best = ch.plugs.reduce((a, b) => (b.kw > a.kw ? b : a))
    const occ = ch.plugs.find(p => p.status === 'Užimta')
    let state: ChargerState =
      occ ? 'busy' : sts.includes('Laisva') ? 'free' : sts.every(x => x === 'Neveikia') ? 'broken' : 'unknown'
    let elapsed: number | null = null, p15 = 0, p30 = 0, remaining: number | null = null, overstayMin = 0
    if (occ) {
      elapsed = occ.since ? Math.max(0, (now - Date.parse(occ.since)) / 60000) : null
      const cls = occ.cls in model.classes ? occ.cls : best.cls
      const look = lookup(model, cls, elapsed ?? 0)
      p15 = look.p15; p30 = look.p30; remaining = look.remaining
      const limit = model.classes[cls].overstay_after
      if (elapsed != null && elapsed > limit) { state = 'overstay'; overstayMin = elapsed - limit }
    }
    return {
      id: ch.id, state, kw: best.kw, dc: best.dc, cls: best.cls,
      types: [...new Set(ch.plugs.map(p => plugName(p.type)))], tariff: best.tariff,
      elapsedMin: elapsed, censored: !!occ?.censored, pFree15: p15, pFree30: p30, remainingMin: remaining, overstayMin,
    }
  })
  const free = chargers.filter(c => c.state === 'free').length
  const busy = chargers.filter(c => c.state === 'busy' || c.state === 'overstay').length
  const overstays = chargers.filter(c => c.state === 'overstay').length
  const stale = s.feedAgeMin != null && s.feedAgeMin > 1440
  const pin: PinState = stale ? 'stale' : free > 0 ? 'free' : overstays > 0 ? 'overstay' : busy > 0 ? 'busy' : 'broken'
  const prices = chargers.map(c => parsePrice(c.tariff)).filter((x): x is number => x != null)
  const price = prices.length ? Math.min(...prices) : null
  return {
    s, chargers, free, total: chargers.length, overstays, stale,
    maxKw: Math.max(...chargers.map(c => c.kw)), dc: chargers.some(c => c.dc), pin,
    price, priceText: price != null ? `${price.toFixed(2)} €/kWh` : (chargers[0]?.tariff || '—'),
  }
}

export interface Reco {
  v: StationView; km: number; drive: number; pArrive: number; wait: number; score: number
}

/** Probability that at least one usable charger is free on arrival + expected wait. */
export function recommend(v: StationView, from: [number, number]): Reco {
  const km = haversineKm(from, [v.s.lon, v.s.lat])
  const drive = driveMinutes(km)
  const usable = v.chargers.filter(c => c.state !== 'broken' && c.state !== 'unknown')
  let pArrive = 0, wait = 0
  if (v.free > 0) {
    pArrive = 0.92 // someone may take it before we arrive
  } else if (usable.length) {
    pArrive = 1 - usable.reduce((acc, c) => acc * (1 - pFreeWithin(c, drive)), 1)
    const rem = usable.map(c => (c.remainingMin ?? 30)).sort((a, b) => a - b)[0]
    wait = Math.max(0, Math.round(rem - drive))
  }
  if (v.stale) pArrive *= 0.6
  const score = drive + wait * 1.2 + (1 - pArrive) * 15 + (v.s.restr ? 30 : 0)
  return { v, km, drive, pArrive, wait, score }
}

export const fmtMin = (m: number) => {
  m = Math.round(m)
  if (m < 60) return `${m} min`
  const h = Math.floor(m / 60), r = m % 60
  return r ? `${h} val. ${r} min` : `${h} val.`
}
export const fmtKm = (km: number) => (km < 1 ? `${Math.round(km * 1000)} m` : `${km.toFixed(1).replace('.', ',')} km`)
export const pct = (p: number) => `${Math.round(p * 100)} %`
