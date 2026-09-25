/**
 * Syntetiskt ljud med Web Audio enligt docs/UI.md §8. Inga ljudfiler.
 * Kedja: osc → (filter) → gain(envelope) → master → compressor → destination.
 * Låses upp vid första pointerdown (TECH.md).
 */
import { THEME } from '../data/theme';
import type { JuiceEvent } from '../data/juice';
import type { SetSound } from '../data/themes';

export interface ToneDef {
  readonly wave: string;
  readonly baseHz: number;
  readonly glideTo?: number;
  readonly attack: number;
  readonly decay: number;
  readonly gain: number;
  readonly lowpassHz?: number;
  readonly harmonicSemitones?: number;
  readonly harmonicGain?: number;
  readonly steps?: readonly number[];
  readonly stepMs?: number;
  readonly vibratoHz?: number;
  readonly vibratoCents?: number;
  readonly filterFromHz?: number;
  readonly filterToHz?: number;
  readonly tremoloHz?: number;
}

const S = THEME.sound as unknown as Record<string, ToneDef> & {
  master: { gain: number; calmGain: number; limiterThreshold: number };
};

let ctx: AudioContext | null = null;
let master: GainNode | null = null;
let noise: AudioBuffer | null = null;
let enabled = true;
let calm = false;
/** Merge-ljudets klangfärg (aktivt set). null = THEME.sound.merge. */
let timbre: SetSound | null = null;
/** Antal spelade klang-toner (testhooken verifierar att ljudvägen körs). */
let timbrePlays = 0;

/** Förmågor (DESIGN §14.5): overrides på merge- och faroljudet. Sätts vid rundstart. */
export interface MelodyCfg {
  melody: readonly number[];
  harmony: boolean;
  bass: boolean;
  harmonySemitones: number;
  harmonyGain: number;
  bassEvery: number;
  bassSemitones: number;
  bassGain: number;
}
export interface EchoCfg {
  delayMs: number;
  feedback: number;
  wet: number;
  repeats: number;
}
export interface TickCfg {
  gain: number;
  hz: readonly number[];
  clickMs: number;
}
let melody: MelodyCfg | null = null;
let echo: EchoCfg | null = null;
let layer: { def: ToneDef; semitones: number } | null = null;
let tickStyle: TickCfg | null = null;
let tickSrc: AudioBufferSourceNode | null = null;
let tickGain: GainNode | null = null;
/** Antal spelade merge-ljud med förmåga (testbarhet). */
let abilityPlays = 0;

let dangerOsc: OscillatorNode | null = null;
let dangerGain: GainNode | null = null;
let dangerLfo: OscillatorNode | null = null;

const semi = (n: number): number => Math.pow(2, n / 12);

function masterGain(): number {
  return calm ? S.master.calmGain : S.master.gain;
}

/** Skapar AudioContext. Måste kallas från en user gesture. */
export function unlockAudio(): void {
  if (ctx) {
    if (ctx.state === 'suspended') void ctx.resume();
    return;
  }
  const Ctor: typeof AudioContext | undefined =
    (globalThis as { AudioContext?: typeof AudioContext; webkitAudioContext?: typeof AudioContext })
      .AudioContext ??
    (globalThis as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!Ctor) return;
  try {
    ctx = new Ctor();
  } catch {
    ctx = null;
    return;
  }
  const comp = ctx.createDynamicsCompressor();
  comp.threshold.value = S.master.limiterThreshold;
  comp.connect(ctx.destination);
  master = ctx.createGain();
  master.gain.value = masterGain();
  master.connect(comp);
  if (ctx.state === 'suspended') void ctx.resume();
}

export function setSoundEnabled(on: boolean): void {
  enabled = on;
  if (!on) stopDanger();
}

export function setCalm(on: boolean): void {
  calm = on;
  if (master) master.gain.value = masterGain();
}

function ready(): boolean {
  return enabled && ctx !== null && master !== null;
}

function noiseBuffer(c: AudioContext): AudioBuffer {
  if (!noise) {
    const len = Math.floor(c.sampleRate * 0.6);
    noise = c.createBuffer(1, len, c.sampleRate);
    const d = noise.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
  }
  return noise;
}

