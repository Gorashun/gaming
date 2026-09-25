/**
 * Förmågor (DESIGN §14.5, UI.md §13.8). Ren logik, ingen Phaser: tar `ability.key` + parametrarna
 * för aktuell nivå ur `avatars.ts` och räknar ut overrides som scenen skickar vidare till
 * befintliga system (regissören, fara, near-miss, samlarbok, juice, ljud). Håller rundans räknare.
 *
 * Regel: en förmåga ger ALDRIG poäng direkt. Inget här rör poängtabellen (data/levels.ts).
 */
import { avatarById, type AbilityParams } from '../data/avatarsIndex';
import { ABILITY_FX } from '../data/abilities';
import type { SeedEntry } from './director';

export type AbilityLevel = 1 | 2 | 3;

const LEVEL_KEY = ['I', 'II', 'III'] as const;

/** Parametrarna för figurens förmåga på nivån, eller null (vanlig/ovanlig, okänd figur). */
export function abilityParams(id: string, level: AbilityLevel): { key: string; p: AbilityParams } | null {
  const a = avatarById(id)?.ability;
  if (!a) return null;
  return { key: a.key, p: a.params[LEVEL_KEY[level - 1]] };
}

const num = (p: AbilityParams, k: string, d = 0): number => (typeof p[k] === 'number' ? (p[k] as number) : d);
const bool = (p: AbilityParams, k: string): boolean => p[k] === true;

/** Statiska overrides för rundan. Allt har neutralt värde när förmågan saknas. */
export interface AbilityOverrides {
  /** Förmågans nyckel, '' om ingen. */
  key: string;
  /** director.setSeedQueue: Rut, Havsdrottningen. */
  seedQueue: SeedEntry[];
  /** Near-miss från lägre nivå (Kajsa), annars null = standard. */
  nearMissMinLevel: number | null;
  /** Skimrande-chansen × (Stjärnvalen). */
  shinyMul: number;
  /** Antal objekt i förhandsvisningen (Siri: 2). */
  peekSteps: number;
  /** Shake × vid kedja (Muller). Taket i juice gäller alltid. */
  chainShakeMul: number;
  /** Rundans första N drop har restitution 0 (Bubbel). */
  noBounceDrops: number;
  /** Havsdrottningen: guldburk och stråklager. */
  goldJar: boolean;
  orchestra: boolean;
  /** Stjärnvalen: stjärnhimmel och extra glow på objekten. */
  starSky: boolean;
  glowBonus: number;
}

export function neutralOverrides(): AbilityOverrides {
  return {
    key: '',
    seedQueue: [],
    nearMissMinLevel: null,
    shinyMul: 1,
    peekSteps: 1,
    chainShakeMul: 1,
    noBounceDrops: 0,
    goldJar: false,
    orchestra: false,
    starSky: false,
    glowBonus: 0,
  };
}

/** Mappar förmåga + nivå till overrides (DESIGN §14.5). */
export function overridesFor(id: string, level: AbilityLevel): AbilityOverrides {
  const o = neutralOverrides();
  const a = abilityParams(id, level);
  if (!a) return o;
  const p = a.p;
  o.key = a.key;
  switch (a.key) {
    case 'thunderChain':
      o.chainShakeMul = num(p, 'shakeMul', 1);
      break;
    case 'nearMissFrom':
      o.nearMissMinLevel = num(p, 'minLevel');
      break;
    case 'starWhale':
      o.shinyMul = num(p, 'shinyMul', 1);
      o.starSky = bool(p, 'starSky');
      o.glowBonus = num(p, 'glowBonus');
      break;
    case 'queuePeek':
      o.peekSteps = num(p, 'steps', 2);
      break;
    case 'noBounceStart':
      o.noBounceDrops = num(p, 'drops');
      break;
    case 'startRainbow':
      o.seedQueue.push({ atDrop: num(p, 'rainbowAtDrop'), type: 'rainbow' });
      if (bool(p, 'bomb')) o.seedQueue.push({ atDrop: num(p, 'bombAtDrop'), type: 'bomb' });
      break;
    case 'queenRound': {
      const q = ABILITY_FX.queen;
      if (bool(p, 'rainbow')) o.seedQueue.push({ atDrop: q.rainbowAtDrop, type: 'rainbow' });
      const n = Math.min(num(p, 'extraSpecials'), q.extraAtDrops.length);
      for (let i = 0; i < n; i++) o.seedQueue.push({ atDrop: q.extraAtDrops[i], type: null });
      o.goldJar = bool(p, 'goldJar');
      o.orchestra = bool(p, 'orchestra');
      break;
    }
  }
  return o;
}

/**
 * Förmågan under en runda: overrides + räknare "per runda" (Lisas olja, Majas och Valas
 * användningar, Bubbels drop). Inga allokeringar efter skapandet.
 */
