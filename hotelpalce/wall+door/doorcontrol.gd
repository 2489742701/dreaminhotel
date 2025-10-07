# ================================================================
#  DoorControl.gd  —— 双Area手动门 + 零开销3D文字提示
# ================================================================
@tool                          # 允许在编辑器里直接看动画效果（无需运行）
extends Node3D
class_name DoorControl         # 全局可调用，类似 DoorControl.new()

# ========== 可调参数 ==========
@export_enum("CLOSED", "NEED_KEY", "OPENED") var start_state = "CLOSED"
# 门初始状态：关闭 | 需要钥匙 | 已打开
@export var key_id_needed: int = 1              # 仅第一次开门所需的钥匙编号
@export var open_angle: float = 90.0            # 门扇相对默认角度的张开幅度（度）
@export var anim_speed: float = 0.5             # 开门/关门动画时长（秒）

# ========== 节点引用 ==========
@onready var door_mesh := $DoorMesh             # 门扇网格（旋转它的 Y 轴即可开关）
@onready var default_rot: Vector3 = door_mesh.rotation_degrees
# 记录初始角度，方便“关门时回到原点”
@onready var in_area  := $inarea                # 玩家踏进“里侧”区域
@onready var out_area := $outarea               # 玩家踏进“外侧”区域
@onready var prompt   := $DoorMesh/Tips         # 靠近才显示的提示文字（Label3D）
@onready var purpose  := $DoorMesh/LabelPurpose # 永久显示的房门用途（Label3D）
@export_multiline var purpose_text := "档案室"   # 在 Inspector 里随时改门用途
@export var purpose_color: Color = Color.WHITE     # 门牌字体颜色

# ========== 运行变量 ==========
var state: String = ""          # 当前门状态，与 start_state 同步
var is_animating: bool = false  # 动画期间禁止再次触发
var key_used: bool = false      # 标记钥匙是否已消耗（一次性门）
var last_side: float = 1.0      # 1=里侧开  -1=外侧开，决定门向哪边旋转

# ========== 信号 ==========
signal door_opened()            # 给外部用（例如任务系统、音效管理器）
signal door_closed()

# ================================================================
#  初始化：只跑一次
# ================================================================
func _ready():
	# 如果门一开始就是打开的，直接转到对应角度并标记钥匙已用
	state = start_state
	if state == "OPENED":
		door_mesh.rotation_degrees.y = default_rot.y + open_angle
		key_used = true

	# 连接区域触发信号：只关心玩家
	in_area.body_entered.connect(_on_in_area_enter)
	out_area.body_entered.connect(_on_out_area_enter)
	in_area.body_exited.connect(_on_area_exit)
	out_area.body_exited.connect(_on_area_exit)

	# 提示文字默认隐藏；用途文字一次性设置后不再改动
	 prompt.modulate.a = 0.0
	 purpose.text = purpose_text
	 purpose.add_theme_color_override("font_color", purpose_color)  # 应用门牌字体颜色

# ================================================================
#  输入：纯手动按 E
# ================================================================
func _input(event):
	# 没人在附近 或 正在动画，都不响应
	if not has_player() or is_animating:
		return
	if event.is_action_pressed("interact"):
		try_toggle()        # 统一入口

# ================================================================
#  统一入口：根据当前状态决定开门/关门/提示没钥匙
# ================================================================
func try_toggle():
	match state:
		"OPENED":
			play_close()
		"NEED_KEY":
			if has_key_in_inventory():
				play_open()
			else:
				print("门：背包里没有钥匙 #", key_id_needed)
		"CLOSED":
			play_open()

# ================================================================
#  开门动画：用 Tween 旋转门扇，方向由 last_side 决定
# ================================================================
func play_open():
	if is_animating: return
	is_animating = true
	state = "OPENED"
	key_used = true          # 钥匙一次性消耗

	var tween = create_tween()
	tween.tween_property(door_mesh, "rotation_degrees:y",
			default_rot.y + open_angle * last_side, anim_speed)
	tween.tween_callback(func():
		is_animating = false
		door_opened.emit()   # 广播给外界
		hide_prompt()        # 门开了就不需要提示了
	)

# ================================================================
#  关门动画：回到初始角度
# ================================================================
func play_close():
	if is_animating: return
	is_animating = true
	state = "CLOSED"

	var tween = create_tween()
	tween.tween_property(door_mesh, "rotation_degrees:y", default_rot.y, anim_speed)
	tween.tween_callback(func():
		is_animating = false
		door_closed.emit()
	)

# ================================================================
#  3D 文字提示：零开销，只在进出 Area 时开关
# ================================================================
func _on_in_area_enter(body):
	if body.is_in_group("player"):
		last_side = 1.0      # 记录“从里侧”进入
		show_prompt()

func _on_out_area_enter(body):
	if body.is_in_group("player"):
		last_side = -1.0     # 记录“从外侧”进入
		show_prompt()

func _on_area_exit(body):
	if body.is_in_group("player"):
		hide_prompt()

func show_prompt():
	if state == "OPENED":
		return               # 已开门就不提示
	prompt.modulate.a = 1.0  # 瞬间显示
	# 状态不同，文字不同
	prompt.text = "需要钥匙" if state == "NEED_KEY" else "E 推开"

func hide_prompt():
	prompt.modulate.a = 0.0

# ================================================================
#  工具函数
# ================================================================
func has_player() -> bool:
	# 任一区域有人就算“附近”
	return in_area.has_overlapping_bodies() or out_area.has_overlapping_bodies()

func has_key_in_inventory() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	# 背包是 Player 下的子节点，用 get_node 拿
	var inv = player.get_node("inventory")
	return inv and inv.has_key(key_id_needed)
