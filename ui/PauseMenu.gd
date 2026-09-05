extends CanvasLayer

## 遊戲中的暫停面板。由 LevelBase._build_common() 掛進每一關。
##
## process_mode 設成 WHEN_PAUSED 是整個機制的關鍵:暫停時 LevelBase._process()
## 會停掉(它是預設的 inherit),Esc 就沒人輪詢、也沒人能把面板收起來。設成
## WHEN_PAUSED 之後,未暫停時由 LevelBase 輪詢 Esc 開啟、暫停時由這裡輪詢 Esc
## 關閉,兩邊剛好互補,不會互搶同一個按鍵。
## 按鈕也一樣 —— 節點在暫停中沒有 process 的話收不到 GUI 輸入,會變成一個
## 按不動的面板。

## open() 發生在哪一個 idle frame。用來擋掉「同一幀開了又關」。
var _opened_frame := -1

@onready var root: Control = $Root
@onready var resume_button: Button = $Root/Panel/Content/ResumeButton
@onready var quit_button: Button = $Root/Panel/Content/QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	resume_button.pressed.connect(close)
	$Root/Panel/Content/MenuButton.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# 瀏覽器版沒有「離開遊戲」這回事,直接把按鈕收掉。
	quit_button.visible = not OS.has_feature("web")
	root.visible = false

func _process(_delta: float) -> void:
	# WHEN_PAUSED,所以這個函式只在暫停中跑 —— 正是「按 Esc 收起面板」該在的地方。
	#
	# 但要擋掉開啟的那一幀:is_action_just_pressed() 在「整個 frame」都是 true,
	# 而 LevelBase._process()(父節點,同一幀先跑)才剛用同一個 just_pressed 把面板
	# 開起來。沒有這道保護的話,面板會在同一幀被開了又關,外觀上就是「Esc 完全沒反應」。
	if Engine.get_process_frames() == _opened_frame:
		return
	if root.visible and Input.is_action_just_pressed("ui_cancel"):
		close()

func open() -> void:
	if root.visible:
		return
	root.visible = true
	_opened_frame = Engine.get_process_frames()
	get_tree().paused = true
	resume_button.grab_focus()

func close() -> void:
	root.visible = false
	get_tree().paused = false

func _on_menu_pressed() -> void:
	# 順序很重要:先解除暫停再換場。反過來寫的話主選單會生在 paused 狀態下,
	# 按鈕全部按不動。
	get_tree().paused = false
	root.visible = false
	get_tree().change_scene_to_file(LevelBase.MAIN_MENU_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()
