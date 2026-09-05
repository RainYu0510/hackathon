extends LevelBase

# 第二關的正式內容與草圖尚未到位。這裡先做成「可通行的過場」,
# 讓測試者能一路玩到第三關;草圖到了直接換掉 build_level() 的內容即可,
# 不需要動任何串接(next_scene_path 與 exit_trigger 就是接口)。
func build_level() -> void:
	next_scene_path = "res://levels/Level03.tscn"
	dimension_background(self, false)
	spawn_players(Vector2(170,560), Vector2(240,560))
	platform(self, Vector2(900,640), Vector2(1800,80), Color("334463"))
	checkpoint(Vector2(150,600))    # 從第一關走出來的那道門(純視覺)
	checkpoint(Vector2(1650,600))   # 通往第三關的門
	exit_trigger(Vector2(1650,530), Vector2(100,170))   # 不需要鑰匙
	var title := Label.new()
	title.text = "LEVEL 02 - placeholder route. Walk right to reach Level 3."
	title.position = Vector2(330,70)
	title.add_theme_font_size_override("font_size",20)
	$HUD.add_child(title)
