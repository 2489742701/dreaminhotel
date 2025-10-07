
# ==============================================================================
# droppable_item.gd - 可拾取物品脚本
# 负责在3D世界中显示可交互的物品，处理物品的旋转、浮动动画、碰撞检测和拾取逻辑
# ==============================================================================

# 扩展自Node3D类，表示这是一个3D场景节点
extends Node3D
# 定义类名为DroppableItem，方便在其他脚本中引用
class_name DroppableItem

# ========== 核心属性 ==========

# 物品资源引用，指向Item类型的资源
@export var item_res: Item:
	set(value):
		item_res = value

# 物品旋转速度（度/秒）
@export var rotate_speed: float = 45.0

# 物品上下浮动速度
@export var bob_speed: float = 2.0

# 物品上下浮动高度
@export var bob_height: float = 0.15

# ========== 模型资源设置 ==========

# 物品3D模型资源，带有setter方法实现实时更新
@export var mesh_resource: Mesh = null:
	# setter方法，当mesh_resource被设置时自动调用
	set(value):
		mesh_resource = value
		# 调用内部方法更新实际显示的模型
		_set_mesh_resource(value)

# ========== 粒子效果系统 ==========

# 常驻粒子效果节点（物品持续显示的特效）
@onready var always := $always as GPUParticles3D

# 拾取时的粒子效果节点（物品被拾取时显示的特效）
@onready var dead := $dead as GPUParticles3D

# ========== 粒子材质设置 ==========


# ========== 内部变量 ==========

# 物品的3D模型实例节点
@onready var mesh: MeshInstance3D = $MeshInstance3D

# 物品的基础Y轴位置（用于浮动动画）
var base_y: float

# 物品是否已被拾取的标志
var picked := false

# ========== 辅助方法 ==========

# 设置物品的3D模型资源
# @param new_mesh_resource: 新的网格模型资源
func _set_mesh_resource(new_mesh_resource: Mesh):
	# 安全检查：确保节点已添加到场景树中
	if not is_inside_tree():
		return
	# 安全检查：确保mesh节点存在且类型正确
	if mesh and mesh.is_class("MeshInstance3D"):
		# 更新mesh的模型资源
		mesh.mesh = new_mesh_resource

# ========== 生命周期函数 ==========

# 节点准备就绪时调用
func _ready():
	# 初始化基础Y轴位置
	base_y = 0.0

	# 获取碰撞检测区域并连接信号
	var area := $Area3D as Area3D
	# 连接body_entered信号到_on_body_enter方法
	area.body_entered.connect(_on_body_enter)

	# 初始化粒子效果
	if always:
		# 开始发射常驻粒子效果
		always.emitting = true
	if dead:
		# 确保拾取粒子效果不发射
		dead.emitting = false
		
# ========== 碰撞事件处理 ==========

# 当有物体进入碰撞区域时调用
func _on_body_enter(body):
	# 安全检查：如果物品已被拾取或进入的不是玩家，则不处理
	if picked or not body.is_in_group("player"):
		return
	# 标记物品为已拾取
	picked = true
	# 更新粒子效果状态
	if always:
		# 停止常驻粒子效果
		always.emitting = false
	if dead:
		# 重启并开始发射拾取粒子效果
		dead.restart()
		dead.emitting = true
	
	# 物品拾取逻辑
	if item_res:
		# 获取玩家节点
		var player = get_tree().get_first_node_in_group("player")
		if player:
			# 获取玩家的背包节点
			var inv = player.get_node("inventory")
			# 将物品添加到背包
			inv.add_item(item_res)
			# 如果是钥匙类型物品且有有效ID，添加到钥匙集合
			if item_res.kind == Item.Kind.KEY and item_res.key_id != -1:
				inv.add_key(item_res.key_id)
		# 注意：自动打开背包功能已被注释掉
			#if player.has_method("toggle_inventory"):
			#	player.toggle_inventory(true)
	
	# 隐藏物品模型
	mesh.hide()
	# 等待粒子效果播放完毕后删除节点
	await get_tree().create_timer(dead.lifetime if dead else 0.8).timeout
	# 从场景树中移除并释放此节点
	queue_free()

# ========== 动画更新 ==========

# 每帧更新物品的动画效果
# @param delta: 帧间隔时间（秒）
func _process(delta):
	# 如果物品已被拾取，则不更新动画
	if picked:
		return
	# 计算旋转角度并应用到模型（deg_to_rad将角度转换为弧度）
	mesh.rotate_y(deg_to_rad(rotate_speed * delta))
	# 计算上下浮动的Y轴偏移量
	# 使用正弦函数和当前时间创建平滑的上下浮动效果
	var offset = sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_height
	# 应用浮动偏移到模型位置
	mesh.position.y = base_y + offset
