import { reactive, ref } from 'vue'

// Visual effects for turn-based combat. The server only returns snapshots and
// log lines, so effects are inferred from the action the player picked and the
// HP difference between the snapshot before and after the turn.

const MAX_ENEMIES = 24
const IMPACT_MS = 260
const ENEMY_TURN_MS = 750
const ENEMY_STAGGER_MS = 260
const FX_LIFETIME_MS = 1200
const FLOAT_LIFETIME_MS = 1100

const ELEMENT_FX = { feu: 'fire', eau: 'water', ombre: 'shadow', lumiere: 'light', nature: 'nature' }

const WEAPON_FX = {
  epee: 'slash', dague: 'slash', rapiere: 'slash', hache: 'cleave',
  masse: 'smash', marteau: 'smash',
  lance: 'pierce', arme_d_hast: 'pierce',
  arc: 'arrow', arbalete: 'arrow', fronde: 'arrow'
}

function makeTarget() {
  return { fx: null, floats: [], shake: 0, lunge: 0 }
}

let uid = 0
const nextId = () => ++uid
const wait = ms => new Promise(resolve => window.setTimeout(resolve, ms))

export function useCombatFx() {
  const player = reactive(makeTarget())
  const enemies = reactive(Array.from({ length: MAX_ENEMIES }, makeTarget))
  // True while the turn is being animated: keeps the fight on screen after a
  // victory/defeat until the final blow has played.
  const playing = ref(false)

  function enemy(i) {
    return enemies[i] || enemies[MAX_ENEMIES - 1]
  }

  function later(ms, fn) {
    window.setTimeout(fn, ms)
  }

  function play(target, kind, { delay = 0, element = null } = {}) {
    later(delay, () => {
      const id = nextId()
      target.fx = { kind, element, id }
      later(FX_LIFETIME_MS, () => { if (target.fx?.id === id) target.fx = null })
    })
  }

  function float(target, text, tone, delay = 0) {
    later(delay, () => {
      const entry = { id: nextId(), text, tone, offset: Math.round((Math.random() - 0.5) * 30) }
      target.floats.push(entry)
      later(FLOAT_LIFETIME_MS, () => {
        const idx = target.floats.indexOf(entry)
        if (idx !== -1) target.floats.splice(idx, 1)
      })
    })
  }

  function bump(target, prop, delay = 0) {
    later(delay, () => { target[prop] = nextId() })
  }

  // Translates the chosen action into { kind, scope, element }.
  // scope: 'target' (single enemy), 'all' (every living enemy), 'self' (player)
  function describe(type, params, ctx) {
    const weaponKind = WEAPON_FX[ctx.weaponType] || (ctx.weaponType ? 'slash' : 'smash')

    if (type === 'attack') return { kind: weaponKind, scope: 'target' }
    if (type === 'analyze') return { kind: 'analyze', scope: 'target', silent: true }

    if (type === 'technique') {
      const tech = ctx.techniques.find(t => t.key === params.key) || {}
      switch (tech.type) {
        case 'multi_attack': return { kind: 'multi_slash', scope: 'target' }
        case 'aoe': return { kind: weaponKind === 'arrow' ? 'arrow' : 'cleave', scope: 'all' }
        case 'armor_pierce': return { kind: 'pierce', scope: 'target' }
        case 'execute': return { kind: 'smash', scope: 'target' }
        case 'stance': case 'counter': case 'combo': return { kind: 'shield', scope: 'self' }
        case 'heal': return { kind: 'heal', scope: 'self' }
        default: return { kind: weaponKind, scope: 'target' }
      }
    }

    if (type === 'magic') {
      const magic = ctx.magics.find(m => m.key === params.key) || {}
      const element = magic.element
      const elementKind = ELEMENT_FX[element] || 'arcane'
      switch (magic.type) {
        case 'damage_aoe': return { kind: elementKind, scope: 'all', element }
        case 'heal': case 'heal_cure': case 'cure': return { kind: 'heal', scope: 'self', element }
        case 'buff': return { kind: element === 'ombre' ? 'aura' : 'shield', scope: 'self', element }
        case 'drain': return { kind: 'shadow', scope: 'target', element, drain: true }
        case 'status': return { kind: elementKind, scope: 'target', element, silent: true }
        default: return { kind: elementKind, scope: 'target', element }
      }
    }

    if (type === 'item') {
      const item = ctx.items.find(i => i.id === params.item_id)
      const effect = item?.data?.effect_type || item?.data?.effect || ''
      if (effect === 'restore_mana' || effect === 'mana') return { kind: 'mana', scope: 'self' }
      if (effect.startsWith('damage')) return { kind: 'explosion', scope: 'target' }
      return { kind: 'heal', scope: 'self' }
    }

    return null
  }

  function hpMap(state) {
    return (state?.enemies || []).map(e => ({ hp: e.hp, alive: e.alive, name: e.name }))
  }

  // Runs the server call (request) then animates the turn. `playing` is raised
  // before the request so a final blow never flashes the end screen early.
  // Resolves once the animation is over.
  async function run(request, type, params, getState, ctx) {
    const before = JSON.parse(JSON.stringify(getState()))
    playing.value = true
    try {
      await request()
      await animate(type, params, before, getState(), ctx)
    } finally {
      playing.value = false
    }
  }

  async function animate(type, params, before, after, ctx) {
    if (!before || !after) return
    const desc = describe(type, params, ctx)
    const prev = hpMap(before)
    const next = hpMap(after)
    // End-of-fight snapshots return the last lines of the whole fight:
    // only keep the current turn.
    const fullLog = after.recent_log || []
    const turnStart = fullLog.map(l => l.startsWith('--- Tour')).lastIndexOf(true)
    const log = turnStart === -1 ? fullLog : fullLog.slice(turnStart)
    const missed = log.some(l => l.includes('raté'))
    let end = 0

    if (desc) {
      if (desc.scope === 'self') {
        play(player, desc.kind, { element: desc.element })
        end = IMPACT_MS
      } else {
        const livingBefore = prev.map((e, i) => (e.alive ? i : null)).filter(i => i !== null)
        let targets = prev.map((e, i) => (next[i] && next[i].hp < e.hp ? i : null)).filter(i => i !== null)
        if (desc.scope === 'all') targets = livingBefore
        else if (!targets.length) {
          const wanted = type === 'analyze' ? params.target : livingBefore[params.target || 0]
          targets = [wanted ?? livingBefore[0]].filter(i => i !== undefined)
        }

        targets.forEach((i, n) => {
          const delay = desc.scope === 'all' ? n * 90 : 0
          play(enemy(i), desc.kind, { delay, element: desc.element })
          const lost = prev[i].hp - (next[i]?.hp ?? prev[i].hp)
          if (lost > 0) {
            bump(enemy(i), 'shake', delay + IMPACT_MS)
            float(enemy(i), `-${lost}`, 'damage', delay + IMPACT_MS)
          } else if (!desc.silent && missed) {
            float(enemy(i), 'Raté', 'miss', delay + IMPACT_MS)
          }
        })
        end = IMPACT_MS + targets.length * 90
        if (desc.drain) play(player, 'heal', { delay: IMPACT_MS + 150, element: 'ombre' })
      }
    }

    // Player gains (heal / mana) read from the log
    const healed = log.map(l => l.match(/récupérez (\d+) PV|: \+(\d+) PV/)).find(Boolean)
    if (healed) float(player, `+${healed[1] || healed[2]}`, 'heal', IMPACT_MS)
    const mana = log.map(l => l.match(/récupérez (\d+) mana/)).find(Boolean)
    if (mana) float(player, `+${mana[1]} mana`, 'mana', IMPACT_MS)

    // Enemy turn: "X vous attaque / utilise / lance ..." lines lunge the attacker
    // and hit the player (claw for blows, arcane burst for spells).
    const names = new Set(next.map(e => e.name))
    const actions = log
      .map(line => ({ line, m: line.match(/^(.+?) (vous attaque|utilise|lance) /) }))
      .filter(a => a.m && names.has(a.m[1]))
    const used = new Set()
    actions.forEach(({ line, m }, n) => {
      const at = Math.max(end, ENEMY_TURN_MS) + n * ENEMY_STAGGER_MS
      const idx = next.findIndex((e, i) => !used.has(i) && e.name === m[1] && (e.alive || prev[i]?.alive))
      if (idx !== -1) used.add(idx)
      const attacker = idx !== -1 ? enemy(idx) : null

      const selfHeal = line.match(/récupère (\d+) PV/)
      if (selfHeal && attacker) {
        play(attacker, 'heal', { delay: at })
        float(attacker, `+${selfHeal[1]}`, 'heal', at + 150)
        end = at + 150
        return
      }

      if (attacker) bump(attacker, 'lunge', at)
      const spell = m[2] === 'lance'
      const hit = line.match(/: (\d+) dégâts/)
      if (hit) {
        play(player, spell ? 'arcane' : 'claw', { delay: at + 140 })
        bump(player, 'shake', at + 220)
        float(player, `-${hit[1]}`, 'damage', at + 220)
      } else if (line.includes('contre-attaquez')) {
        play(player, 'shield', { delay: at + 140 })
        float(player, 'Contre !', 'heal', at + 220)
      } else if (line.includes('paré !')) {
        play(player, 'shield', { delay: at + 140 })
        float(player, 'Paré -1', 'miss', at + 220)
      } else if (line.includes('raté')) {
        float(player, 'Esquive', 'miss', at + 220)
      } else if (spell) {
        play(player, 'arcane', { delay: at + 140 })
      }
      end = at + 220
    })

    const finished = after.status && after.status !== 'active'
    await wait(end + (finished ? 900 : 350))
  }

  return { player, enemy, playing, run }
}
