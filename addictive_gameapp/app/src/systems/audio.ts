/**
 * Syntetiskt ljud med Web Audio enligt docs/UI.md §8. Inga ljudfiler.
 * Kedja: osc → (filter) → gain(envelope) → master → compressor → destination.
 * Låses upp vid första pointerdown (TECH.md).
 */
import { THEME } from '../data/theme';
import type { JuiceEvent } from '../data/juice';

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
    const f = m.baseHz * semi(steps * (m.semitonePerCombo ?? 1));
    tone(m, f, vol, now);
    if (m.harmonicSemitones) {
      tone(m, f * semi(m.harmonicSemitones), vol * (m.harmonicGain ?? 0.4), now);
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

/** Fristående ton ur data (skimrande, kedjepling). `semitones` transponerar, `delayMs` fördröjer. */
export function playTone(
  def: ToneDef & { readonly delayMs?: number },
  semitones = 0,
  intensity = 1,
): void {
  if (!ready()) return;
  const at = ctx!.currentTime + (def.delayMs ?? 0) / 1000;
  const vol = 0.55 + 0.45 * Math.min(1, Math.max(0, intensity));
  const f = def.baseHz * semi(semitones);
  tone(def, f, vol, at);
  if (def.harmonicSemitones) tone(def, f * semi(def.harmonicSemitones), vol * (def.harmonicGain ?? 0.3), at);
}

/** Dov sågtandston som loopar medan faran pågår. */
export function startDanger(): void {
  if (!ready() || dangerOsc) return;
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

export function stopDanger(): void {
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