/** En ton med envelope. Returnerar sluttiden. */
function tone(def: ToneDef, freq: number, vol: number, at: number): number {
  const c = ctx!;
  const osc = c.createOscillator();
  osc.type = (def.wave === 'noise' ? 'sine' : def.wave) as OscillatorType;
  osc.frequency.setValueAtTime(freq, at);

  let node: AudioNode = osc;
  if (def.lowpassHz) {
    const f = c.createBiquadFilter();
    f.type = 'lowpass';
    f.frequency.value = def.lowpassHz;
    osc.connect(f);
    node = f;
  }

  const g = c.createGain();
  const peak = Math.max(0.0002, def.gain * vol);
  g.gain.setValueAtTime(0.0001, at);
  g.gain.linearRampToValueAtTime(peak, at + def.attack);
  const end = at + def.attack + def.decay;
  g.gain.exponentialRampToValueAtTime(0.0001, end);
  node.connect(g);
  g.connect(master!);

  if (def.glideTo) {
    osc.frequency.exponentialRampToValueAtTime(
      Math.max(20, def.glideTo * (freq / def.baseHz)),
      end,
    );
  }

  if (def.vibratoHz && def.vibratoCents) {
    const lfo = c.createOscillator();
    lfo.frequency.value = def.vibratoHz;
    const depth = c.createGain();
    depth.gain.value = (freq * def.vibratoCents) / 1200;
    lfo.connect(depth);
    depth.connect(osc.frequency);
    lfo.start(at);
    lfo.stop(end + 0.02);
  }

  osc.start(at);
  osc.stop(end + 0.02);
  return end;
}

function playNoise(def: ToneDef, vol: number, at: number): void {
  const c = ctx!;
  const src = c.createBufferSource();
  src.buffer = noiseBuffer(c);
  const f = c.createBiquadFilter();
  f.type = 'lowpass';
  const end = at + def.attack + def.decay;
  f.frequency.setValueAtTime(def.filterFromHz ?? 3200, at);
  f.frequency.exponentialRampToValueAtTime(Math.max(40, def.filterToHz ?? 200), end);
  const g = c.createGain();
  const peak = Math.max(0.0002, def.gain * vol);
  g.gain.setValueAtTime(0.0001, at);
  g.gain.linearRampToValueAtTime(peak, at + def.attack);
  g.gain.exponentialRampToValueAtTime(0.0001, end);
  src.connect(f);
  f.connect(g);
  g.connect(master!);
  src.start(at);
  src.stop(end + 0.02);
  // 60 Hz sub under bruset
  tone({ wave: 'sine', baseHz: def.baseHz, attack: 0.001, decay: def.decay, gain: def.gain * 0.8 }, def.baseHz, vol, at);
}

/**
 * Setets klangfärg (UI.md §12.1.5): ett oscillatorlager per `layers[i]` → summa →
 * valfritt lågpass (med svep) → envelope → master. Glid underifrån och brusklick valfritt.
 */
function timbreAt(s: SetSound, f: number, vol: number, at: number): void {
  const c = ctx!;
  const end = at + s.attack + s.decay;
  const env = c.createGain();
  env.gain.setValueAtTime(0.0001, at);
  env.gain.linearRampToValueAtTime(Math.max(0.0002, s.gain * vol), at + s.attack);
  env.gain.exponentialRampToValueAtTime(0.0001, end);
  env.connect(master!);
  let sum: AudioNode = env;
  if (s.lowpassHz) {
    const lp = c.createBiquadFilter();
    lp.type = 'lowpass';
    lp.Q.value = s.lowpassQ ?? 0.7;
    lp.frequency.setValueAtTime(s.lowpassHz, at);
    if (s.lowpassToHz) lp.frequency.exponentialRampToValueAtTime(s.lowpassToHz, end);
    lp.connect(env);
    sum = lp;
  }
  for (const layer of s.layers) {
    const osc = c.createOscillator();
    osc.type = layer.wave;
    const fl = f * semi(layer.semitones);
    if (s.bendSemitones && s.bendMs) {
      osc.frequency.setValueAtTime(fl * semi(s.bendSemitones), at);
      osc.frequency.exponentialRampToValueAtTime(fl, at + s.bendMs / 1000);
    } else {
      osc.frequency.setValueAtTime(fl, at);
    }
    if (layer.detuneCents) osc.detune.value = layer.detuneCents;
    if (s.vibratoHz && s.vibratoCents) {
      const lfo = c.createOscillator();
      lfo.frequency.value = s.vibratoHz;
      const depth = c.createGain();
      depth.gain.value = s.vibratoCents;
      lfo.connect(depth);
      depth.connect(osc.detune);
      lfo.start(at);
      lfo.stop(end + 0.02);
    }
    const g = c.createGain();
    g.gain.value = layer.gain;
    osc.connect(g);
    g.connect(sum);
    osc.start(at);
    osc.stop(end + 0.02);
  }
  if (s.noise) {
    const src = c.createBufferSource();
    src.buffer = noiseBuffer(c);
    const lp = c.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = s.noise.lowpassHz;
    const g = c.createGain();
    g.gain.setValueAtTime(Math.max(0.0002, s.noise.gain * vol), at);
    g.gain.exponentialRampToValueAtTime(0.0001, at + s.noise.decay);
    src.connect(lp);
    lp.connect(g);
    g.connect(master!);
    src.start(at);
    src.stop(at + s.noise.decay + 0.02);
  }
  timbrePlays++;
}

