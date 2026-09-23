class_name CorridorLight
extends RefCounted
## Korridorens ljus som ren matematik (M6 spår A steg 3, ART_DIRECTION_V2 §4).
##
## [b]Inga Light3D.[/b] Mobil- och Compatibility-renderarna tar max åtta
## omni-ljus per mesh och hela våningen är EN mesh (research 06 §1). Ljuset
## bakas därför in i hörnfärgerna av [CorridorMesh] med funktionerna här, och
## handfacklan ligger i [code]corridor_surface.gdshaderinc[/code]. Samma
## funktioner ger fiendernas [code]light_tint[/code], så att en råtta under en
## fackla är lika varm som väggen bakom den.
##
## Tre hue-familjer i världen, aldrig fler: sot (kall fyllnad), eld (facklorna),
## ben (texturen själv). Gift, frost och guld hör till UI-lagret.

## Kall blågrå fyllnad: det som syns där ingen fackla når.
const COLD_FILL: Color = Color(0.08, 0.105, 0.165)
## Väggfacklans färg och räckvidd.
const TORCH_COLOR: Color = Color(1.0, 0.55, 0.24)
const TORCH_ENERGY: float = 2.2
const TORCH_RANGE_M: float = 4.8
## Handfacklan i shadern, samma siffror här för fienderna.
const HAND_COLOR: Color = Color(1.0, 0.56, 0.26)
const HAND_ENERGY: float = 1.55
const HAND_RANGE_M: float = 6.2
## "Taket försvinner helt" (§4). Golvet bär ljuset, väggarna mörknar uppåt.
const CEILING_FACTOR: float = 0.3
## Hörnskugga där vägg möter golv och tak.
const AO_FLOOR: float = 0.72
const AO_CEILING: float = 0.55


## Det bakade ljuset i en punkt. [param torches] är facklornas världspunkter.
static func bake(point: Vector3, torches: PackedVector3Array) -> Color:
	var light: Color = COLD_FILL
	for torch: Vector3 in torches:
		var d: float = point.distance_to(torch)
		var fall: float = clampf(1.0 - d / TORCH_RANGE_M, 0.0, 1.0)
		if fall <= 0.0:
			continue
		light += TORCH_COLOR * (TORCH_ENERGY * fall * fall)
	return Color(light.r, light.g, light.b, 1.0)


## Hörnskuggan på en vägg på höjden [param y].
static func wall_occlusion(y: float, ceiling: float) -> float:
	var low: float = lerpf(AO_FLOOR, 1.0, clampf(y / 0.7, 0.0, 1.0))
	var high: float = lerpf(1.0, AO_CEILING, clampf((y - (ceiling - 1.0)) / 1.0, 0.0, 1.0))
	return low * high


## Handfacklans bidrag på [param distance] meter (samma kurva som shadern).
static func hand(distance: float) -> Color:
	var fall: float = clampf(1.0 - distance / HAND_RANGE_M, 0.0, 1.0)
	return HAND_COLOR * (HAND_ENERGY * fall * fall)


## Fiendens ton: det bakade ljuset vid fötterna plus handfacklan, lite
## nedtonat eftersom en billboard inte har någon normal som vetter mot ljuset.
static func battler_tint(point: Vector3, torches: PackedVector3Array, camera_distance: float) -> Color:
	var c: Color = bake(point + Vector3(0.0, 1.0, 0.0), torches) + hand(camera_distance) * 0.8
	# Aldrig mörkare än att formen läses, aldrig så ljus att färgen bränns ut.
	return Color(clampf(c.r, 0.35, 1.4), clampf(c.g, 0.35, 1.3), clampf(c.b, 0.35, 1.3), 1.0)
