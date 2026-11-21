<template>
  <div class="fx-layer">
    <div v-if="fx" :key="fx.id" class="fx-stage" :class="`fx-${fx.kind}`" :style="tint">
      <!-- Blade strokes -->
      <svg v-if="isBlade" class="fx-svg" viewBox="0 0 100 100">
        <path class="fx-stroke" d="M12 88 Q 40 52 90 10" />
        <path v-if="fx.kind === 'multi_slash'" class="fx-stroke fx-stroke-late" d="M10 14 Q 52 40 88 90" />
        <path v-if="fx.kind === 'cleave'" class="fx-stroke fx-stroke-wide" d="M4 62 Q 50 30 96 58" />
      </svg>

      <!-- Thrust -->
      <svg v-else-if="fx.kind === 'pierce'" class="fx-svg" viewBox="0 0 100 100">
        <line class="fx-thrust" x1="-20" y1="52" x2="62" y2="48" />
        <circle class="fx-ring" cx="62" cy="48" r="6" />
      </svg>

      <!-- Arrow -->
      <svg v-else-if="fx.kind === 'arrow'" class="fx-svg" viewBox="0 0 100 100">
        <g class="fx-arrow">
          <line x1="0" y1="50" x2="46" y2="50" stroke="#e7e5e4" stroke-width="2.5" />
          <path d="M46 44 L58 50 L46 56 Z" fill="#d6d3d1" />
          <path d="M0 50 L-6 44 M0 50 L-6 56 M5 50 L-1 44 M5 50 L-1 56" stroke="#b45309" stroke-width="2" />
        </g>
        <circle class="fx-ring" cx="56" cy="50" r="5" />
      </svg>

      <!-- Blunt impact -->
      <svg v-else-if="fx.kind === 'smash'" class="fx-svg" viewBox="0 0 100 100">
        <circle class="fx-ring fx-ring-big" cx="50" cy="50" r="10" />
        <g class="fx-star">
          <path v-for="a in 8" :key="a" :transform="`rotate(${a * 45} 50 50)`" d="M50 38 L53 22 L50 26 L47 22 Z" />
        </g>
      </svg>

      <!-- Enemy blow on the player -->
      <svg v-else-if="fx.kind === 'claw'" class="fx-svg" viewBox="0 0 100 100">
        <path v-for="(d, n) in CLAWS" :key="n" class="fx-claw" :style="{ animationDelay: `${n * 60}ms` }" :d="d" />
      </svg>

      <!-- Shield -->
      <svg v-else-if="fx.kind === 'shield'" class="fx-svg fx-shield" viewBox="0 0 100 100">
        <defs>
          <linearGradient :id="`shield-${fx.id}`" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stop-color="var(--fx-light)" stop-opacity="0.4" />
            <stop offset="1" stop-color="var(--fx-main)" stop-opacity="0.12" />
          </linearGradient>
        </defs>
        <path d="M50 10 L82 22 Q 82 62 50 90 Q 18 62 18 22 Z" :fill="`url(#shield-${fx.id})`"
          stroke="var(--fx-light)" stroke-width="2.5" />
        <path class="fx-shield-shine" d="M30 26 L44 20 L36 60 Z" fill="white" opacity="0.35" />
      </svg>

      <!-- Scan -->
      <template v-else-if="fx.kind === 'analyze'">
        <div class="fx-scan"></div>
        <div class="fx-brackets"></div>
      </template>

      <!-- Particle based effects (fire, water, shadow, light, nature, heal, mana, arcane, aura, explosion) -->
      <template v-else>
        <div class="fx-glow"></div>
        <div v-if="fx.kind === 'light'" class="fx-rays"></div>
        <span v-for="p in particles" :key="p.n" class="fx-p" :style="p.style"></span>
      </template>
    </div>

    <span v-for="f in floats" :key="f.id" class="fx-float" :class="`fx-float-${f.tone}`"
      :style="{ marginLeft: `${f.offset}px` }">{{ f.text }}</span>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  fx: { type: Object, default: null },
  floats: { type: Array, default: () => [] }
})

const CLAWS = ['M22 18 L48 86', 'M40 12 L66 82', 'M58 10 L82 74']

// [main, light] colors per effect, overridable by the spell element
const PALETTE = {
  fire: ['#ea580c', '#fde047'], explosion: ['#ea580c', '#fde047'],
  water: ['#0284c7', '#7dd3fc'], shadow: ['#581c87', '#a855f7'],
  light: ['#d97706', '#fef3c7'], nature: ['#15803d', '#86efac'],
  heal: ['#16a34a', '#fef08a'], mana: ['#1d4ed8', '#93c5fd'],
  arcane: ['#7e22ce', '#e9d5ff'], aura: ['#6b21a8', '#d8b4fe'],
  shield: ['#b45309', '#fcd34d']
}
const ELEMENT_PALETTE = {
  feu: PALETTE.fire, eau: PALETTE.water, ombre: PALETTE.shadow, lumiere: PALETTE.light, nature: PALETTE.nature
}

