/** Burkmått och Matter-parametrar enligt DESIGN.md §3. */
export const WORLD = {
  width: 360,
  height: 640,
} as const;

export const CAN = {
  /** Yttre bredd på burken. */
  outerWidth: 360,
  /** Väggtjocklek. */
  wallThickness: 20,
  /** Golvets ovansida. */
  floorY: 600,
  /** Burkens överkant (väggarna börjar här). HUD ligger i bandet ovanför. */
  topY: 24,
  /** Farolinjens y. */
  dangerY: 110,
  /** Y där det hängande objektet svävar (UI.md dropLineY). */
  spawnY: 64,
} as const;

export const CAN_LEFT = (WORLD.width - CAN.outerWidth) / 2; // 0
export const CAN_RIGHT = CAN_LEFT + CAN.outerWidth; // 360
export const INNER_LEFT = CAN_LEFT + CAN.wallThickness; // 20
export const INNER_RIGHT = CAN_RIGHT - CAN.wallThickness; // 340

export const PHYSICS = {
  gravityY: 1.0,
  restitution: 0.1,
  friction: 0.3,
  frictionStatic: 0.5,
  frictionAir: 0.005,
  /** Densitet = densityBase * (radie / densityRefRadius) ^ densityRadiusExponent. */
  densityBase: 0.001,
  densityRefRadius: 14,
  densityRadiusExponent: 2,
  /** Impuls som grannar får vid en merge. */
  mergeNeighbourImpulse: 0.004,
  /** Radie runt en merge där grannar knuffas. */
  mergeNeighbourRadius: 90,
  /** Hur länge (ms) ett objekt får ha centrum ovanför farolinjen innan förlust. */
  lossGraceMs: 1500,
  /** Cooldown (ms) innan nästa objekt får släppas om inget nuddats. */
  dropCooldownMs: 600,
} as const;

export function densityFor(radius: number): number {
  return (
    PHYSICS.densityBase *
    Math.pow(radius / PHYSICS.densityRefRadius, PHYSICS.densityRadiusExponent)
  );
}
