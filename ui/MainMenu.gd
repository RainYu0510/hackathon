extends Control

## 主選單。project.godot 的 run/main_scene 指向這裡,遊戲從這一頁開始。
## 遊戲中按 Esc 是叫出暫停面板(ui/PauseMenu.tscn),從那裡才回得到這一頁。

## 三關的場景路徑,索引 = 關卡編號 - 1。「開始遊戲」用的也是 LEVEL_PATHS[0],
## 不另外開一個 FIRST_LEVEL_PATH —— 同一份資料不要開兩個欄位。
##
## 注意 Level02_PLACEHOLDER.tscn 的檔名有誤導性:它掛的是 levels/level_02.gd,
## 是真正可玩的第二關,不是佔位關卡(README.md 有記錄)。
##
## 三關都可以單獨開始:LevelBase._ready() 一進來就 GameManager.reset_level_state(),
## 而第二、三關的腳本自己會把護目鏡發給 P1,不會變成沒人能切空間的死局。
const LEVEL_PATHS: Array[String] = [
	"res://levels/Level01.tscn",
	"res://levels/Level02_PLACEHOLDER.tscn",
	"res://levels/Level03.tscn",
]

const CONTROLS_TEXT := """兩名玩家共用一台鍵盤

玩家 1 — NoxCat(黑貓)        玩家 2 — CyberDog(賽博狗)
  移動   A / D                  移動   ← / →
  跳躍   W                      跳躍   ↑
  攻擊   F                      攻擊   K
  互動   G                      互動   L

只有黑貓能拾取護目鏡,拿到之後互動鍵改成切換空間。
出口需要兩名玩家同時站進門框才會過關。

R    重新開始本關
Esc  暫停(繼續 / 回主選單 / 離開遊戲)"""

@onready var modal_layer: Control = $ModalLayer
@onready var controls_panel: PanelContainer = $ModalLayer/ControlsPanel
@onready var level_panel: PanelContainer = $ModalLayer/LevelPanel
@onready var start_button: Button = $Layout/Buttons/StartButton
@onready var level_button: Button = $Layout/Buttons/LevelButton
@onready var controls_button: Button = $Layout/Buttons/ControlsButton
@onready var quit_button: Button = $Layout/Buttons/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	level_button.pressed.connect(_open_panel.bind(level_panel))
	controls_button.pressed.connect(_open_panel.bind(controls_panel))
	quit_button.pressed.connect(_on_quit_pressed)
	$ModalLayer/ControlsPanel/Content/CloseButton.pressed.connect(_close_panel)
	$ModalLayer/LevelPanel/Content/LevelCloseButton.pressed.connect(_close_panel)
	$ModalLayer/ControlsPanel/Content/ControlsLabel.text = CONTROLS_TEXT
	# 三顆關卡按鈕接同一個 handler,不要寫三個幾乎一樣的函式。
	var level_buttons: Array[Button] = [
		$ModalLayer/LevelPanel/Content/Level1Button,
		$ModalLayer/LevelPanel/Content/Level2Button,
		$ModalLayer/LevelPanel/Content/Level3Button,
	]
	for index in range(level_buttons.size()):
		level_buttons[index].pressed.connect(_on_level_pressed.bind(index))
	_close_panel()
	# 瀏覽器版沒有「離開遊戲」這回事,直接把按鈕收掉。
	quit_button.visible = not OS.has_feature("web")

func _process(_delta: float) -> void:
	# 依 AGENTS.md 的架構約束,輸入一律輪詢 Input singleton,不用 _input() 回呼。
	# 沒有面板開著時 Esc 不做事 —— 主選單的 Esc 不該變成「離開遊戲」。
	if modal_layer.visible and Input.is_action_just_pressed("ui_cancel"):
		_close_panel()

## 遮罩與兩個面板都掛在 ModalLayer 底下一起開關,「有沒有彈出視窗開著」只有
## modal_layer.visible 這一個真相來源,不會出現遮罩開著但面板關著的走鐘狀態。
func _open_panel(panel: PanelContainer) -> void:
	controls_panel.visible = panel == controls_panel
	level_panel.visible = panel == level_panel
	modal_layer.visible = true
	for child: Node in panel.get_node("Content").get_children():
		if child is Button:
			(child as Button).grab_focus()
			break

## 關閉時把焦點整個放掉。原本是把焦點還給開啟面板的那顆按鈕,結果面板關掉之後
## 那顆按鈕上還留著一圈焦點框,看起來像卡住了。沒有焦點擁有者時,鍵盤按方向鍵
## Godot 會自己抓第一個可聚焦的控制項,所以鍵盤操作不會因此斷掉。
func _close_panel() -> void:
	modal_layer.visible = false
	controls_panel.visible = false
	level_panel.visible = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_PATHS[0])

func _on_level_pressed(index: int) -> void:
	get_tree().change_scene_to_file(LEVEL_PATHS[index])

func _on_quit_pressed() -> void:
	get_tree().quit()
