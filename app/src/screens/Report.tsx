import { useEffect, useState } from 'react'
import { Camera, ChevronLeft, X } from 'lucide-react'
import { Emoji, type EmojiName } from '../icons'
import { fmtMin, type Reco } from '../data'

const TYPES: { k: string; label: string; icon: EmojiName; bg: string }[] = [
  { k: 'overstay', label: 'Užsistovėjęs', icon: 'hourglass_not_done', bg: '#FFE7C7' },
  { k: 'notplugged', label: 'Neprijungtas automobilis', icon: 'automobile', bg: '#FFD9D6' },
  { k: 'ice', label: 'Ne elektromobilis', icon: 'fuel_pump', bg: '#E6E0FF' },
  { k: 'broken', label: 'Neveikia', icon: 'hammer_and_wrench', bg: '#E4E7EB' },
  { k: 'blocked', label: 'Užstatyta', icon: 'no_entry', bg: '#FFD9D6' },
  { k: 'other', label: 'Kita', icon: 'warning', bg: '#FFF3BF' },
]

export default function Report({ r, onClose, onSubmitted }: { r: Reco | null; onClose: () => void; onSubmitted: (pts: number) => void }) {
  const [type, setType] = useState<string | null>(null)
  const [photo, setPhoto] = useState<string | null>(null)
  const [stage, setStage] = useState<'pick' | 'details' | 'verify'>('pick')
  const [checks, setChecks] = useState(0)

  const v = r?.v
  const worst = v?.chargers.filter(c => c.state === 'overstay' || c.state === 'busy').sort((a, b) => (b.elapsedMin ?? 0) - (a.elapsedMin ?? 0))[0]
  const dataConfirms =
    !!v && (type === 'overstay' ? !!v.chargers.find(c => c.state === 'overstay')
      : type === 'broken' ? v.chargers.some(c => c.state === 'broken')
        : type === 'notplugged' || type === 'ice' || type === 'blocked' ? v.free > 0 // spot reported "free" but physically taken
          : false)

  useEffect(() => {
    if (stage !== 'verify') return
    setChecks(0)
    const ts = [600, 1500, 2500].map((ms, i) => setTimeout(() => setChecks(i + 1), ms))
    return () => ts.forEach(clearTimeout)
  }, [stage])

  const pts = dataConfirms ? 30 : 15
  const typ = TYPES.find(t => t.k === type)

  return (
    <div className="sheet" style={{ maxHeight: '86%' }}>
      <div className="grabber" />
      <div className="scroll">
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          {stage === 'details' && <button onClick={() => setStage('pick')}><ChevronLeft size={28} /></button>}
          <div style={{ fontSize: 25, fontWeight: 800, flex: 1 }}>{stage === 'verify' ? 'Pranešimas išsiųstas' : 'Pranešti'}</div>
          <button onClick={onClose} style={{ width: 40, height: 40, borderRadius: 20, background: 'var(--field)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><X size={22} /></button>
        </div>
        {v && <div className="muted" style={{ marginTop: 4 }}>{v.s.name} · {v.s.addr}</div>}

        {stage === 'pick' && (
          <div className="report-grid">
            {TYPES.map(t => (
              <button key={t.k} className="report-tile" onClick={() => { setType(t.k); setStage('details') }}>
                <div className="disc" style={{ background: t.bg }}><Emoji name={t.icon} size={46} /></div>
                {t.label}
              </button>
            ))}
          </div>
        )}

        {stage === 'details' && typ && (
          <>
            <div className="pill-row"><span className="pill" style={{ background: typ.bg }}><Emoji name={typ.icon} size={18} />{typ.label}</span></div>
            <label className="photo-drop">
              {photo ? <img className="preview" src={photo} alt="" /> : <><Camera size={36} /><span>Nufotografuokite vietą</span><span style={{ fontSize: 13, fontWeight: 500 }}>Valstybinis numeris bus automatiškai paslėptas</span></>}
              <input type="file" accept="image/*" capture="environment" hidden
                onChange={e => { const f = e.target.files?.[0]; if (f) setPhoto(URL.createObjectURL(f)) }} />
            </label>
            {worst && type === 'overstay' && (
              <div className="insight" style={{ background: '#fff0dc' }}>
                <Emoji name="stopwatch" size={22} style={{ flex: 'none' }} />
                <div>Mūsų duomenimis, {Math.round(worst.kw)} kW jungtis užimta jau <b>{fmtMin(worst.elapsedMin ?? 0)}</b>.</div>
              </div>
            )}
          </>
        )}

        {stage === 'verify' && (
          <div style={{ marginTop: 12 }}>
            <div className={`check ${checks >= 1 ? 'done' : ''}`}>
              <Emoji name={dataConfirms ? 'check_mark_button' : 'light_bulb'} size={26} />
              <div><div className="t">{dataConfirms ? 'Patvirtinta realaus laiko duomenimis' : 'Duomenys to neparodo'}</div>
                <div className="s">{dataConfirms
                  ? type === 'overstay' && worst ? `Jungtis užimta ${fmtMin(worst.elapsedMin ?? 0)} – ${worst.dc ? 'DC sesija įprastai trunka ~35 min' : 'įkrovimas jau turėjo baigtis'}`
                    : type === 'broken' ? 'Operatorius jungtį irgi rodo kaip neveikiančią'
                      : 'Sistema vietą rodo kaip laisvą, nors ji fiziškai užimta – būtent tokių atvejų duomenys nemato'
                  : 'Pranešimą patvirtins kiti vairuotojai'}</div></div>
            </div>
            <div className={`check ${checks >= 2 ? 'done' : ''}`}>
              <Emoji name="handshake" size={26} />
              <div><div className="t">2 vairuotojai šalia patvirtino</div><div className="s">Prašymas patvirtinti išsiųstas netoliese esantiems EVFlow vartotojams</div></div>
            </div>
            <div className={`check ${checks >= 3 ? 'done' : ''}`}>
              <Emoji name="bell" size={26} />
              <div><div className="t">Perduota operatoriui</div><div className="s">{v?.s.op.replace(/,? ?UAB/, '') || 'Operatorius'} gavo pranešimą su nuotrauka ir laiku</div></div>
            </div>
          </div>
        )}
      </div>
      {stage === 'details' && (
        <div className="btns"><button className="btn primary" onClick={() => setStage('verify')}>Siųsti</button></div>
      )}
      {stage === 'verify' && (
        <div className="btns"><button className="btn primary" disabled={checks < 3} style={{ opacity: checks < 3 ? .5 : 1 }} onClick={() => onSubmitted(pts)}>
          Gauti +{pts} taškų</button></div>
      )}
    </div>
  )
}
