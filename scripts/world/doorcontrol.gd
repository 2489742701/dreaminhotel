# ==============================================================================
# DoorControl.gd
# 门控制系统
# 实现可交互的双区域手动门，支持需要钥匙的门，并提供零开销的3D文字提示
# 适用于初学者：了解如何实现游戏中的可交互物体、状态管理和用户提示系统
# ==============================================================================

# @tool装饰器允许在Godot编辑器中直接预览动画效果（无需运行游戏）
@tool                          # 允许在编辑器里直接看动画效果（无需运行）
# 扩展自Node3D类，表示这是一个3D场景节点
extends Node3D
# 定义类名为DoorControl，使其他脚本可以直接引用此类
class_name DoorControl         # 全局可调用，类似 DoorControl.new()

# ========== 可调参数 ==========
# 门的初始状态枚举：关闭、需要钥匙、已打开
# 初学者提示：枚举可以限制属性只能选择预设的值
@export_enum("CLOSED", "NEED_KEY", "OPENED") var start_state = "CLOSED"

# 打开这扇门需要的钥匙ID
@export var key_id_needed: int = 1              # 仅第一次开门所需的钥匙编号
# 门打开时旋转的角度
@export var open_angle: float = 90.0            # 门扇相对默认角度的张开幅度（度）
# 开门/关门动画的持续时间
@export var anim_speed: float = 0.5             # 开门/关门动画时长（秒）

# ========== 节点引用 ==========
# 这些是场景树中的子节点引用，使用$符号直接获取
@onready var door_mesh := $DoorMesh             # 门扇网格（旋转它的 Y 轴即可开关）
@onready var default_rot: Vector3 = door_mesh.rotation_degrees
# 记录初始角度，方便“关门时回到原点”
@onready var in_area  := $inarea                # 玩家踏进“里侧”区域
@onready var out_area := $outarea               # 玩家踏进“外侧”区域
@onready var prompt   := $DoorMesh/Tips         # 靠近才显示的提示文字（Label3D）
@onready var purpose  := $DoorMesh/LabelPurpose # 永久显示的房门用途（Label3D）

# 门的用途文字，可以在Inspector中随时修改
@export_multiline var purpose_text := "档案室"   # 在 Inspector 里随时改门用途
# 门牌文字的颜色
@export var purpose_color: Color = Color.WHITE     # 门牌字体颜色

# ========== 运行变量 ==========
var state: String = ""          # 当前门状态，与 start_state 同步
var is_animating: bool = false  # 动画期间禁止再次触发
var key_used: bool = false      # 标记钥匙是否已消耗（一次性门）
var last_side: float = 1.0      # 1=里侧开  -1=外侧开，决定门向哪边旋转
var _tween: Tween = null        # 复用的Tween对象

# ========== 信号 ==========
# 这些信号可以被其他节点连接，用于响应门的状态变化
# 初学者提示：信号是Godot中实现事件驱动编程的重要机制
signal door_opened()            # 给外部用（例如任务系统、音效管理器）
signal door_closed()

# ========== 初始化方法 ==========
# _ready方法在节点首次进入场景树时调用
func _ready():
	# 初始化门的状态
	state = start_state
	# 如果门一开始就是打开的，直接转到对应角度并标记钥匙已用
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
	# 应用门牌字体颜色，但保留原有的透明度
	purpose.modulate = Color(purpose_color.r, purpose_color.g, purpose_color.b, purpose.modulate.a)
	
	# 初始化Tween对象引用（先设为null，需要时再创建）
	_tween = null

# ========== 输入处理方法 ==========
# _input方法捕获所有输入事件
# @param event: 输入事件对象
func _input(event):
	# 没人在附近 或 正在动画，都不响应
	if not has_player() or is_animating:
		return
	# 检查是否按下了交互键（"E"）
	if event.is_action_pressed("interact"):
		try_toggle()        # 统一入口

# ========== 状态切换控制 ==========
# 统一入口：根据当前状态决定开门/关门/提示没钥匙
func try_toggle():
	# 使用match语句根据当前状态执行不同逻辑
	# 初学者提示：match类似于switch语句，但在GDScript中更加强大
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

# ========== 动画播放方法 ==========
# 开门动画：用Tween旋转门扇，方向由last_side决定
func play_open():
	# 防止在动画期间重复触发
	if is_animating: return
	is_animating = true
	# 更新门的状态
	state = "OPENED"
	key_used = true          # 钥匙一次性消耗

	# 创建新的Tween对象（不复用，避免状态问题）
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween().set_loops(0)
	
	# 补间动画：旋转门扇到打开角度
	_tween.tween_property(door_mesh, "rotation_degrees:y", default_rot.y + open_angle * last_side, anim_speed)
	# 动画完成后的回调函数
	_tween.tween_callback(func():
		is_animating = false
		door_opened.emit()   # 广播给外界（例如播放开门音效）
		hide_prompt()        # 门开了就不需要提示了
	)

# 关门动画：回到初始角度
func play_close():
	# 防止在动画期间重复触发
	if is_animating: return
	is_animating = true
	# 更新门的状态
	state = "CLOSED"

	# 创建新的Tween对象（不复用，避免状态问题）
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween().set_loops(0)
	
	# 补间动画：旋转门扇回到默认角度
	_tween.tween_property(door_mesh, "rotation_degrees:y", default_rot.y, anim_speed)
	# 动画完成后的回调函数
	_tween.tween_callback(func():
		is_animating = false
		door_closed.emit()   # 广播给外界
	)

# ========== 3D文字提示控制 ==========
# 玩家进入内侧区域时调用
func _on_in_area_enter(body):
	# 检查是否是玩家
	if body.is_in_group("player"):
		last_side = 1.0      # 记录“从里侧”进入
		show_prompt()        # 显示交互提示

# 玩家进入外侧区域时调用
func _on_out_area_enter(body):
	# 检查是否是玩家
	if body.is_in_group("player"):
		last_side = -1.0     # 记录“从外侧”进入
		show_prompt()        # 显示交互提示

# 玩家离开任意区域时调用
func _on_area_exit(body):
	# 检查是否是玩家
	if body.is_in_group("player"):
		hide_prompt()        # 隐藏交互提示

# 显示提示文字
func show_prompt():
	# 已开门就不提示
	if state == "OPENED":
		return               
	prompt.modulate.a = 1.0  # 瞬间显示（设置透明度为1）
	# 状态不同，提示文字不同
	prompt.text = "需要钥匙" if state == "NEED_KEY" else "E 推开"

# 隐藏提示文字
func hide_prompt():
	prompt.modulate.a = 0.0  # 设置透明度为0（完全透明）

# ========== 工具函数 ==========
# 检查玩家是否在附近
func has_player() -> bool:
	# 任一区域有人就算“附近”
	return in_area.has_overlapping_bodies() or out_area.has_overlapping_bodies()

# 检查玩家背包中是否有所需钥匙
func has_key_in_inventory() -> bool:
	# 安全检查：确保全局玩家存在
	if not Global.player:
		return false
	# 背包是Player下的子节点，用get_node获取
	var inv = Global.player.get_node("inventory")
	# 检查背包是否存在并拥有所需钥匙
	return inv and inv.has_key(key_id_needed)
