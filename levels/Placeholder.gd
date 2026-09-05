extends LevelBase

# 尚未設計的關卡佔位。改成 extends LevelBase 之後,佔位關至少會有 R 鍵重置、
# HUD 與相機 —— 以前它是 extends Node2D,任何關卡接過來就是死路,只能關程式。
# 這裡不生成玩家,所以沒有人會掉下去。
func build_level() -> void:
	var label := Label.new()
	label.text = "LEVEL DESIGN TBD"
	label.position = Vector2(450,320)
	label.add_theme_font_size_override("font_size",42)
	$HUD.add_child(label)
