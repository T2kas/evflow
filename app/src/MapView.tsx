import { useEffect, useRef } from 'react'
import maplibregl, { type GeoJSONSource, type Map as MLMap } from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { wazeStyle } from './mapStyle'
import type { StationView, PinState } from './data'

export const PIN_COLORS: Record<PinState, string> = {
  free: '#1DB954', busy: '#F0453A', overstay: '#FF8A00', broken: '#9AA0A6', stale: '#B9BEC4',
}

/** Round Waze-style POI pin with a white bolt, drawn to canvas so MapLibre can use it as an icon. */
function pinImage(color: string, ring = false) {
  const s = 2, w = 44 * s
  const c = document.createElement('canvas')
  c.width = c.height = w
  const g = c.getContext('2d')!
  g.shadowColor = 'rgba(0,0,0,.28)'; g.shadowBlur = 5 * s; g.shadowOffsetY = 1.5 * s
  g.beginPath(); g.arc(w / 2, w / 2, 16 * s, 0, Math.PI * 2); g.fillStyle = '#fff'; g.fill()
  g.shadowColor = 'transparent'
  g.beginPath(); g.arc(w / 2, w / 2, 13 * s, 0, Math.PI * 2); g.fillStyle = color; g.fill()
  if (ring) { g.lineWidth = 3 * s; g.strokeStyle = '#1b1b1b'; g.beginPath(); g.arc(w / 2, w / 2, 18.5 * s, 0, Math.PI * 2); g.stroke() }
  g.fillStyle = '#fff'
  g.beginPath()
  const o = w / 2, k = s
  g.moveTo(o + 2 * k, o - 9 * k); g.lineTo(o - 6 * k, o + 1.5 * k); g.lineTo(o - 0.5 * k, o + 1.5 * k)
  g.lineTo(o - 2.5 * k, o + 9 * k); g.lineTo(o + 6 * k, o - 2 * k); g.lineTo(o + 0.5 * k, o - 2 * k); g.closePath(); g.fill()
  return { width: w, height: w, data: new Uint8Array(g.getImageData(0, 0, w, w).data.buffer) }
}

interface Props {
  views: StationView[]
  user: [number, number]
  heading?: number
  selectedId?: string | null
  route?: [number, number][] | null
  mode: 'browse' | 'route' | 'nav'
  recenter?: number
  onSelect: (id: string) => void
}

