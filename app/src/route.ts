// Driving route via the public OSRM demo server; falls back to a straight line.
import { haversineKm } from './data'

export interface Step { at: [number, number]; dist: number; type: string; modifier?: string; name: string }
export interface Route { coords: [number, number][]; km: number; min: number; via: string; steps: Step[]; cum: number[] }

function cumulative(coords: [number, number][]) {
  const cum = [0]
  for (let i = 1; i < coords.length; i++) cum.push(cum[i - 1] + haversineKm(coords[i - 1], coords[i]))
  return cum
}

export async function getRoute(from: [number, number], to: [number, number]): Promise<Route> {
  try {
    const u = `https://router.project-osrm.org/route/v1/driving/${from[0]},${from[1]};${to[0]},${to[1]}?overview=full&geometries=geojson&steps=true`
    const r = await fetch(u, { signal: AbortSignal.timeout(6000) }).then(x => x.json())
    const rt = r.routes[0]
    const coords = rt.geometry.coordinates as [number, number][]
    const cum = cumulative(coords)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const steps: Step[] = rt.legs[0].steps.map((s: any) => ({
      at: s.maneuver.location, dist: s.distance, type: s.maneuver.type, modifier: s.maneuver.modifier, name: s.name || '',
    }))
    const names = [...new Set(steps.map(s => s.name).filter(Boolean))].slice(0, 3)
    // OSRM demo ignores traffic: add 25 % for city congestion
    return { coords, km: rt.distance / 1000, min: Math.round(rt.duration / 60 * 1.25) + 1, via: names.join(', '), steps, cum }
  } catch {
    const coords: [number, number][] = [from, to]
    const km = haversineKm(from, to) * 1.35
    return {
      coords, km, min: Math.round(km / 28 * 60) + 2, via: '', cum: cumulative(coords),
      steps: [{ at: to, dist: km * 1000, type: 'arrive', name: '' }],
    }
  }
}

/** Point + bearing at distance d (km) along the route. */
export function along(r: Route, d: number): { pos: [number, number]; bearing: number } {
  const { coords, cum } = r
  let i = cum.findIndex(c => c >= d)
  if (i <= 0) i = i === 0 ? 1 : coords.length - 1
  const a = coords[i - 1], b = coords[i]
  const seg = cum[i] - cum[i - 1] || 1e-9
  const t = Math.min(1, Math.max(0, (d - cum[i - 1]) / seg))
  const pos: [number, number] = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
  const y = Math.sin((b[0] - a[0]) * Math.PI / 180) * Math.cos(b[1] * Math.PI / 180)
  const x = Math.cos(a[1] * Math.PI / 180) * Math.sin(b[1] * Math.PI / 180) -
    Math.sin(a[1] * Math.PI / 180) * Math.cos(b[1] * Math.PI / 180) * Math.cos((b[0] - a[0]) * Math.PI / 180)
  return { pos, bearing: (Math.atan2(y, x) * 180 / Math.PI + 360) % 360 }
}
