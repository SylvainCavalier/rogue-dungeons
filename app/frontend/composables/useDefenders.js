// Display helpers shared by the recruitment tab (guild) and the fortress page.
export function directionLabel(dir) {
  return { nord: 'Nord', sud: 'Sud', est: 'Est', ouest: 'Ouest' }[dir] || dir
}

// "18 PV", "Attaque 2D+1"… from the `stats` payload of DefenderService.
export function defenderStatParts(stats) {
  if (!stats) return []
  const parts = [`${stats.hp} PV`]
  if (stats.role === 'heal') {
    parts.push(`Soin ${stats.heal} / tour`)
  } else {
    parts.push(`Attaque ${stats.attack}`, `Dégâts ${stats.damage}`)
  }
  parts.push(`Esquive ${stats.esquive}`, `Résistance ${stats.resistance}`, `Attire ${stats.taunt}`)
  return parts
}