/** Maestro: merge-tonen följer en melodi (halvtoner över 392 Hz). null = halvtonstrappan. */
export function setMergeMelody(m: MelodyCfg | null): void {
  melody = m;
}
/** Eko: fördröjda, avklingande upprepningar av merge-tonen. */
export function setMergeEcho(e: EchoCfg | null): void {
  echo = e;
}
/** Havsdrottningen: extra lager (stråkar) ovanpå merge-tonen. */
export function setMergeLayer(def: ToneDef | null, semitones = 0): void {
  layer = def ? { def, semitones } : null;
}
/** Tick: tick-tack i stället för det dova faroljudet. */
export function setDangerStyle(t: TickCfg | null): void {
  tickStyle = t;
}
/** Alla förmågeoverrides av (vid rundstart innan förmågan sätter sina). */
export function resetAudioOverrides(): void {
  melody = null;
  echo = null;
  layer = null;
  tickStyle = null;
}
export function abilityPlayCount(): number {
  return abilityPlays;
}

/** Aktivt sets klangfärg för merge-ljudet. Sätts vid rundstart, aldrig mitt i en runda. */
export function setMergeTimbre(s: SetSound | null): void {
  timbre = s;
}

export function timbrePlayCount(): number {
  return timbrePlays;
}

/** Ett sets merge-klang på 392 Hz · 2^(semitones/12), t.ex. arpeggio i boken och rundavslutet. */
export function playTimbre(s: SetSound, semitones = 0, delayMs = 0, intensity = 1): void {
  if (!ready()) return;
  const m = S.merge;
  const vol = 0.55 + 0.45 * Math.min(1, Math.max(0, intensity));
  timbreAt(s, m.baseHz * semi(semitones), vol, ctx!.currentTime + delayMs / 1000);
}

export interface PlayOpts {
  /** 0..1, skalar volymen. */
  intensity?: number;
  /** Combo-steg för merge-pitch. */
  combo?: number;
}

/** Spelar ett event ur ljudkartan. Tyst om ljudet är av eller inte upplåst. */
export function playSound(event: JuiceEvent | 'bomb' | 'ui', opts: PlayOpts = {}): void {
  if (!ready()) return;
  const def = S[event];
  if (!def) return;
  const vol = 0.55 + 0.45 * Math.min(1, Math.max(0, opts.intensity ?? 1));
  const now = ctx!.currentTime;

  if (event === 'danger') {
    startDanger();
    return;
  }

  if (event === 'bomb') {
    playNoise(def, vol, now);
    return;
  }

  if (event === 'merge') {
    const m = S.merge as ToneDef & { comboCap: number; semitonePerCombo: number };
    const steps = Math.min(opts.combo ?? 0, m.comboCap);
    const n = Math.max(1, opts.combo ?? 1);
    const f = m.baseHz * semi(melody ? melody.melody[(n - 1) % melody.melody.length] : steps * (m.semitonePerCombo ?? 1));
    mergeAt(m, f, vol, now);
    if (melody || echo || layer) abilityPlays++;
    if (melody?.harmony) mergeAt(m, f * semi(melody.harmonySemitones), vol * melody.harmonyGain, now);
    if (melody?.bass && n % melody.bassEvery === 0) mergeAt(m, f * semi(melody.bassSemitones), vol * melody.bassGain, now);
    if (layer) tone(layer.def, f * semi(layer.semitones), vol, now);
    if (echo) {
      for (let k = 1; k <= echo.repeats; k++) {
        mergeAt(m, f, vol * echo.wet * Math.pow(echo.feedback, k - 1), now + (k * echo.delayMs) / 1000);
      }
    }
    return;
  }

  if (def.steps && def.stepMs) {
    for (let i = 0; i < def.steps.length; i++) {
      const at = now + (i * def.stepMs) / 1000;
      const f = def.baseHz * semi(def.steps[i]);
      tone(def, f, vol, at);
      if (def.harmonicSemitones) {
        tone(def, f * semi(def.harmonicSemitones), vol * (def.harmonicGain ?? 0.25), at);
      }
    }
    return;
  }

  tone(def, def.baseHz, vol, now);
}