const isBlade = computed(() => ['slash', 'multi_slash', 'cleave'].includes(props.fx?.kind))

const tint = computed(() => {
  if (!props.fx) return {}
  const byElement = ['shield', 'aura', 'heal'].includes(props.fx.kind) && props.fx.element !== 'lumiere'
    ? ELEMENT_PALETTE[props.fx.element] : null
  const [main, light] = byElement || PALETTE[props.fx.kind] || PALETTE.arcane
  return { '--fx-main': main, '--fx-light': light }
})

const COUNT = { fire: 12, explosion: 14, water: 12, shadow: 8, light: 10, nature: 10, heal: 12, mana: 12, arcane: 10, aura: 10 }

// Random per effect instance (fx.id changes on every cast)
const particles = computed(() => {
  if (!props.fx) return []
  const n = COUNT[props.fx.kind] || 0
  return Array.from({ length: n }, (_, i) => {
    const angle = (i / n) * Math.PI * 2 + Math.random() * 0.6
    const dist = 28 + Math.random() * 26
    return {
      n: i,
      style: {
        left: `${15 + Math.random() * 70}%`,
        '--dx': `${Math.cos(angle) * dist}px`,
        '--dy': `${Math.sin(angle) * dist}px`,
        '--rise': `${-30 - Math.random() * 40}px`,
        '--drift': `${(Math.random() - 0.5) * 24}px`,
        '--s': (0.6 + Math.random() * 0.8).toFixed(2),
        '--rot': `${Math.round(Math.random() * 360)}deg`,
        animationDelay: `${Math.round(Math.random() * 220)}ms`
      }
    }
  })
})
</script>

<style scoped>
.fx-layer { position: absolute; inset: 0; pointer-events: none; z-index: 20; }
.fx-stage { position: absolute; inset: 0; }
.fx-svg { position: absolute; inset: -15%; width: 130%; height: 130%; overflow: visible; }

