
# ==============================================================================
# droppable_item.gd - 可拾取物品脚本
# 负责在3D世界中显示可交互的物品，处理物品的旋转、浮动动画、碰撞检测和拾取逻辑
# ==============================================================================

# 扩展自RigidBody3D类，表示这是一个3D物理刚体
extends RigidBody3D
# 定义类名为DroppableItem，方便在其他脚本中引用
class_name DroppableItem

# ========== 核心属性 ==========

# 物品资源引用，指向Item类型的资源
@export var 物品资源: Item:
	set(value):
		物品资源 = value

# 物品旋转速度（度/秒）
@export var 旋转速度: float = 45.0

# 物品上下浮动速度
@export var 浮动速度: float = 2.0

# 物品上下浮动高度
@export var 浮动高度: float = 0.15

# 掉落物模型缩放比例（相对于手持大小的倍数）
# 手持大小通常为1.0，掉落物建议2.0-3.0倍
@export var 模型缩放: float = 2.5:
	set(value):
		模型缩放 = value
		# 如果已在场景树中，立即应用缩放
		if is_inside_tree() and mesh:
			_apply_model_scale()

# ========== 模型资源设置 ==========

# 物品3D模型资源，带有setter方法实现实时更新
@export var 模型资源: Mesh = null:
	# setter方法，当模型资源被设置时自动调用
	set(value):
		模型资源 = value
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

# 推力速度
var push_velocity := Vector3.ZERO

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
		# 应用缩放
		_apply_model_scale()

# 应用模型缩放
# 让掉落物模型比手持时更大，便于玩家在场景中发现和拾取
func _apply_model_scale():
	if not mesh:
		return
	
	# 获取当前变换
	var current_transform = mesh.transform
	
	# 提取当前旋转（保留旋转信息）
	var current_basis = current_transform.basis
	
	# 创建新的缩放矩阵
	var scale_matrix = Basis().scaled(Vector3(模型缩放, 模型缩放, 模型缩放))
	
	# 组合：先旋转，再缩放
	var new_basis = scale_matrix * current_basis.orthonormalized()
	
	# 应用新的变换（保留位置）
	mesh.transform = Transform3D(new_basis, current_transform.origin)
	print("掉落物模型缩放应用: ", 模型缩放, "倍")

# 设置向前的推力
# @param direction: 推力方向
# @param force: 推力大小
func set_push_force(direction: Vector3, force: float):
	push_velocity = direction.normalized() * force
	# 解冻刚体，允许移动
	freeze = false
	# 应用推力
	apply_central_impulse(push_velocity)

# 自动从物品资源加载模型
# 确保掉落物显示的模型与物品枚举定义中的模型一致
func _auto_load_model_from_item():
	# 安全检查：确保物品资源存在
	if not 物品资源:
		print("警告: 掉落物没有物品资源，无法自动加载模型")
		return
	
	# 检查物品资源是否有模型属性
	if 物品资源.get("模型") != null:
		# 如果物品有模型属性，直接使用
		var item_model = 物品资源.模型
		if item_model:
			_set_mesh_resource(item_model)
			mesh.visible = true
			print("自动加载物品模型: ", 物品资源.名称翻译键, " 模型可见: ", mesh.visible)
	else:
		print("警告: 物品资源没有模型定义: ", 物品资源.名称翻译键)
		# 如果物品没有模型，使用默认的模型资源（如果有的话）
		if 模型资源:
			_set_mesh_resource(模型资源)
			mesh.visible = true
			print("使用默认模型资源")
		else:
			print("警告: 物品没有模型，且无默认模型，将使用默认BoxMesh")

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
	
	# 自动加载物品资源中定义的模型
	_auto_load_model_from_item()
		
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
	
	# 物品拾取逻辑 - 将物品添加到玩家背包
	if 物品资源:
		# 使用Global.player获取玩家引用
		if Global.player:
			# 获取玩家的背包节点
			var inv = Global.player.get_node("inventory")
			if inv:
				# 将物品添加到背包 - add_item内部会自动处理钥匙类物品的特殊逻辑
				inv.add_item(物品资源)
	# 注意：自动打开背包功能已被注释掉，需要玩家手动打开
	#if Global.player.has_method("toggle_inventory"):
	#	Global.player.toggle_inventory(true)
	
	# 隐藏物品模型
	mesh.hide()
	
	# 立即禁用刚体碰撞，避免继续与玩家碰撞
	collision_layer = 0
	collision_mask = 0
	freeze = true
	
	# 处理拾取粒子效果并确保节点销毁
	if dead:
		# 断开可能存在的旧连接，避免多次连接
		if dead.is_connected("finished", queue_free):
			dead.disconnect("finished", queue_free)
		# 重启并开始发射拾取粒子效果
		dead.restart()
		dead.emitting = true
		# 连接finished信号到queue_free
		dead.finished.connect(queue_free)
	else:
		# 如果没有粒子效果，直接删除节点
		queue_free()

# ========== 动画更新 ==========

# 每帧更新物品的动画效果
# @param delta: 帧间隔时间（秒）
func _process(delta):
	# 如果物品已被拾取，则不更新动画
	if picked:
		return
	# 计算旋转角度并应用到模型（deg_to_rad将角度转换为弧度）
	mesh.rotate_y(deg_to_rad(旋转速度 * delta))
	# 计算上下浮动的Y轴偏移量
	# 使用正弦函数和当前时间创建平滑的上下浮动效果
	var offset = sin(Time.get_ticks_msec() / 1000.0 * 浮动速度) * 浮动高度
	# 应用浮动偏移到模型位置
	mesh.position.y = base_y + offset