export class Abilities {
  readonly id: string;
  readonly level: AbilityLevel;
  readonly key: string;
  readonly p: AbilityParams;
  readonly o: AbilityOverrides;

  /** Lisa: kvarvarande siktning (ms) och om lyktan lyser just nu. */
  lisaOilMs = 0;
  lisaActive = false;
  /** Maja: kvarvarande drag. */
  magnetLeft = 0;
  /** Vala: kvarvarande andetag, om ett andetag pågår och vilken gräns som gäller. */
  breathLeft = 0;
  breathing = false;
  graceMs = 0;
  /** Bubbel: kvarvarande drop utan studs. */
  noBounceLeft = 0;

  private readonly baseGraceMs: number;

  constructor(id: string, level: AbilityLevel, baseGraceMs: number) {
    this.id = id;
    this.level = level;
    const a = abilityParams(id, level);
    this.key = a?.key ?? '';
    this.p = a?.p ?? {};
    this.o = overridesFor(id, level);
    this.baseGraceMs = baseGraceMs;
    this.resetRound();
  }

  param(k: string, d = 0): number {
    return num(this.p, k, d);
  }

  flag(k: string): boolean {
    return bool(this.p, k);
  }

  /** Ny runda: alla "per runda"-räknare fylls på. */
  resetRound(): void {
    this.lisaOilMs = this.key === 'sameLevelGlow' ? this.param('seconds') * 1000 : 0;
    this.lisaActive = false;
    this.magnetLeft = this.key === 'magnetPull' ? this.param('uses') : 0;
    this.breathLeft = this.key === 'breath' ? this.param('uses') : 0;
    this.breathing = false;
    this.graceMs = this.baseGraceMs;
    this.noBounceLeft = this.o.noBounceDrops;
  }

  /** Lisa: anropas varje frame. Lyktan lyser medan man siktar och oljan räcker. */
  tickAim(dtMs: number, aiming: boolean): boolean {
    if (this.key !== 'sameLevelGlow') return false;
    this.lisaActive = aiming && this.lisaOilMs > 0;
    if (this.lisaActive) this.lisaOilMs = Math.max(0, this.lisaOilMs - dtMs);
    return this.lisaActive;
  }

  /** Bubbel: true om detta drop ska landa utan studs (räknar ner). */
  takeNoBounce(): boolean {
    if (this.noBounceLeft <= 0) return false;
    this.noBounceLeft--;
    return true;
  }

  /** Maja: förbrukar ett drag om det finns. Aldrig under fara. */
  tryMagnet(danger: boolean): boolean {
    if (this.key !== 'magnetPull' || danger || this.magnetLeft <= 0) return false;
    this.magnetLeft--;
    return true;
  }

  /**
   * Vala: förlustgränsen givet hur länge det mest utsatta objektet legat över linjen.
   * Når ett objekt vanliga gränsen och ett andetag finns kvar förbrukas det och gränsen blir
   * `graceMs` tills burken är under linjen igen (maxAboveMs = 0).
   */
  lossGrace(maxAboveMs: number): number {
    if (this.key !== 'breath') return this.baseGraceMs;
    if (this.breathing) {
      if (maxAboveMs <= 0) {
        this.breathing = false;
        this.graceMs = this.baseGraceMs;
      }
      return this.graceMs;
    }
    if (maxAboveMs >= this.baseGraceMs && this.breathLeft > 0) {
      this.breathLeft--;
      this.breathing = true;
      this.graceMs = this.param('graceMs', this.baseGraceMs);
    }
    return this.graceMs;
  }
}

/** Ett objekt som Maja kan dra i. level < 0 = räknas aldrig (specialobjekt). */
export interface MagnetItem {
  level: number;
  x: number;
  y: number;
  r: number;
  /** Fart (px/steg). */
  speed: number;
}

/**
 * Maja: första paret av samma nivå (≤ maxLevel) som båda ligger stilla och har ett gap < rangePx.
 * Skriver index i out[0], out[1]. Returnerar true om ett par hittades. Inga allokeringar.
 */
export function findMagnetPair(
  items: readonly MagnetItem[],
  count: number,
  rangePx: number,
  maxLevel: number,
  stillSpeed: number,
  out: number[],
): boolean {
  for (let i = 0; i < count; i++) {
    const a = items[i];
    if (a.level < 0 || a.level > maxLevel || a.speed > stillSpeed) continue;
    for (let j = i + 1; j < count; j++) {
      const b = items[j];
      if (b.level !== a.level || b.speed > stillSpeed) continue;
      const dx = b.x - a.x;
      const dy = b.y - a.y;
      const gap = Math.sqrt(dx * dx + dy * dy) - a.r - b.r;
      if (gap <= 0 || gap >= rangePx) continue;
      out[0] = i;
      out[1] = j;
      return true;
    }
  }
  return false;
}
