// Driver's points / reputation. Kept in localStorage for the demo (wrapped – storage may be unavailable).
import { useCallback, useState } from 'react'

export interface Event { at: number; label: string; pts: number; kind: 'ontime' | 'late' | 'report' | 'redeem' }
export interface Game { points: number; onTime: number; late: number; reports: number; streak: number; events: Event[] }

const KEY = 'evflow.game.v1'
const SEED: Game = {
  points: 340, onTime: 11, late: 1, reports: 2, streak: 4,
  events: [
    { at: Date.now() - 86400e3 * 1, label: 'Laiku atlaisvinote vietą · Ozas', pts: 50, kind: 'ontime' },
    { at: Date.now() - 86400e3 * 2, label: 'Patvirtintas pranešimas · Akropolis', pts: 30, kind: 'report' },
    { at: Date.now() - 86400e3 * 4, label: 'Vėlavote 18 min · Panorama', pts: 0, kind: 'late' },
  ],
}

function read(): Game {
  try {
    const s = localStorage.getItem(KEY)
    if (s) return JSON.parse(s)
  } catch { /* storage blocked */ }
  return SEED
}

export function reputation(g: Game) {
  // Beta prior (4 on-time, 0 late) so newcomers start "good", not perfect
  const r = (g.onTime + 4) / (g.onTime + g.late + 4)
  const level = r >= 0.95 ? 'Pavyzdinis vairuotojas' : r >= 0.85 ? 'Patikimas vairuotojas' : r >= 0.7 ? 'Stengiasi' : 'Dažnai užsistovi'
  return { score: r, level, stars: Math.max(1, Math.round(r * 5 - 0.2)) }
}

export function useGame() {
  const [g, setG] = useState<Game>(read)
  const update = useCallback((f: (g: Game) => Game) => {
    setG(prev => {
      const n = f(prev)
      try { localStorage.setItem(KEY, JSON.stringify(n)) } catch { /* ignore */ }
      return n
    })
  }, [])
  const add = useCallback((e: Omit<Event, 'at'>) => update(g => ({
    ...g,
    points: Math.max(0, g.points + e.pts),
    onTime: g.onTime + (e.kind === 'ontime' ? 1 : 0),
    late: g.late + (e.kind === 'late' ? 1 : 0),
    reports: g.reports + (e.kind === 'report' ? 1 : 0),
    streak: e.kind === 'ontime' ? g.streak + 1 : e.kind === 'late' ? 0 : g.streak,
    events: [{ ...e, at: Date.now() }, ...g.events].slice(0, 30),
  })), [update])
  const reset = useCallback(() => update(() => SEED), [update])
  return { g, add, reset }
}
