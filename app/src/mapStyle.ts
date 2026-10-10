// OpenFreeMap "positron" recoloured to a Waze-like palette:
// mint parks, bright blue water, white roads with soft grey casings, grey labels.
import type { StyleSpecification, LayerSpecification } from 'maplibre-gl'

const C = {
  bg: '#f1f2ef',
  park: '#c2f0c6',
  wood: '#c9f2cc',
  residential: '#ececea',
  water: '#a7d8f3',
  building: '#e3e3e1',
  buildingLine: '#d5d5d3',
  casing: '#d6d6d6',
  road: '#ffffff',
  minor: '#ffffff',
  label: '#6b6b6b',
  waterLabel: '#3a8cc4',
}

export async function wazeStyle(): Promise<StyleSpecification> {
  const style: StyleSpecification = await fetch('https://tiles.openfreemap.org/styles/positron').then(r => r.json())
  const set = (l: LayerSpecification, k: string, v: unknown) => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    ;(l as any).paint = { ...((l as any).paint || {}), [k]: v }
  }
  for (const l of style.layers) {
    const id = l.id
    if (id === 'background') set(l, 'background-color', C.bg)
    else if (id === 'park') set(l, 'fill-color', C.park)
    else if (id === 'landcover_wood') { set(l, 'fill-color', C.wood); set(l, 'fill-opacity', 1) }
    else if (id === 'landuse_residential') set(l, 'fill-color', C.residential)
    else if (id === 'water') set(l, 'fill-color', C.water)
    else if (id === 'waterway') set(l, 'line-color', C.water)
    else if (id === 'building') { set(l, 'fill-color', C.building); set(l, 'fill-outline-color', C.buildingLine) }
    else if (id.endsWith('_casing')) set(l, 'line-color', C.casing)
    else if (id === 'highway_minor') { set(l, 'line-color', C.minor); set(l, 'line-opacity', 1) }
    else if (id.endsWith('_inner')) set(l, 'line-color', C.road)
    else if (id.startsWith('highway-name')) { set(l, 'text-color', C.label); set(l, 'text-halo-color', '#ffffff'); set(l, 'text-halo-width', 1.5) }
    else if (id.startsWith('water_name')) set(l, 'text-color', C.waterLabel)
    else if (id.startsWith('label_')) set(l, 'text-color', '#555')
  }
  // Waze draws minor streets white with a soft grey outline – positron has no casing for them
  const i = style.layers.findIndex(l => l.id === 'highway_minor')
  if (i >= 0) {
    const minor = style.layers[i] as LayerSpecification & { paint: Record<string, unknown> }
    const width = (a: number) => ['interpolate', ['exponential', 1.5], ['zoom'], 12, 0.6 * a, 14, 2.5 * a, 16, 7 * a, 18, 18 * a]
    const casing = { ...minor, id: 'highway_minor_casing', paint: { 'line-color': C.casing, 'line-width': width(1) } }
    minor.paint = { ...minor.paint, 'line-color': C.minor, 'line-width': width(0.75) }
    style.layers.splice(i, 0, casing as LayerSpecification)
  }
  return style
}
