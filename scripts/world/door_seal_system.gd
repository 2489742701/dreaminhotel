# ==============================================================================
# DoorSealSystem.gd - 门封系统
# 实现右键封门功能，支持木板动画效果
# 适用于初学者：了解如何实现交互式物体动画和状态管理
# ==============================================================================

# 扩展自Node3D类，表示这是一个3D场景节点
extends Node3D
class_name DoorSealSystem

# ========== 可调参数 ==========
# 是否可以封门（默认不可以）
@export var 可以封门: bool = false
# 封门需要的物品ID（木板物品）
@export var 封门所需物品ID: int = 1
# 木板数量
@export var 木板数量: int = 6
# 木板动画持续时间（秒）
@export var 木板动画速度: float = 0.8
# 木板间距
@export var 木板间距: float = 0.3

# ========== 节点引用 ==========
@onready var out木板组 := $out木板组 as Node3D  # 外部木板组
@onready var in木板组 := $in木板组 as Node3D    # 内部木板组
@onready var door_control := get_parent() as DoorControl  # 门控制系统

# ========== 运行变量 ==========
var 已封门: bool = false
var 木板动画中: bool = false
var 木板位置: Array[Vector3] = []
var _tween: Tween = null

# ========== 信号 ==========
signal 封门开始()
signal 封门完成()
signal 封门失败(原因: String)

# ========== 初始化方法 ==========
func _ready():
	# 初始化木板位置
	初始化木板位置()
	
	# 隐藏木板组（初始状态）
	隐藏所有木板()
	
	# 连接门控制系统的信号
	if door_control:
		door_control.door_opened.connect(_on_door_opened)
		door_control.door_closed.connect(_on_door_closed)

# ========== 输入处理方法 ==========
func _input(event):
	# 检查是否可以封门
	if not 可以封门 or 已封门 or 木板动画中:
		return
		
	# 检查玩家是否在门附近
	if not door_control or not door_control.has_player():
		return
		
	# 检查右键点击
	if event.is_action_pressed("right_click"):
		尝试封门()

# ========== 封门逻辑 ==========
func 尝试封门():
	# 检查玩家是否有封门所需物品
	if not 检查封门物品():
		封门失败.emit("缺少封门所需物品")
		print("封门失败：缺少封门所需物品")
		return
	
	# 检查门是否关闭
	if door_control.state == "OPENED":
		封门失败.emit("门必须关闭才能封门")
		print("封门失败：门必须关闭才能封门")
		return
	
	# 开始封门流程
	开始封门()

func 检查封门物品() -> bool:
	# 安全检查：确保全局玩家存在
	if not Global.player:
		return false
	
	# 获取玩家背包
	var inv = Global.player.get_node("inventory")
	if not inv:
		return false
	
	# 检查玩家是否有足够的封门物品
	# 这里需要根据您的物品系统实现具体的检查逻辑
	# 暂时返回true用于测试
	return true

func 开始封门():
	封门开始.emit()
	木板动画中 = true
	
	print("开始封门...")
	
	# 播放木板动画
	播放木板动画()

func 播放木板动画():
	# 创建新的Tween对象
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween().set_loops(0)
	
	# 显示木板组
	显示木板组()
	
	# 播放木板动画：从两侧向中间移动
	for i in range(木板数量):
		# 外部木板动画
		if out木板组 and i < out木板组.get_child_count():
			var out木板 = out木板组.get_child(i)
			var 目标位置 = 木板位置[i]
			
			# 设置初始位置（从外部开始）
			var 初始位置 = 目标位置 + Vector3(木板间距 * (木板数量 - i), 0, 0)
			out木板.position = 初始位置
			out木板.visible = true
			
			# 添加动画到Tween
			_tween.tween_property(out木板, "position", 目标位置, 木板动画速度)
		
		# 内部木板动画
		if in木板组 and i < in木板组.get_child_count():
			var in木板 = in木板组.get_child(i)
			var 目标位置 = 木板位置[i]
			
			# 设置初始位置（从内部开始）
			var 初始位置 = 目标位置 - Vector3(木板间距 * (木板数量 - i), 0, 0)
			in木板.position = 初始位置
			in木板.visible = true
			
			# 添加动画到Tween
			_tween.tween_property(in木板, "position", 目标位置, 木板动画速度)
	
	# 动画完成后的回调
	_tween.tween_callback(func():
		木板动画中 = false
		已封门 = true
		封门完成.emit()
		print("封门完成！")
		
		# 禁用门交互（封门后门无法再打开）
		if door_control:
			door_control.禁用门交互()
	)

# ========== 辅助方法 ==========
func 初始化木板位置():
	木板位置.clear()
	
	# 计算木板位置（从下到上排列）
	for i in range(木板数量):
		var y位置 = i * 0.2  # 调整这个值来改变木板间距
		木板位置.append(Vector3(0, y位置, 0))

func 隐藏所有木板():
	if out木板组:
		for 木板 in out木板组.get_children():
			木板.visible = false
	
	if in木板组:
		for 木板 in in木板组.get_children():
			木板.visible = false

func 显示木板组():
	if out木板组:
		out木板组.visible = true
	if in木板组:
		in木板组.visible = true

# ========== 门状态变化处理 ==========
func _on_door_opened():
	# 门打开时，如果已封门，则移除封门
	if 已封门:
		移除封门()

func _on_door_closed():
	# 门关闭时，不做特殊处理
	pass

func 移除封门():
	已封门 = false
	隐藏所有木板()
	print("封门已移除")

# ========== 公共方法 ==========
func 启用封门():
	可以封门 = true

func 禁用封门():
	可以封门 = false

func 获取封门状态() -> bool:
	return 已封门