export default function MapView({ views, user, heading = 0, selectedId, route, mode, recenter = 0, onSelect }: Props) {
  const el = useRef<HTMLDivElement>(null)
  const map = useRef<MLMap | null>(null)
  const ready = useRef(false)
  const pending = useRef<(() => void)[]>([])
  const whenReady = (fn: () => void) => (ready.current ? fn() : pending.current.push(fn))
  const userMarker = useRef<maplibregl.Marker | null>(null)
  const onSelectRef = useRef(onSelect)
  onSelectRef.current = onSelect

  useEffect(() => {
    let dead = false
    wazeStyle().then(style => {
      if (dead || !el.current) return
      const m = new maplibregl.Map({
        container: el.current, style, center: user, zoom: 13.6, attributionControl: false, pitchWithRotate: false,
      })
      map.current = m
      m.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-left')
      m.on('load', () => {
        for (const [k, col] of Object.entries(PIN_COLORS)) {
          m.addImage(`pin-${k}`, pinImage(col), { pixelRatio: 2 })
          m.addImage(`pin-${k}-sel`, pinImage(col, true), { pixelRatio: 2 })
        }
        m.addSource('route', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } })
        m.addLayer({ id: 'route-casing', type: 'line', source: 'route', layout: { 'line-cap': 'round', 'line-join': 'round' },
          paint: { 'line-color': '#4B1FA8', 'line-width': ['interpolate', ['linear'], ['zoom'], 10, 7, 16, 16] } })
        m.addLayer({ id: 'route-line', type: 'line', source: 'route', layout: { 'line-cap': 'round', 'line-join': 'round' },
          paint: { 'line-color': '#7B3FF2', 'line-width': ['interpolate', ['linear'], ['zoom'], 10, 4.5, 16, 11] } })
        m.addSource('stations', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } })
        m.addLayer({
          id: 'stations', type: 'symbol', source: 'stations',
          layout: {
            'icon-image': ['get', 'icon'], 'icon-allow-overlap': true, 'icon-ignore-placement': true,
            'icon-size': ['interpolate', ['linear'], ['zoom'], 9, 0.45, 12, 0.7, 15, 1],
            'symbol-sort-key': ['get', 'rank'],
            'text-field': ['step', ['zoom'], '', 13.5, ['get', 'label']],
            'text-font': ['Noto Sans Bold'], 'text-size': 11, 'text-offset': [0, 1.75], 'text-anchor': 'top',
            'text-optional': true,
          },
          paint: { 'text-color': '#1b1b1b', 'text-halo-color': '#fff', 'text-halo-width': 1.6 },
        })
        m.on('click', 'stations', e => {
          const f = e.features?.[0]
          if (f) onSelectRef.current(String(f.properties!.id))
        })
        m.on('mouseenter', 'stations', () => (m.getCanvas().style.cursor = 'pointer'))
        m.on('mouseleave', 'stations', () => (m.getCanvas().style.cursor = ''))
        ready.current = true
        pending.current.splice(0).forEach(fn => fn())
      })
      const dot = document.createElement('div')
      dot.className = 'user-puck'
      dot.innerHTML = '<div class="halo"></div><div class="arrow"></div>'
      userMarker.current = new maplibregl.Marker({ element: dot, rotationAlignment: 'map' }).setLngLat(user).addTo(m)
    })
    return () => { dead = true; map.current?.remove() }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // stations
  useEffect(() => {
    const apply = () => {
      const src = map.current?.getSource('stations') as GeoJSONSource | undefined
      if (!src) return
      src.setData({
        type: 'FeatureCollection',
        features: views.map(v => ({
          type: 'Feature',
          geometry: { type: 'Point', coordinates: [v.s.lon, v.s.lat] },
          properties: {
            id: v.s.id,
            icon: `pin-${v.pin}${v.s.id === selectedId ? '-sel' : ''}`,
            label: `${v.free}/${v.total}${v.dc ? ' ⚡' : ''}`,
            rank: v.s.id === selectedId ? 10 : v.pin === 'free' ? 5 : v.pin === 'overstay' ? 4 : 1,
          },
        })),
      })
    }
    whenReady(apply)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [views, selectedId])

  // route
  useEffect(() => {
    const apply = () => {
      const src = map.current?.getSource('route') as GeoJSONSource | undefined
      if (!src) return
      src.setData(route
        ? { type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: route } }
        : { type: 'FeatureCollection', features: [] })
      if (route && mode === 'route') {
        const b = route.reduce((bb, c) => bb.extend(c), new maplibregl.LngLatBounds(route[0], route[0]))
        map.current!.fitBounds(b, { padding: { top: 110, bottom: 330, left: 50, right: 50 }, duration: 800, pitch: 0, bearing: 0 })
      }
    }
    whenReady(apply)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [route, mode])

  // user + camera
  useEffect(() => {
    userMarker.current?.setLngLat(user).setRotation(heading)
    const m = map.current
    if (!m) return
    if (mode === 'nav') m.easeTo({ center: user, zoom: 16.6, pitch: 58, bearing: heading, duration: 900, padding: { top: 260, bottom: 0, left: 0, right: 0 } })
  }, [user, heading, mode])

  useEffect(() => {
    const m = map.current
    if (m && mode === 'browse') m.easeTo({ pitch: 0, bearing: 0, padding: { top: 0, bottom: 0, left: 0, right: 0 }, duration: 600 })
  }, [mode])

  useEffect(() => {
    if (recenter) map.current?.easeTo({ center: user, zoom: 14, bearing: 0, pitch: 0, padding: { top: 0, bottom: 0, left: 0, right: 0 }, duration: 700 })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [recenter])

  // fly to selection
  useEffect(() => {
    const v = views.find(x => x.s.id === selectedId)
    if (v && map.current && mode === 'browse')
      map.current.easeTo({ center: [v.s.lon, v.s.lat], zoom: Math.max(map.current.getZoom(), 14.5), padding: { bottom: 380, top: 0, left: 0, right: 0 }, duration: 700 })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId])

  return <div ref={el} className="map" />
}
