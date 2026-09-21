extends Node
## Mätscen för [code]src/game/shaders/palette_lut.gdshader[/code].
##
## Renderar [code]design/probe_ramp.png[/code] (16 kända färger, 1 px per färg)
## tre gånger i en [SubViewport] och läser tillbaka pixlarna:
##
## [br]rad 0 – utan material (renderarens sanning för texturen)
## [br]rad 1 – [code]lut_strength = 0[/code] (ska vara byte-identisk med rad 0)
## [br]rad 2 – [code]lut_strength = 1[/code] med [code]lut_iron.png[/code]
##           (ska vara byte-identisk med LUT-texelns egen färg)
## [br]rad 3 – [code]lut_strength = 0[/code] + [code]modulate = #FF8040[/code]
##           (bevisar att vertex-COLOR-vägen fortfarande bär modulate)
##
## Rad 0 som referens gör testet renderaroberoende: kravet är att shadern inte
## får ändra en enda byte när den är avstängd, oavsett om motorn arbetar i
## sRGB (GL Compatibility) eller linjärt (Mobile/Forward+).
##
## Körs under xvfb-run – en riktig GPU-kontext krävs, [code]--headless[/code]
## ritar ingenting:
## [codeblock]
## xvfb-run -a godot --path . design/shader_probe.tscn                    # mobile
## xvfb-run -a godot --path . design/shader_probe.tscn --rendering-driver opengl3 \
##     --rendering-method gl_compatibility
## [/codeblock]
## Exit 0 = båda raderna stämmer, exit 1 = avvikelse (CI-vänligt).

const RAMP_PATH: String = "res://design/probe_ramp.png"
const LUT_PATH: String = "res://assets/sprites/dice/lut_iron.png"
const SHADER_PATH: String = "res://src/game/shaders/palette_lut.gdshader"

const SWATCHES: int = 16
const ROWS: int = 4
const MODULATE: Color = Color(1.0, 0.501961, 0.25098, 1.0)  # #FF8040


func _ready() -> void:
	await _run()


func _run() -> void:
	var ramp: Texture2D = load(RAMP_PATH) as Texture2D
	var lut: Texture2D = load(LUT_PATH) as Texture2D
	var shader: Shader = load(SHADER_PATH) as Shader
	if ramp == null or lut == null or shader == null:
		push_error("probe: saknar resurs")
		get_tree().quit(2)
		return

	print("=== palette_lut probe ===")
	print("rendering_method=%s  adapter=%s" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_api_version(),
	])

	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SWATCHES, ROWS)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	add_child(viewport)

	viewport.add_child(_sprite(ramp, 0, null))
	viewport.add_child(_sprite(ramp, 1, _material(shader, lut, 0.0)))
	viewport.add_child(_sprite(ramp, 2, _material(shader, lut, 1.0)))
	var modulated: Sprite2D = _sprite(ramp, 3, _material(shader, lut, 0.0))
	modulated.modulate = MODULATE
	viewport.add_child(modulated)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot: Image = viewport.get_texture().get_image()

	var source: Image = ramp.get_image()
	source.decompress()
	var lut_image: Image = lut.get_image()
	lut_image.decompress()

	var passthrough_bad: int = 0
	var lut_bad: int = 0
	var modulate_bad: int = 0
	print("i  källa   rad0 raw  rad1 s=0   rad2 s=1  förväntad LUT  rad3 mod  förväntad mod")
	for i: int in range(SWATCHES):
		var src_hex: String = _hex(source.get_pixel(i, 0))
		var raw_hex: String = _hex(shot.get_pixel(i, 0))
		var off_hex: String = _hex(shot.get_pixel(i, 1))
		var on_hex: String = _hex(shot.get_pixel(i, 2))
		var want_hex: String = _hex(_expected_lut(source.get_pixel(i, 0), lut_image))
		var mod_hex: String = _hex(shot.get_pixel(i, 3))
		var want_mod: String = _hex(source.get_pixel(i, 0) * MODULATE)
		var flags: String = ""
		if off_hex != raw_hex:
			passthrough_bad += 1
			flags += " PASSTHROUGH-FEL"
		if on_hex != want_hex:
			lut_bad += 1
			flags += " LUT-FEL"
		if not _near(shot.get_pixel(i, 3), source.get_pixel(i, 0) * MODULATE):
			modulate_bad += 1
			flags += " MODULATE-FEL"
		print("%2d #%s  #%s   #%s   #%s   #%s      #%s  #%s%s" % [
			i, src_hex, raw_hex, off_hex, on_hex, want_hex, mod_hex, want_mod, flags,
		])

	print("passthrough-avvikelser: %d/%d" % [passthrough_bad, SWATCHES])
	print("lut-avvikelser:         %d/%d" % [lut_bad, SWATCHES])
	print("modulate-avvikelser:    %d/%d" % [modulate_bad, SWATCHES])
	var ok: bool = passthrough_bad == 0 and lut_bad == 0 and modulate_bad == 0
	print("RESULTAT: %s" % ("OK" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


## Rad 2:s facit. Samma matematik som shadern, men på CPU och på texturens
## egna byte-värden – därför oberoende av renderarens färgrymd.
func _expected_lut(src: Color, lut_image: Image) -> Color:
	var l: float = clampf(src.r * 0.2126 + src.g * 0.7152 + src.b * 0.0722, 0.0, 1.0)
	var width: int = lut_image.get_width()
	var index: int = int(floor(l * float(width - 1)))
	return lut_image.get_pixel(clampi(index, 0, width - 1), 0)


## Modulate multipliceras i float och avrundas av rastreraren; 1/255 slack.
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 0.005 and absf(a.g - b.g) <= 0.005 and absf(a.b - b.b) <= 0.005


func _sprite(tex: Texture2D, row: int, mat: ShaderMaterial) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0.0, float(row))
	sprite.material = mat
	return sprite


func _material(shader: Shader, lut: Texture2D, strength: float) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("palette_lut", lut)
	mat.set_shader_parameter("lut_strength", strength)
	mat.set_shader_parameter("material_tint", Color(1, 1, 1, 1))
	mat.set_shader_parameter("luma_gamma", 1.0)
	mat.set_shader_parameter("flash", 0.0)
	mat.set_shader_parameter("flash_color", Color(1, 1, 1, 1))
	return mat


func _hex(c: Color) -> String:
	return c.to_html(false).to_upper()
