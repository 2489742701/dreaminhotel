extends Node3D
class_name Key
# 拾取型钥匙道具（悬浮旋转、靠近按 E 即捡）
# ===============================================================

@export var key_id : int = 1                    # 钥匙编号，决定能开哪扇门
@export var rotate_speed : float = 90.0         # 悬浮旋转速度（度/秒）
@export var bob_speed : float = 2.0             # 上下浮动频率（Hz）
@export var bob_height : float = 0.15           # 浮动幅度（米）

# === 节点缓存 ===================================================
@onready var mesh := $keymesh                   # 钥匙网格，负责旋转+浮动
@onready var pickup_area := $KeyPickup          # Area3D，检测玩家靠近
@onready var particles := $KeyPickup/keyend     # 拾取时一次性播放的特效
@onready var always := $KeyPickup/keyhere       # 常驻微光粒子（拾取前可见）

# === 运行状态 ===================================================
var base_y : float                              # 记录初始高度，用于浮动
var picked := false                             # 防重复拾取标记

# ===============================================================
func _ready():
	base_y = mesh.global_position.y
	particles.emitting = false                    # 特效默认关闭
	always.emitting = true                        # 常驻微光开启
	pickup_area.body_entered.connect(_on_body_enter) # 只连接触发信号

# ===============================================================
# 每帧：旋转+正弦浮动（性能极轻）
func _process(delta):
	if picked: return                            # 已拾取就不再更新
	mesh.rotate_y(deg_to_rad(rotate_speed * delta))
	var offset = sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_height
	mesh.global_position.y = base_y + offset

# ===============================================================
# 玩家进入拾取区域即自动捡起
func _on_body_enter(body):
	if picked or not body.is_in_group("player"):
		return

	picked = true                                 # 标记已捡
	always.emitting = false                       # 关闭常驻微光

	# === 背包交互（子节点方式） ==================================
	# 要求玩家节点下必须有子节点 inventory（挂 inventory.gd）
	if body.has_node("inventory"):
		body.get_node("inventory").add_key(key_id) # 安全调用，不会空指针

	# === 视觉反馈 ===============================================
	mesh.hide()                                   # 隐藏钥匙模型
	pickup_area.set_deferred("monitoring", false) # 避免信号再触发（物理锁保护）
	# 添加安全检查确保节点存在
	if particles:
		particles.restart()                           # 一次性特效
		particles.emitting = true

	# === 延迟自毁 ===============================================
	await get_tree().create_timer(particles.lifetime).timeout
	queue_free()                                  # 特效播完销毁自身
