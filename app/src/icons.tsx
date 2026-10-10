// Colour icons: Microsoft Fluent Emoji (flat, MIT). Line icons come from lucide-react.
const files = import.meta.glob('./assets/emoji/*.svg', { eager: true, query: '?url', import: 'default' }) as Record<string, string>
const url = (name: string) => files[`./assets/emoji/${name}_flat.svg`]

export type EmojiName =
  | 'house' | 'briefcase' | 'high_voltage' | 'electric_plug' | 'camera_with_flash' | 'warning'
  | 'automobile' | 'wrapped_gift' | 'trophy' | 'glowing_star' | 'hourglass_not_done' | 'check_mark_button'
  | 'battery' | 'no_entry' | 'hammer_and_wrench' | 'fuel_pump' | 'hot_beverage' | 'bell' | 'fire' | 'coin'
  | 'p_button' | 'stopwatch' | '1st_place_medal' | 'sparkles' | 'sport_utility_vehicle' | 'money_bag'
  | 'light_bulb' | 'party_popper' | 'handshake'

export function Emoji({ name, size = 24, style }: { name: EmojiName; size?: number; style?: React.CSSProperties }) {
  return <img src={url(name)} width={size} height={size} alt="" draggable={false} style={{ display: 'block', ...style }} />
}

/** Report button glyph: rounded warning triangle with a plus (drawn here, not a Waze asset). */
export function ReportGlyph({ size = 44 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill="none">
      <path d="M21.4 7.6a3 3 0 0 1 5.2 0l16.3 28.2A3 3 0 0 1 40.3 40H7.7a3 3 0 0 1-2.6-4.2L21.4 7.6Z"
        fill="#FFD60A" stroke="#1b1b1b" strokeWidth="3.4" strokeLinejoin="round" />
      <path d="M24 19v13M17.5 25.5h13" stroke="#1b1b1b" strokeWidth="3.6" strokeLinecap="round" />
    </svg>
  )
}

/** Our mascot "Kištukas" – a friendly plug. Original artwork. */
export function Mascot({ size = 96, mood = 'love' }: { size?: number; mood?: 'love' | 'happy' | 'sleepy' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 120 120">
      <path d="M44 14v16M76 14v16" stroke="#2b2b2b" strokeWidth="7" strokeLinecap="round" />
      <path d="M22 52c0-17 12-24 38-24s38 7 38 24v18c0 22-16 34-38 34S22 92 22 70V52Z" fill="#7BE0A6" stroke="#1b1b1b" strokeWidth="5" />
      <path d="M60 104c0 6 4 10 12 10" stroke="#1b1b1b" strokeWidth="5" strokeLinecap="round" fill="none" />
      {mood === 'love' ? (
        <>
          <path d="M41 50c-4-6-13-2-10 5l10 9 10-9c3-7-6-11-10-5Z" fill="#FF4D6D" stroke="#1b1b1b" strokeWidth="3" />
          <path d="M79 50c-4-6-13-2-10 5l10 9 10-9c3-7-6-11-10-5Z" fill="#FF4D6D" stroke="#1b1b1b" strokeWidth="3" />
        </>
      ) : mood === 'sleepy' ? (
        <>
          <path d="M33 57q8 6 16 0M71 57q8 6 16 0" stroke="#1b1b1b" strokeWidth="4" fill="none" strokeLinecap="round" />
        </>
      ) : (
        <>
          <circle cx="44" cy="56" r="6" fill="#1b1b1b" />
          <circle cx="76" cy="56" r="6" fill="#1b1b1b" />
        </>
      )}
      <path d="M48 76q12 10 24 0" stroke="#1b1b1b" strokeWidth="5" fill="none" strokeLinecap="round" />
      <circle cx="34" cy="72" r="5" fill="#FF9DB0" opacity=".7" />
      <circle cx="86" cy="72" r="5" fill="#FF9DB0" opacity=".7" />
    </svg>
  )
}