/* Blades */
.fx-stroke {
  fill: none; stroke: #fafaf9; stroke-width: 4; stroke-linecap: round;
  stroke-dasharray: 130; stroke-dashoffset: 130;
  filter: drop-shadow(0 0 3px #e0f2fe) drop-shadow(0 0 6px #38bdf8);
  animation: fx-draw 0.42s cubic-bezier(.2,.7,.3,1) forwards;
}
.fx-stroke-late { animation-delay: 0.16s; }
.fx-stroke-wide { stroke-width: 6; stroke: #fde68a; filter: drop-shadow(0 0 5px #f59e0b); }
.fx-cleave .fx-stroke { stroke-width: 6; }
@keyframes fx-draw {
  0% { stroke-dashoffset: 130; opacity: 1; }
  45% { stroke-dashoffset: 0; opacity: 1; }
  100% { stroke-dashoffset: -130; opacity: 0; }
}

/* Thrust & arrow */
.fx-thrust {
  stroke: #f5f5f4; stroke-width: 3; stroke-linecap: round;
  filter: drop-shadow(0 0 4px #bae6fd);
  stroke-dasharray: 90; stroke-dashoffset: 90;
  animation: fx-draw 0.38s ease-out forwards;
}
.fx-arrow { animation: fx-fly 0.28s cubic-bezier(.3,.6,.4,1) forwards; }
@keyframes fx-fly {
  0% { transform: translateX(-70px); opacity: 0.4; }
  85% { transform: translateX(0); opacity: 1; }
  100% { transform: translateX(0); opacity: 0; }
}
.fx-ring {
  fill: none; stroke: #fef3c7; stroke-width: 2; opacity: 0;
  transform-box: fill-box; transform-origin: center;
  animation: fx-ring 0.45s ease-out 0.22s forwards;
}
.fx-ring-big { stroke: #fbbf24; stroke-width: 4; animation-delay: 0.05s; }
@keyframes fx-ring {
  0% { transform: scale(0.4); opacity: 1; }
  100% { transform: scale(4); opacity: 0; }
}
.fx-star { fill: #fde68a; transform-origin: 50px 50px; animation: fx-pop 0.4s ease-out forwards; }
@keyframes fx-pop {
  0% { transform: scale(0.3); opacity: 0; }
  30% { transform: scale(1.1); opacity: 1; }
  100% { transform: scale(1.4); opacity: 0; }
}

/* Claws */
.fx-claw {
  fill: none; stroke: #ef4444; stroke-width: 4.5; stroke-linecap: round;
  filter: drop-shadow(0 0 4px #7f1d1d);
  stroke-dasharray: 90; stroke-dashoffset: 90;
  animation: fx-draw 0.4s ease-out forwards;
}

/* Shield */
.fx-shield { inset: 0; width: 100%; height: 100%; transform-origin: center; animation: fx-shield 1.1s ease-out forwards; filter: drop-shadow(0 0 8px var(--fx-main)); }
@keyframes fx-shield {
  0% { transform: scale(0.4); opacity: 0; }
  25% { transform: scale(1.08); opacity: 1; }
  40% { transform: scale(1); }
  75% { opacity: 1; }
  100% { transform: scale(1.05); opacity: 0; }
}
.fx-shield-shine { animation: fx-shine 1.1s ease-in-out forwards; }
@keyframes fx-shine { 0%, 30% { opacity: 0; } 50% { opacity: 0.5; } 100% { opacity: 0; } }

/* Scan */
.fx-scan {
  position: absolute; left: 0; right: 0; height: 18%;
  background: linear-gradient(to bottom, transparent, rgba(251,191,36,0.55), transparent);
  animation: fx-scan 0.9s ease-in-out forwards;
}
@keyframes fx-scan { 0% { top: -20%; opacity: 0; } 15% { opacity: 1; } 100% { top: 100%; opacity: 0; } }
.fx-brackets {
  position: absolute; inset: 8%;
  border: 2px solid rgba(251,191,36,0.85);
  clip-path: polygon(0 0, 30% 0, 30% 4%, 4% 4%, 4% 30%, 0 30%, 0 70%, 4% 70%, 4% 96%, 30% 96%, 30% 100%, 70% 100%, 70% 96%, 96% 96%, 96% 70%, 100% 70%, 100% 30%, 96% 30%, 96% 4%, 70% 4%, 70% 0, 100% 0, 100% 100%, 0 100%);
  animation: fx-fade 1s ease-out forwards;
}
@keyframes fx-fade { 0% { opacity: 0; transform: scale(1.15); } 25% { opacity: 1; transform: scale(1); } 100% { opacity: 0; } }

/* Glow behind particles */
.fx-glow {
  position: absolute; inset: -10%; border-radius: 9999px;
  background: radial-gradient(circle, var(--fx-light) 0%, var(--fx-main) 35%, transparent 70%);
  mix-blend-mode: screen; opacity: 0;
  animation: fx-glow 0.9s ease-out forwards;
}
@keyframes fx-glow { 0% { opacity: 0; transform: scale(0.5); } 30% { opacity: var(--fx-glow-peak, 0.5); } 100% { opacity: 0; transform: scale(1.2); } }
.fx-shadow .fx-glow { mix-blend-mode: normal; background: radial-gradient(circle, rgba(0,0,0,0.85) 0%, var(--fx-main) 45%, transparent 70%); }
.fx-heal .fx-glow, .fx-mana .fx-glow, .fx-aura .fx-glow {
  inset: 0; border-radius: 0.75rem;
  background: radial-gradient(ellipse at 50% 100%, var(--fx-light) 0%, var(--fx-main) 40%, transparent 75%);
  animation-duration: 1.1s;
  --fx-glow-peak: 0.35;
}

.fx-rays {
  position: absolute; inset: -30%; border-radius: 9999px;
  background: repeating-conic-gradient(from 0deg, rgba(254,243,199,0.8) 0deg 6deg, transparent 6deg 30deg);
  mask-image: radial-gradient(circle, black 15%, transparent 65%);
  -webkit-mask-image: radial-gradient(circle, black 15%, transparent 65%);
  mix-blend-mode: screen;
  animation: fx-rays 0.9s ease-out forwards;
}
@keyframes fx-rays { 0% { opacity: 0; transform: rotate(0) scale(0.5); } 30% { opacity: 1; } 100% { opacity: 0; transform: rotate(40deg) scale(1.2); } }

/* Particles */
.fx-p {
  position: absolute; width: 14px; height: 14px; opacity: 0;
  animation-duration: 0.85s; animation-timing-function: ease-out; animation-fill-mode: forwards;
}
/* Fire: flames rising from the bottom */
.fx-fire .fx-p, .fx-explosion .fx-p {
  bottom: 8%; width: 16px; height: 22px;
  border-radius: 50% 50% 45% 45% / 65% 65% 35% 35%;
  background: radial-gradient(ellipse at 50% 75%, #fef9c3 0%, #fbbf24 30%, #ea580c 65%, transparent 72%);
  filter: blur(0.4px);
  animation-name: fx-flame;
}
@keyframes fx-flame {
  0% { transform: translate(0, 0) scale(calc(var(--s) * 0.4)); opacity: 0; }
  20% { opacity: 1; }
  100% { transform: translate(var(--drift), var(--rise)) scale(var(--s)); opacity: 0; }
}
/* Explosion / water / arcane: burst outward from the centre */
.fx-explosion .fx-p, .fx-water .fx-p, .fx-arcane .fx-p {
  left: calc(50% - 7px) !important; top: calc(50% - 7px); bottom: auto;
  animation-name: fx-burst;
}
.fx-water .fx-p {
  width: 9px; height: 12px; border-radius: 50% 50% 50% 50% / 60% 60% 40% 40%;
  background: radial-gradient(circle at 40% 35%, #f0f9ff, #38bdf8 55%, #0369a1);
}
.fx-arcane .fx-p {
  width: 8px; height: 8px; border-radius: 9999px;
  background: var(--fx-light); box-shadow: 0 0 8px 2px var(--fx-main);
}
@keyframes fx-burst {
  0% { transform: translate(0, 0) scale(0.3); opacity: 0; }
  20% { opacity: 1; }
  100% { transform: translate(var(--dx), var(--dy)) scale(var(--s)); opacity: 0; }
}
/* Shadow: smoke puffs */
.fx-shadow .fx-p {
  top: 30%; width: 34px; height: 34px; border-radius: 9999px;
  background: radial-gradient(circle, rgba(88,28,135,0.85), rgba(10,10,10,0.6) 55%, transparent 70%);
  filter: blur(3px);
  animation-name: fx-smoke; animation-duration: 1s;
}
@keyframes fx-smoke {
  0% { transform: translate(0, 10px) scale(0.4) rotate(0); opacity: 0; }
  30% { opacity: 0.9; }
  100% { transform: translate(var(--drift), -20px) scale(calc(var(--s) * 1.6)) rotate(var(--rot)); opacity: 0; }
}
/* Light: sparkling stars */
.fx-light .fx-p {
  top: 45%; width: 10px; height: 10px;
  background: #fffbeb;
  clip-path: polygon(50% 0, 62% 38%, 100% 50%, 62% 62%, 50% 100%, 38% 62%, 0 50%, 38% 38%);
  filter: drop-shadow(0 0 4px #fbbf24);
  animation-name: fx-burst;
}
/* Nature: leaves swirling */
.fx-nature .fx-p {
  bottom: 10%; width: 12px; height: 7px;
  border-radius: 0 100% 0 100%;
  background: linear-gradient(135deg, #bbf7d0, #16a34a);
  animation-name: fx-leaf; animation-duration: 1s;
}
@keyframes fx-leaf {
  0% { transform: translate(0, 0) rotate(0) scale(0.5); opacity: 0; }
  20% { opacity: 1; }
  100% { transform: translate(calc(var(--drift) * 2), var(--rise)) rotate(calc(var(--rot) + 360deg)) scale(var(--s)); opacity: 0; }
}
/* Heal / mana / aura: soft motes rising */
.fx-heal .fx-p, .fx-mana .fx-p, .fx-aura .fx-p {
  bottom: 5%; width: 7px; height: 7px; border-radius: 9999px;
  background: var(--fx-light); box-shadow: 0 0 6px 2px var(--fx-main);
  animation-name: fx-flame; animation-duration: 1.1s;
}
.fx-heal .fx-p:nth-child(3n) {
  width: 11px; height: 11px; border-radius: 0; background: var(--fx-light);
  clip-path: polygon(38% 0, 62% 0, 62% 38%, 100% 38%, 100% 62%, 62% 62%, 62% 100%, 38% 100%, 38% 62%, 0 62%, 0 38%, 38% 38%);
}

/* Floating numbers */
.fx-float {
  position: absolute; left: 50%; top: 30%;
  transform: translateX(-50%);
  font-weight: 800; font-size: 1.05rem; white-space: nowrap;
  text-shadow: 0 1px 0 #000, 0 0 6px rgba(0,0,0,0.9);
  animation: fx-float 1.1s ease-out forwards;
}
.fx-float-damage { color: #fca5a5; font-size: 1.25rem; }
.fx-float-heal { color: #86efac; }
.fx-float-mana { color: #93c5fd; }
.fx-float-miss { color: #d6d3d1; font-style: italic; font-size: 0.9rem; }
@keyframes fx-float {
  0% { transform: translate(-50%, 6px) scale(0.6); opacity: 0; }
  15% { transform: translate(-50%, 0) scale(1.15); opacity: 1; }
  30% { transform: translate(-50%, -4px) scale(1); }
  100% { transform: translate(-50%, -34px); opacity: 0; }
}
</style>
