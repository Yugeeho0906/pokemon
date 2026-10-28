extends SceneTree
const Trainers = preload("res://game/trainers.gd")
const KOREAN_FONT = preload("res://assets/fonts/NotoSansKR.otf")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var canvas := Control.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("edf0e4")
	background.size = Vector2(1280,800)
	canvas.add_child(background)
	for i in range(12):
		var origin := Vector2(32+(i%4)*312,16+(i/4)*260)
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.texture = Trainers.battle_texture(Trainers.IDS[i])
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.position = origin+Vector2(68,0)
		art.size = Vector2(160,214)
		canvas.add_child(art)
		var label := Label.new()
		label.add_theme_font_override("font",KOREAN_FONT)
		label.add_theme_color_override("font_color",Color("24473f"))
		label.text = Trainers.NAMES[i]+" · 전투 시안"
		label.position = origin+Vector2(32,222)
		canvas.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/beta3")
	root.get_texture().get_image().save_png("res://artifacts/beta3/trainers-godot-preview.png")
	quit()