/** Merge-klangen (setets klangfärg, annars tonen + kvint) på frekvens f. */
function mergeAt(m: ToneDef, f: number, vol: number, at: number): void {
  if (timbre) {
    timbreAt(timbre, f, vol, at);
    return;
  }
  tone(m, f, vol, at);
  if (m.harmonicSemitones) tone(m, f * semi(m.harmonicSemitones), vol * (m.harmonicGain ?? 0.4), at);
}

/** Fristående ton ur data (skimrande, kedjepling). `semitones` transponerar, `delayMs` fördröjer. */
export function playTone(
  def: ToneDef & { readonly delayMs?: number },
  semitones = 0,
  intensity = 1,
): void {
  if (!ready()) return;
  const at = ctx!.currentTime + (def.delayMs ?? 0) / 1000;
  const vol = 0.55 + 0.45 * Math.min(1, Math.max(0, intensity));
  const steps = def.steps && def.stepMs ? def.steps : [0];
  for (let i = 0; i < steps.length; i++) {
    const t = at + (i * (def.stepMs ?? 0)) / 1000;
    const f = def.baseHz * semi(semitones + steps[i]);
    tone(def, f, vol, t);
    if (def.harmonicSemitones) tone(def, f * semi(def.harmonicSemitones), vol * (def.harmonicGain ?? 0.3), t);
  }
}

/** Dov sågtandston som loopar medan faran pågår. */
export function startDanger(): void {
  if (!ready() || dangerOsc || tickSrc) return;
  if (tickStyle) {
    startTick(tickStyle);
    return;
  }
  const c = ctx!;
  const d = S.danger;
  const osc = c.createOscillator();
  osc.type = 'sawtooth';
  osc.frequency.value = d.baseHz;
  const f = c.createBiquadFilter();
  f.type = 'lowpass';
  f.frequency.value = d.lowpassHz ?? 300;
  const g = c.createGain();
  g.gain.setValueAtTime(0.0001, c.currentTime);
  g.gain.linearRampToValueAtTime(d.gain, c.currentTime + d.attack);
  // Tremolo 4 Hz: amplitudmodulation, ingen ljusstyrkeväxling.
  const lfo = c.createOscillator();
  lfo.frequency.value = d.tremoloHz ?? 4;
  const depth = c.createGain();
  depth.gain.value = d.gain * 0.5;
  lfo.connect(depth);
  depth.connect(g.gain);
  osc.connect(f);
  f.connect(g);
  g.connect(master!);
  osc.start();
  lfo.start();
  dangerOsc = osc;
  dangerGain = g;
  dangerLfo = lfo;
}

/** Tick-tack: en loopad buffert på 1 s med ett klick per halvsekund (2 Hz). */
function startTick(t: TickCfg): void {
  const c = ctx!;
  const len = c.sampleRate;
  const buf = c.createBuffer(1, len, c.sampleRate);
  const d = buf.getChannelData(0);
  const click = Math.floor((c.sampleRate * t.clickMs) / 1000);
  for (let k = 0; k < t.hz.length; k++) {
    const o = Math.floor((k * len) / t.hz.length);
    for (let i = 0; i < click && o + i < len; i++) {
      d[o + i] = Math.sin((2 * Math.PI * t.hz[k] * i) / c.sampleRate) * Math.exp((-6 * i) / click);
    }
  }
  const src = c.createBufferSource();
  src.buffer = buf;
  src.loop = true;
  const g = c.createGain();
  g.gain.value = t.gain;
  src.connect(g);
  g.connect(master!);
  src.start();
  tickSrc = src;
  tickGain = g;
}

export function stopDanger(): void {
  if (tickSrc && ctx) {
    tickGain?.gain.setTargetAtTime(0.0001, ctx.currentTime, 0.05);
    tickSrc.stop(ctx.currentTime + 0.25);
    tickSrc = null;
    tickGain = null;
  }
  if (!dangerOsc || !ctx || !dangerGain) return;
  const end = ctx.currentTime + 0.25;
  dangerGain.gain.cancelScheduledValues(ctx.currentTime);
  dangerGain.gain.setValueAtTime(Math.max(0.0002, dangerGain.gain.value), ctx.currentTime);
  dangerGain.gain.exponentialRampToValueAtTime(0.0001, end);
  dangerOsc.stop(end + 0.02);
  dangerLfo?.stop(end + 0.02);
  dangerOsc = null;
  dangerGain = null;
  dangerLfo = null;
}
