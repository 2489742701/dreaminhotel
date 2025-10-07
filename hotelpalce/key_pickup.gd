# ==============================================================================
# key_pickup.gd
# 钥匙拾取系统
# 实现了一个可交互的钥匙道具，具有悬浮旋转效果，玩家靠近时可以拾取
# 适用于初学者：了解如何实现基本的游戏交互物体和动画效果
# ==============================================================================

# 扩展自Node3D类，表示这是一个3D场景节点
extends Node3D
# 定义类名为Key，使其他脚本可以直接引用此类
class_name Key

# ========== 自定义属性 ==========
# @export关键字让这些属性可以在Godot编辑器中直接编辑
@export var key_id : int = 1                    # 钥匙编号，决定能开哪扇门
@export var rotate_speed : float = 90.0         # 悬浮旋转速度（度/秒）
@export var bob_speed : float = 2.0             # 上下浮动频率（Hz）
@export var bob_height : float = 0.15           # 浮动幅度（米）

# ========== 节点缓存 ==========
# @onready确保在节点准备好后再获取这些引用
@onready var mesh := $keymesh                   # 钥匙网格，负责旋转+浮动
@onready var pickup_area := $KeyPickup          # Area3D，检测玩家靠近
@onready var particles := $KeyPickup/keyend     # 拾取时一次性播放的特效
@onready var always := $KeyPickup/keyhere       # 常驻微光粒子（拾取前可见）

# ========== 运行状态 ==========
var base_y : float                              # 记录初始高度，用于浮动
var picked := false                             # 防重复拾取标记

# ========== 初始化方法 ==========
func _ready():
	# 记录钥匙初始Y坐标，作为浮动效果的基准
	base_y = mesh.global_position.y
	# 拾取特效默认关闭，只有在拾取时才播放
	particles.emitting = false                    
	# 常驻微光默认开启，作为视觉提示
	always.emitting = true                        
	# 连接区域检测信号，当有物体进入时触发_on_body_enter函数
	pickup_area.body_entered.connect(_on_body_enter)

# ========== 每帧更新方法 ==========
# @param delta: 自上一帧以来经过的时间（秒）
func _process(delta):
	# 如果已经被拾取，就不再更新动画
	if picked: return                            
	# 计算旋转角度并应用到钥匙网格上
	mesh.rotate_y(deg_to_rad(rotate_speed * delta))
	# 计算上下浮动的偏移量（使用正弦函数创建平滑的上下运动）
	# Time.get_ticks_msec()获取毫秒时间戳，用于创建连续的动画
	var offset = sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_height
	# 应用浮动效果
	mesh.global_position.y = base_y + offset

# ========== 交互处理方法 ==========
# 当有物体进入拾取区域时调用
# @param body: 进入区域的物体
func _on_body_enter(body):
	# 检查是否已被拾取，或者进入的不是玩家
	if picked or not body.is_in_group("player"):
		return

	# 标记钥匙已被拾取，防止重复拾取
	picked = true                                 
	# 关闭常驻微光，因为钥匙已经被拾取
	always.emitting = false                       

	# ========== 背包交互 ==========
	# 要求玩家节点下必须有子节点 inventory（挂 inventory.gd）
	if body.has_node("inventory"):
		# 安全调用，将钥匙添加到玩家的背包中
		body.get_node("inventory").add_key(key_id) # 安全调用，不会空指针

	# ========== 视觉反馈 ==========
	mesh.hide()                                   # 隐藏钥匙模型
	pickup_area.set_deferred("monitoring", false) # 避免信号再触发（物理锁保护）
	# 添加安全检查确保节点存在
	if particles:
		particles.restart()                           # 一次性特效
		particles.emitting = true

	# ========== 延迟自毁 ==========
	# 等待特效播放完毕后销毁自身
	await get_tree().create_timer(particles.lifetime).timeout
	queue_free()                                  # 特效播完销毁自身
