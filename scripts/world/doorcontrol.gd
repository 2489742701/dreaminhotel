# ==============================================================================
# DoorControl.gd
# 门控制系统
# 实现可交互的双区域手动门，支持需要钥匙的门，并提供零开销的3D文字提示
# 适用于初学者：了解如何实现游戏中的可交互物体、状态管理和用户提示系统
# ==============================================================================

# @tool装饰器允许在Godot编辑器中直接预览动画效果和颜色变化（无需运行游戏）
@tool                          # 允许在编辑器里直接看动画效果和颜色变化（无需运行）
# 扩展自Node3D类，表示这是一个3D场景节点
extends Node3D
# 定义类名为DoorControl，使其他脚本可以直接引用此类
class_name DoorControl         # 全局可调用，类似 DoorControl.new()

# ========== 可调参数 ==========
# 门的初始状态枚举：关闭、需要钥匙、已打开
# 初学者提示：枚举可以限制属性只能选择预设的值
@export_enum("CLOSED", "NEED_KEY", "OPENED") var 初始状态 = "CLOSED"

# 打开这扇门需要的钥匙ID
@export var 所需钥匙ID: int = 1              # 仅第一次开门所需的钥匙编号
# 门打开时旋转的角度
@export var 开门角度: float = 90.0            # 门扇相对默认角度的张开幅度（度）
# 开门/关门动画的持续时间
@export var 动画速度: float = 0.5             # 开门/关门动画时长（秒）

# 封门功能相关参数
@export var 可以封门: bool = false            # 是否可以封门（默认不可以）
@export var 默认已封: bool = false            # 门默认是否已封
@export var 封门所需物品ID: int = 1           # 封门需要的物品ID
@export var 木板动画速度: float = 0.03         # 木板动画速度（秒）
@export var 木板动画间隔: float = 0.001        # 木板动画间隔（秒）
@export var 调试模式: bool = false            # 调试模式：关闭后需要手持封门物品才能封门

# 斧头劈砍功能相关参数
@export var 门总耐久度: int = 3                # 门需要砍几次才能开
@export var 斧头物品ID: int = 2               # 斧头的物品ID

# 怪物检测范围
@export var 怪物检测范围: float = 5.0          # 怪物检测门的范围（米）

# ========== 材质颜色控制参数 ==========
# 修改这里：添加 set 关键字，指定变量改变时调用的函数
@export var 门颜色: Color = Color.WHITE:
	set(value):
		门颜色 = value
		# 在编辑器模式下立即更新颜色
		if Engine.is_editor_hint():
			_update_door_color()

@export var 门框颜色: Color = Color.WHITE:
	set(value):
		门框颜色 = value
		# 在编辑器模式下立即更新颜色
		if Engine.is_editor_hint():
			_update_frame_color()

# ========== 节点引用 ==========
# 节点引用
# 这些是场景树中的子节点引用，使用$符号直接获取
@onready var door_mesh := $DoorMesh             # 门扇网格（旋转它的 Y 轴即可开关）
@onready var default_rot: Vector3 = door_mesh.rotation_degrees
# 记录初始角度，方便"关门时回到原点"
@onready var in_area  := $inarea                # 玩家踏进"里侧"区域
@onready var out_area := $outarea               # 玩家踏进"外侧"区域
# @onready var prompt   := $DoorMesh/Tips         # 靠近才显示的提示文字（Label3D）- 已删除
# @onready var prompt2  := $DoorMesh/Tips2        # 另一面的提示文字（Label3D）- 已删除
@onready var purpose  := $DoorMesh/LabelPurpose # 永久显示的房门用途（Label3D）

# 材质相关节点引用
@onready var door_mesh_real := $DoorMesh/门     # 真正的门扇网格（MeshInstance3D）
@onready var door_frame_mesh := $门框            # 门框网格（直接挂在根节点下）

# 木板组节点引用
@onready var out_planks := $Out木板组           # 外侧木板组
@onready var in_planks := $in木板组             # 内侧木板组

# 木板动画相关变量
var is_sealed: bool = false                     # 门是否已封
var current_door_hp: int = 0                    # 记录当前剩余耐久度
var current_plank_index: int = 0                # 当前正在劈砍的木板索引

# 动画队列系统
var animation_queue = []                        # 动画队列
var is_animation_playing = false                # 当前是否有动画正在播放

# 劈砍冷却时间
@export var 劈砍冷却时间: float = 0.5           # 秒
var 上次劈砍时间: float = 0                      # 上次劈砍的时间戳

# 门的用途文字，可以在Inspector中随时修改
@export_multiline var 用途文字 := "档案室"   # 在 Inspector 里随时改门用途
# 门牌文字的颜色
@export var 用途颜色: Color = Color.WHITE     # 门牌字体颜色

# ========== 运行变量 ==========
var state: String = ""          # 当前门状态，与 初始状态 同步
var is_animating: bool = false  # 动画期间禁止再次触发
var key_used: bool = false      # 标记钥匙是否已消耗（一次性门）
var last_side: float = 1.0      # 1=里侧开  -1=外侧开，决定门向哪边旋转
var player_last_side: float = 1.0  # 玩家的开门方向
var monster_last_side: float = 1.0  # 怪物的开门方向
var _tween: Tween = null        # 复用的Tween对象
var 门已封: bool = false        # 门是否已被封住
var is_destroyed: bool = false   # 门是否已被破坏（耐久归零）
var is_executing_chop: bool = false  # 防止重入锁，避免怪物和玩家同时攻击
var interaction_cooldown: float = 0.0  # 门交互冷却时间（秒）
var interaction_cooldown_duration: float = 2.0  # 门交互冷却持续时间（秒）
var _is_opening: bool = false  # 递归锁，防止 try_open_door 无限递归

# ========== 信号 ==========
# 这些信号可以被其他节点连接，用于响应门的状态变化
# 初学者提示：信号是Godot中实现事件驱动编程的重要机制
signal door_opened()            # 给外部用（例如任务系统、音效管理器）
signal door_closed()

# ========== 初始化方法 ==========
# _ready方法在节点首次进入场景树时调用
func _ready():
	# 防御性编程：检查关键节点是否存在
	if not is_instance_valid(door_mesh):
		push_error("门控系统初始化失败：找不到门扇网格节点")
		return
	
	# 将门控制系统添加到door_control组，方便斧头攻击效果检测
	add_to_group("door_control")
	
	# 初始化门的状态
	state = 初始状态
	
	# 初始化封门状态
	if 可以封门:
		门已封 = 默认已封
		if 门已封:
			state = "NEED_KEY"
			所需钥匙ID = -1
			is_sealed = true
			initialize_plank_durability()
			reset_planks_state()
		else:
			hide_all_planks()
	
	# 初始化门耐久度
	current_door_hp = 门总耐久度
	
	# 初始化木板索引
	current_plank_index = 0
	
	# 如果门一开始就是打开的，直接转到对应角度并标记钥匙已用
	if state == "OPENED":
		door_mesh.rotation_degrees.y = default_rot.y + 开门角度
		key_used = true
	else:
		door_mesh.rotation_degrees.y = default_rot.y

	# 连接区域触发信号：只关心玩家
	in_area.body_entered.connect(_on_in_area_enter)
	out_area.body_entered.connect(_on_out_area_enter)
	in_area.body_exited.connect(_on_area_exit)
	out_area.body_exited.connect(_on_area_exit)

	# 提示文字默认隐藏；用途文字一次性设置后不再改动

func _physics_process(delta):
	# 更新交互冷却时间
	if interaction_cooldown > 0:
		interaction_cooldown -= delta
	# prompt.modulate.a = 0.0
	# prompt2.modulate.a = 0.0
	purpose.text = 用途文字
	# 应用门牌字体颜色，但保留原有的透明度
	purpose.modulate = Color(用途颜色.r, 用途颜色.g, 用途颜色.b, purpose.modulate.a)
	
	# 初始化Tween对象引用（先设为null，需要时再创建）
	_tween = null
	
	# 初始化材质
	initialize_materials()



# ========== 材质管理系统 (安全修复版) ========== 

func initialize_materials() -> void:
	# 确保节点已加载
	if not is_instance_valid(door_mesh_real) or not is_instance_valid(door_frame_mesh):
		return

	# 初始化门扇材质
	_ensure_unique_material(door_mesh_real)
	# 初始化门框材质
	_ensure_unique_material(door_frame_mesh)
	
	# 强制刷新一次颜色
	_update_door_color()
	_update_frame_color()

# 通用函数：确保网格拥有一个独立的覆盖材质（带安全检查）
func _ensure_unique_material(mesh_instance: MeshInstance3D) -> void:
	if not is_instance_valid(mesh_instance):
		return
	
	# 1. 检查网格资源是否存在
	var mesh = mesh_instance.mesh
	if not mesh:
		return # 没有网格，没法设置材质
		
	# 2. 检查网格是否有表面 (Surface)
	# 如果是新建的空网格，表面数可能是0，试图操作索引0会报错
	if mesh.get_surface_count() == 0:
		return

	var active_mat = null
	
	# 3. 安全获取当前材质
	# 只有当覆盖材质数量大于0时，才尝试获取，防止报错！
	if mesh_instance.get_surface_override_material_count() > 0:
		active_mat = mesh_instance.get_surface_override_material(0)
	
	# 如果没有覆盖材质，尝试从Mesh资源获取默认材质
	if not active_mat:
		active_mat = mesh.surface_get_material(0)
	
	# 4. 创建或复制材质
	if not active_mat:
		# 没有任何材质，新建一个
		active_mat = StandardMaterial3D.new()
		# 立即应用，这会自动调整 override 数组的大小
		mesh_instance.set_surface_override_material(0, active_mat)
	else:
		# 有材质，检查是否需要复制（Make Unique）
		if not active_mat.resource_local_to_scene:
			active_mat = active_mat.duplicate()
			mesh_instance.set_surface_override_material(0, active_mat)

# 更新门扇颜色的内部函数
func _update_door_color():
	# 基础检查
	if not is_instance_valid(door_mesh_real): return
	if not door_mesh_real.mesh or door_mesh_real.mesh.get_surface_count() == 0: return

	# 确保有独立材质 (如果之前没有，这个函数会创建，不会报错)
	_ensure_unique_material(door_mesh_real)
	
	# 安全获取材质进行修改
	# 经过 ensure 步骤后，这里一定是安全的
	if door_mesh_real.get_surface_override_material_count() > 0:
		var mat = door_mesh_real.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.albedo_color = 门颜色

# 更新门框颜色的内部函数
func _update_frame_color():
	# 基础检查
	if not is_instance_valid(door_frame_mesh): return
	if not door_frame_mesh.mesh or door_frame_mesh.mesh.get_surface_count() == 0: return

	# 确保有独立材质
	_ensure_unique_material(door_frame_mesh)
	
	# 安全获取材质进行修改
	if door_frame_mesh.get_surface_override_material_count() > 0:
		var mat = door_frame_mesh.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.albedo_color = 门框颜色

# 设置门和门框颜色函数
func set_door_color(door_color: Color, frame_color: Color) -> void:
	# 更新导出的颜色变量（通过setter会自动调用更新函数）
	门颜色 = door_color
	门框颜色 = frame_color
	
	print("门颜色已设置为：", door_color, "，门框颜色已设置为：", frame_color)

# 获取当前门颜色
func get_door_color() -> Color:
	return 门颜色

# 获取当前门框颜色
func get_frame_color() -> Color:
	return 门框颜色

# 输入处理方法 ==========
# _input方法捕获所有输入事件
# @param event: 输入事件对象
func _input(event):
	# 没人在附近 或 正在动画，都不响应
	if not has_player() or is_animating:
		return
	
	# 检查是否按下了交互键（"E"）
	if event.is_action_pressed("interact"):
		try_toggle()        # 统一入口
	
	# 检查是否按下了右键（封门功能）
	# 只有当玩家手持封门物品时才响应右键
	# 重要：只在当前门有玩家时处理，由全局算法决定封哪扇门
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _player_holding_seal_item():
			# 使用全局评分算法找最近的门封门
			# 只由第一个检测到玩家在区域内的门触发，避免重复
			if in_area.has_overlapping_bodies() or out_area.has_overlapping_bodies():
				_try_seal_nearest_door()
		# 否则不处理，让玩家系统的右键处理生效（消耗品使用等）

# 全局封门入口：找到玩家附近最近的门并封门
# 使用空间查询算法，基于距离+朝向的综合评分找到最佳封门目标
# 静态变量防止同一帧多个门重复触发
var _seal_request_processed: bool = false

func _try_seal_nearest_door():
	# 防止同一帧多次触发
	if _seal_request_processed:
		return
	_seal_request_processed = true
	
	# 延迟重置标志
	get_tree().create_timer(0.1).timeout.connect(func(): _seal_request_processed = false)
	
	if not Global.player:
		return
	
	# 检查玩家是否手持封门物品
	if not is_holding_seal_item():
		return
	
	var player_pos = Global.player.global_position
	var player_forward = _get_player_forward()
	
	# 收集所有候选门
	var candidates = _find_sealable_doors_near_player(player_pos)
	
	if candidates.is_empty():
		print("封门失败：附近没有可封的门")
		return
	
	# 使用评分算法找到最佳封门目标
	var best_door = _find_best_seal_target(candidates, player_pos, player_forward)
	
	if best_door:
		print("封门：选中最近的门 - ", best_door.name)
		best_door.try_seal_door_with_item()
	else:
		print("封门失败：没有合适的门")

# 获取玩家前方方向
func _get_player_forward() -> Vector3:
	if not Global.player:
		return Vector3.FORWARD
	
	# 优先使用相机方向
	if Global.player.has_node("camera"):
		var cam = Global.player.get_node("camera")
		return -cam.global_transform.basis.z.normalized()
	
	# 备用：使用玩家自身方向
	return -Global.player.global_transform.basis.z.normalized()

# 找到玩家附近所有可封的门
# @param player_pos: 玩家位置
# @return: 候选门数组
func _find_sealable_doors_near_player(player_pos: Vector3) -> Array:
	var candidates: Array = []
	
	# 获取所有门控制节点
	var all_doors = get_tree().get_nodes_in_group("door_control")
	
	for door in all_doors:
		if not is_instance_valid(door):
			continue
		
		# 过滤条件1：门必须可以封（使用 has 方法检查属性存在性）
		if not "可以封门" in door or not door.可以封门:
			continue
		
		# 过滤条件2：门不能已被封
		if "is_sealed" in door and door.is_sealed:
			continue
		
		# 过滤条件3：门必须是关闭状态
		if "state" in door and door.state != "CLOSED":
			continue
		
		# 过滤条件4：距离在可封范围内（2米）
		var dist = player_pos.distance_to(door.global_position)
		if dist > 2.0:
			continue
		
		candidates.append(door)
		print("候选门: ", door.name, " 距离: ", "%.2f" % dist)
	
	return candidates

# 评分算法：找到最佳封门目标
# 综合考虑距离和朝向，距离越近、面朝方向越对准的门得分越高
# @param candidates: 候选门列表
# @param player_pos: 玩家位置
# @param player_forward: 玩家前方方向
# @return: 最佳门节点
func _find_best_seal_target(candidates: Array, player_pos: Vector3, player_forward: Vector3) -> Node:
	var best_door: Node = null
	var best_score: float = -999.0
	
	for door in candidates:
		var door_pos = door.global_position
		
		# 因子1：距离评分（越近越好，0-1分）
		var distance = player_pos.distance_to(door_pos)
		var distance_score = 1.0 / (1.0 + distance)  # 距离越近分数越高
		
		# 因子2：朝向评分（玩家面朝门越好，-1到1分）
		var to_door = (door_pos - player_pos).normalized()
		to_door.y = 0  # 只考虑水平方向
		if to_door.length() > 0.01:
			to_door = to_door.normalized()
		var forward_score = player_forward.dot(to_door)  # 点积：1=正对，-1=背对
		
		# 综合评分：距离权重0.6 + 朝向权重0.4
		# 朝向需要偏移到0-1范围
		var total_score = distance_score * 0.6 + (forward_score + 1.0) * 0.5 * 0.4
		
		print("门: ", door.name, " 距离: ", "%.2f" % distance, " 距离分: ", "%.2f" % distance_score, " 朝向分: ", "%.2f" % forward_score, " 总分: ", "%.2f" % total_score)
		
		if total_score > best_score:
			best_score = total_score
			best_door = door
	
	return best_door

# 检查玩家是否手持封门物品
func _player_holding_seal_item() -> bool:
	if not Global.player:
		return false
	
	var player_script = Global.player.get_script()
	if not player_script or not player_script.has_method("get_equipped_item"):
		return false
	
	var equipped_item = Global.player.get_equipped_item()
	if not equipped_item:
		return false
	
	return equipped_item.物品类型 == Item.Kind.SEAL_ITEM

# ========== 状态切换控制 ==========
# 统一入口：根据当前状态决定开门/关门/提示没钥匙
func try_toggle():
	# 玩家开门，使用玩家的开门方向
	last_side = player_last_side
	
	# 使用match语句根据当前状态执行不同逻辑
	# 初学者提示：match类似于switch语句，但在GDScript中更加强大
	match state:
		"OPENED":
			play_close()
		"NEED_KEY":
			if has_key_in_inventory():
				play_open()
			else:
				print("门：背包里没有钥匙 #", 所需钥匙ID)
		"CLOSED":
			play_open()

# 尝试开门（供怪物使用）
func try_open_door(caller: Node = null):
	# 递归锁，防止无限递归
	if _is_opening:
		return
	_is_opening = true
	
	# 检查交互冷却
	if interaction_cooldown > 0:
		_is_opening = false
		return
	
	# 如果门已经打开，不需要操作
	if state == "OPENED":
		_is_opening = false
		return
	
	# 如果门被封住（有木板），无法开门
	if is_sealed:
		print("门：门被封住，无法打开")
		_is_opening = false
		return
	
	# 如果需要钥匙
	if state == "NEED_KEY":
		# 如果是玩家在开门，检查背包是否有钥匙
		if caller and caller.is_in_group("player"):
			if not has_key_in_inventory():
				print("门：没有钥匙，无法打开")
				_is_opening = false
				return
		# 如果是怪物在开门，不需要检查钥匙，直接开门
		elif caller and caller.is_in_group("monster"):
			print("门：怪物尝试开门")
		else:
			# 未知调用者，检查背包
			if not has_key_in_inventory():
				print("门：没有钥匙，无法打开")
				_is_opening = false
				return
	
	# 如果是怪物开门，根据怪物的位置来决定门向哪边打开
	# 修复：直接根据怪物在门的哪一侧来决定开门方向，避免被玩家的last_side影响
	if caller and caller.is_in_group("monster"):
		# 计算门到怪物的方向向量
		var door_to_monster = (caller.global_position - global_position).normalized()
		door_to_monster.y = 0  # 只考虑水平方向
		
		# 获取门的朝向（假设门的正面是+Z方向）
		var door_forward = global_basis.z.normalized()
		
		# 计算门到怪物方向与门朝向的点积
		var dot_product = door_forward.dot(door_to_monster)
		
		# 如果点积大于0，说明怪物在门的"前方"，门应该向"后方"打开
		# 如果点积小于0，说明怪物在门的"后方"，门应该向"前方"打开
		if dot_product > 0:
			monster_last_side = 1.0   # 门向内开
		else:
			monster_last_side = -1.0  # 门向外开
		
		# 设置当前开门方向为怪物的开门方向
		last_side = monster_last_side
		
		print("门：怪物开门，门朝向: ", door_forward, " 门到怪物方向: ", door_to_monster, " 点积: ", dot_product, " 门向哪边开: ", last_side)
	
	# 尝试开门
	play_open()
	
	# 释放递归锁
	_is_opening = false

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
	_tween.tween_property(door_mesh, "rotation_degrees:y", default_rot.y + 开门角度 * last_side, 动画速度)
	# 动画完成后的回调函数
	_tween.tween_callback(func():
		is_animating = false
		door_opened.emit()   # 广播给外界（例如播放开门音效）
		# hide_prompt()        # 门开了就不需要提示了 - 已删除
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
	_tween.tween_property(door_mesh, "rotation_degrees:y", default_rot.y, 动画速度)
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
		player_last_side = 1.0      # 记录"从里侧"进入
		# show_prompt()        # 显示交互提示 - 已删除
	
	# 检查是否是怪物
	if body.is_in_group("monster"):
		monster_last_side = 1.0      # 记录"从里侧"进入

# 玩家进入外侧区域时调用
func _on_out_area_enter(body):
	# 检查是否是玩家
	if body.is_in_group("player"):
		player_last_side = -1.0     # 记录"从外侧"进入
		# show_prompt()        # 显示交互提示 - 已删除
	
	# 检查是否是怪物
	if body.is_in_group("monster"):
		monster_last_side = -1.0     # 记录"从外侧"进入

# 玩家离开任意区域时调用
func _on_area_exit(body):
	# 检查是否是玩家
	if body.is_in_group("player"):
		# hide_prompt()        # 隐藏交互提示 - 已删除
		# 检查是否真的离开了整个门的范围（因为有两个area，可能从in走到out）
		# 只有当两个区域都没有玩家时，才注销
		if not has_player():
			pass  # 不再需要注销逻辑
	
	# 检查是否是怪物
	if body.is_in_group("monster"):
		# 检查是否真的离开了整个门的范围
		if not has_monster():
			pass  # 不再需要注销逻辑

# 显示提示文字 - 已删除
# func show_prompt():
# 	# 已开门就不提示
# 	if state == "OPENED":
# 		return               
# 	prompt.modulate.a = 1.0  # 瞬间显示（设置透明度为1）
# 	prompt2.modulate.a = 1.0 # 另一面也显示
# 	update_prompt_with_seal()

# 隐藏提示文字 - 已删除
# func hide_prompt():
# 	prompt.modulate.a = 0.0  # 设置透明度为0（完全透明）
# 	prompt2.modulate.a = 0.0 # 另一面也隐藏

# ========== 工具函数 ==========
# 检查玩家是否在附近
func has_player() -> bool:
	# 任一区域有人就算"附近"
	return in_area.has_overlapping_bodies() or out_area.has_overlapping_bodies()

# 检查玩家是否靠近门（距离判定）
func is_player_nearby() -> bool:
	# 安全检查：确保全局玩家存在
	if not Global.player:
		return false
	
	# 计算玩家到门的距离
	var player_pos = Global.player.global_position
	var door_pos = global_position
	var distance = player_pos.distance_to(door_pos)
	
	# 设置最大允许距离（1.5米，玩家必须靠近门才能破坏）
	var max_distance = 1.5
	
	# 检查距离是否在允许范围内
	var is_nearby = distance <= max_distance
	print("玩家距离门: ", distance, "米，是否靠近: ", is_nearby)
	
	return is_nearby

func has_monster() -> bool:
	# 任一区域有怪物就算"附近"
	return in_area.has_overlapping_bodies() or out_area.has_overlapping_bodies()

# 检查玩家背包中是否有所需钥匙
func has_key_in_inventory() -> bool:
	# 如果钥匙ID为-1，表示无法开门
	if 所需钥匙ID == -1:
		print("门：门已被封住，无法打开")
		return false
	
	# 安全检查：确保全局玩家存在
	if not Global.player:
		return false
	# 背包是Player下的子节点，用get_node获取
	var inv = Global.player.get_node("inventory")
	# 检查背包是否存在并拥有所需钥匙
	return inv and inv.has_key(所需钥匙ID)

# ========== 封门功能 ==========

# 尝试封门
func try_seal_door():
	# 检查是否可以封门
	if not 可以封门 or is_sealed:
		return
	
	# 检查门是否关闭
	if state != "CLOSED":
		print("封门失败：门必须关闭才能封门")
		return
	
	# 检查玩家是否有封门物品
	if not has_seal_item_in_inventory():
		print("封门失败：缺少封门所需物品")
		return
	
	# 开始封门
	start_seal_door()

# 检查玩家是否有封门物品
func has_seal_item_in_inventory() -> bool:
	# 安全检查：确保全局玩家存在
	if not Global.player:
		return false
	
	# 获取玩家背包
	var inv = Global.player.get_node("inventory")
	if not inv:
		return false
	
	# 这里需要根据您的物品系统实现具体的检查逻辑
	# 暂时返回true用于测试
	return true

# 开始封门
func start_seal_door():
	is_sealed = true
	state = "NEED_KEY"  # 设置为需要钥匙状态
	所需钥匙ID = -1      # 设置为-1表示无法开门
	is_destroyed = false # 重置破坏标记，允许重新封门
	print("开始封门...")
	
	# 重置木板状态
	reset_plank_system()
	
	# 立即初始化木板耐久度
	initialize_plank_durability()
	
	# 播放木板动画
	play_plank_animation()

# ========== 手持物品封门功能 ==========

# 尝试使用手持物品封门
func try_seal_door_with_item():
	# 检查是否可以封门
	if not 可以封门 or is_sealed:
		return
	
	# 检查门是否关闭
	if state != "CLOSED":
		print("封门失败：门必须关闭才能封门")
		return
	
	# 调试模式：可以无条件封门（但仍需消耗物品）
	if 调试模式:
		print("调试模式：无条件封门")
		start_seal_door()
		# 调试模式下如果手持封门物品也消耗
		if is_holding_seal_item():
			_consume_seal_item()
		return
	
	# 检查玩家是否手持封门物品(SEAL_ITEM类型)
	if is_holding_seal_item():
		print("检测到封门物品，开始封门")
		start_seal_door()
		# 消耗手持的封门物品
		_consume_seal_item()
		return
	
	# 检查玩家是否手持消耗品（消耗品不能封门）
	if is_holding_consumable():
		print("封门失败：当前手持的是消耗品，无法封门")
		return
	
	# 其他物品也不能封门
	print("封门失败：需要手持封门物品(木板)")

# 检查玩家是否手持封门物品
func has_seal_item_in_hand() -> bool:
	# 去掉必须手持木板的限制，直接返回true
	return true

# 检查玩家是否手持消耗品（不能封门）
func is_holding_consumable() -> bool:
	# 安全检查：确保全局玩家存在
	if not Global.player:
		return false
	
	# 检查玩家是否装备了物品
	var player_script = Global.player.get_script()
	if not player_script or not player_script.has_method("get_equipped_item"):
		return false
	
	var equipped_item = Global.player.get_equipped_item()
	if not equipped_item:
		return false
	
	# 检查物品是否为消耗品（消耗品不能封门）
	# 封门物品(SEAL_ITEM)是例外，可以用于封门
	if equipped_item.物品类型 == Item.Kind.CONSUMABLE:
		return true
	
	return false

# 检查玩家是否手持封门物品
func is_holding_seal_item() -> bool:
	# 安全检查：确保全局玩家存在
	if not Global.player:
		return false
	
	# 检查玩家是否装备了物品
	var player_script = Global.player.get_script()
	if not player_script or not player_script.has_method("get_equipped_item"):
		return false
	
	var equipped_item = Global.player.get_equipped_item()
	if not equipped_item:
		return false
	
	# 检查物品是否为封门物品类型
	return equipped_item.物品类型 == Item.Kind.SEAL_ITEM

# 消耗封门物品（封门后从背包移除木板）
func _consume_seal_item() -> void:
	if not Global.player:
		return
	
	var inv = Global.player.get_node("inventory")
	if not inv:
		return
	
	var equipped_item = Global.player.get_equipped_item()
	if not equipped_item:
		return
	
	# 找到物品在背包中的索引
	var item_index = -1
	for i in range(inv.items.size()):
		var entry = inv.items[i]
		if entry and entry.has("item") and entry.item == equipped_item:
			item_index = i
			break
	
	if item_index == -1:
		print("警告: 无法在背包中找到封门物品")
		return
	
	# 移除物品
	inv.remove_item(item_index)
	
	# 卸下物品
	if Global.player.has_method("unequip_item"):
		Global.player.unequip_item()
	
	print("封门物品已消耗并从背包移除")

# 消耗手持物品
func consume_hand_item() -> void:
	# 安全检查：确保全局玩家存在
	if not Global.player:
		return
	
	# 获取玩家背包
	var inv = Global.player.get_node("inventory")
	if not inv:
		return
	
	# 查找当前装备的物品在背包中的索引
	var equipped_item = Global.player.get_equipped_item()
	if not equipped_item:
		return
	
	var item_index = -1
	for i in range(inv.items.size()):
		var entry = inv.items[i]
		if entry and entry.has("item") and entry.item == equipped_item:
			item_index = i
			break
	
	if item_index == -1:
		print("警告: 无法在背包中找到当前装备的物品")
		return
	
	# 移除物品
	inv.remove_item(item_index)
	
	# 卸下物品
	if Global.player.has_method("unequip_item"):
		Global.player.unequip_item()

# 播放木板动画
func play_plank_animation():
	# 确保记录完整的初始位置
	record_initial_plank_positions()
	
	# 重置所有木板的位置和旋转状态（确保木板回到原位并可见）
	reset_planks_state()
	
	# 创建动画序列
	var tween = create_tween()
	tween.set_parallel(false)  # 串行执行，实现从上到下一块一块封
	
	# 为每块木板添加动画
	var plank_count = out_planks.get_child_count()
	
	# 按从上到下的顺序排列木板（根据Y轴位置）
	var out_planks_sorted = []
	var in_planks_sorted = []
	
	# 收集所有木板
	for i in range(plank_count):
		out_planks_sorted.append(out_planks.get_child(i))
		in_planks_sorted.append(in_planks.get_child(i))
	
	# 按Y轴位置从高到低排序（从上到下）
	out_planks_sorted.sort_custom(func(a, b): return a.position.y > b.position.y)
	in_planks_sorted.sort_custom(func(a, b): return a.position.y > b.position.y)
	
	for i in range(plank_count):
		# 获取排序后的木板
		var out_plank = out_planks_sorted[i]
		var in_plank = in_planks_sorted[i]
		
		# 获取完整的初始位置
		var out_start_pos = Vector3(
			out_plank.get_meta("initial_x", out_plank.position.x),
			out_plank.get_meta("initial_y", out_plank.position.y),
			out_plank.get_meta("initial_z", out_plank.position.z)
		)
		var in_start_pos = Vector3(
			in_plank.get_meta("initial_x", in_plank.position.x),
			in_plank.get_meta("initial_y", in_plank.position.y),
			in_plank.get_meta("initial_z", in_plank.position.z)
		)
		
		# 设置初始位置（从不同方向0.5米处出现）
		out_plank.position.z = out_start_pos.z - 0.5  # 从前方0.5米处
		out_plank.visible = true
		
		in_plank.position.z = in_start_pos.z + 0.5  # 从后方0.5米处
		in_plank.visible = true
		
		# 添加动画延迟，实现从上到下一块一块移动的效果
		tween.tween_interval(i * 木板动画间隔)
		
		# 外侧木板移动到原来的位置
		tween.tween_property(out_plank, "position", out_start_pos, 木板动画速度)
		
		# 内侧木板移动到原来的位置
		tween.tween_property(in_plank, "position", in_start_pos, 木板动画速度)
	
	# 动画完成后的回调
	tween.tween_callback(func():
		print("封门完成！")
		disable_door_interaction()
	)

# 隐藏所有木板
func hide_all_planks():
	for plank in out_planks.get_children():
		plank.visible = false
	for plank in in_planks.get_children():
		plank.visible = false

# 显示所有木板（用于测试）
func show_all_planks():
	for plank in out_planks.get_children():
		plank.visible = true
	for plank in in_planks.get_children():
		plank.visible = true

# 重置所有木板的位置和旋转状态
func reset_planks_state():
	# 重置外侧木板
	for plank in out_planks.get_children():
		plank.rotation_degrees = Vector3.ZERO  # 重置旋转
		# 重置位置到完整初始状态（包括X、Y、Z轴）
		plank.position = Vector3(
			plank.get_meta("initial_x", plank.position.x),
			plank.get_meta("initial_y", plank.position.y),
			plank.get_meta("initial_z", plank.position.z)
		)
		if not plank.has_meta("initial_x"):
			plank.set_meta("initial_x", plank.position.x)
		if not plank.has_meta("initial_y"):
			plank.set_meta("initial_y", plank.position.y)
		if not plank.has_meta("initial_z"):
			plank.set_meta("initial_z", plank.position.z)
		plank.visible = true  # 重置可见性
	
	# 重置内侧木板
	for plank in in_planks.get_children():
		plank.rotation_degrees = Vector3.ZERO  # 重置旋转
		# 重置位置到完整初始状态（包括X、Y、Z轴）
		plank.position = Vector3(
			plank.get_meta("initial_x", plank.position.x),
			plank.get_meta("initial_y", plank.position.y),
			plank.get_meta("initial_z", plank.position.z)
		)
		if not plank.has_meta("initial_x"):
			plank.set_meta("initial_x", plank.position.x)
		if not plank.has_meta("initial_y"):
			plank.set_meta("initial_y", plank.position.y)
		if not plank.has_meta("initial_z"):
			plank.set_meta("initial_z", plank.position.z)
		plank.visible = true  # 重置可见性
	
	print("木板状态已重置")

# 禁用门交互
func disable_door_interaction():
	# 禁用门的交互功能
	print("门交互已禁用")

# 启用门交互
func enable_door_interaction():
	# 启用门的交互功能
	is_sealed = false
	state = "CLOSED"  # 恢复为关闭状态
	所需钥匙ID = 1     # 恢复默认钥匙ID
	
	# 设置交互冷却，防止怪物立即重新开门
	interaction_cooldown = interaction_cooldown_duration
	
	# 门已被破坏，但节点保留，允许再次封门
	is_destroyed = true
	
	print("门交互已启用，冷却时间: ", interaction_cooldown_duration, " 秒")
	
	# 注意：不再立即隐藏木板，因为可能还有动画正在进行
	# 木板会在各自的动画完成后自动隐藏

# 记录木板的初始位置
func record_initial_plank_positions():
	# 记录外侧木板的初始位置
	for plank in out_planks.get_children():
		if not plank.has_meta("initial_x"):
			plank.set_meta("initial_x", plank.position.x)
		if not plank.has_meta("initial_y"):
			plank.set_meta("initial_y", plank.position.y)
		if not plank.has_meta("initial_z"):
			plank.set_meta("initial_z", plank.position.z)
	
	# 记录内侧木板的初始位置
	for plank in in_planks.get_children():
		if not plank.has_meta("initial_x"):
			plank.set_meta("initial_x", plank.position.x)
		if not plank.has_meta("initial_y"):
			plank.set_meta("initial_y", plank.position.y)
		if not plank.has_meta("initial_z"):
			plank.set_meta("initial_z", plank.position.z)
	
	print("木板初始位置已记录")

# 重置木板系统状态
func reset_plank_system():
	# 重置当前木板索引
	current_plank_index = 0
	
	# 重置门耐久度，下次使用时重新初始化
	current_door_hp = 0
	
	# 重置所有木板的位置和旋转状态
	reset_planks_state()
	
	print("木板系统状态已重置")

# 更新提示文字（考虑封门状态）- 已删除提示文本，保留UI状态更新
func update_prompt_with_seal():
	# 如果钥匙ID为-1，显示门已封住
	if 所需钥匙ID == -1:
		# 检查玩家是否有斧头，如果有则显示劈砍提示
		if has_axe_in_inventory():
			# prompt.text = "左键 劈砍" - 已删除
			# prompt2.text = "左键 劈砍" - 已删除
			# 更新UI状态文本：显示"需要斧头"
			update_ui_door_status("需要斧头")
		else:
			# prompt.text = "门已封住" - 已删除
			# prompt2.text = "门已封住" - 已删除
			# 更新UI状态文本：显示"门已封住"
			update_ui_door_status("门已封住")
		return
	
	# 如果门可以封门且未封，检查玩家是否手持木板
	if 可以封门 and not is_sealed and state == "CLOSED":
		if has_seal_item_in_hand():
			# prompt.text = "右键 封门" - 已删除
			# prompt2.text = "右键 封门" - 已删除
			# 更新UI状态文本：显示"右键 封门"
			update_ui_door_status("右键 封门")
		else:
			# 不需要显示"需要木板"提示，直接返回
			# 清除UI状态文本
			update_ui_door_status("")
			return
		return
	
	# 原有的提示逻辑
	if state == "OPENED":
		# 门可以打开时，清除UI状态文本
		update_ui_door_status("")
		return               
	
	# 更新UI状态文本
	if state == "NEED_KEY":
		update_ui_door_status("门上锁")
	else:
		# 门可以打开时，清除UI状态文本
		update_ui_door_status("")

# 更新UI门状态显示
func update_ui_door_status(状态: String):
	# 安全检查：确保全局UI存在
	if not Global.ui:
		return
	
	# 检查UI是否有显示门状态的方法
	if Global.ui.has_method("显示门状态"):
		Global.ui.显示门状态("门", 状态)
	else:
		# 备用方案：直接设置状态文本
		Global.ui.更新状态文本显示(状态)

# ========== 斧头劈砍功能 ==========

# 尝试劈砍木板
func try_chop_planks() -> bool:
	# 检查门是否已封
	if not is_sealed:
		print("劈砍失败：门未封")
		return false
	
	# 检查玩家是否有斧头
	if not has_axe_in_inventory():
		print("劈砍失败：需要斧头")
		return false
	
	# 检查玩家是否靠近门（距离判定）
	if not is_player_nearby():
		print("劈砍失败：玩家距离门太远")
		return false
	
	# 开始劈砍木板
	start_chop_plank()
	return true

# 检查玩家是否有斧头
func has_axe_in_inventory() -> bool:
	# 安全检查：确保全局玩家存在
	if not Global.player:
		print("斧头检测失败：全局玩家不存在")
		return false
	
	# 检查玩家是否装备了斧头
	if not Global.player.has_method("has_axe"):
		print("斧头检测失败：玩家节点没有has_axe方法")
		return false
	
	var has_axe = Global.player.has_axe()
	print("斧头检测结果：", has_axe)
	return has_axe

# 使用斧头（减少耐久度）
func use_axe() -> bool:
	# 安全检查：确保全局玩家存在
	if not Global.player:
		return false
	
	# 获取玩家背包
	var inv = Global.player.get_node("inventory")
	if not inv:
		return false
	
	# 检查玩家是否装备了斧头
	if not has_axe_in_inventory():
		return false
	
	# 获取当前装备的斧头
	var axe_item = Global.player.current_equipped_item
	if not axe_item:
		return false
	
	# 减少斧头耐久度
	if axe_item.has_method("reduce_durability"):
		# 如果斧头有耐久度系统，减少耐久度
		return axe_item.reduce_durability(1)
	elif "耐久度" in axe_item:
		# 如果斧头有耐久度属性，直接减少
		if axe_item.耐久度 > 0:
			axe_item.耐久度 -= 1
			print("斧头耐久度减少1次，剩余", axe_item.耐久度, "次")
			return axe_item.耐久度 > 0
		else:
			print("斧头已损坏，无法使用")
			return false
	else:
		# 如果没有耐久度系统，默认可以无限使用
		print("使用斧头劈砍")
		return true

# 开始劈砍木板
func start_chop_plank():
	# 检查斧头耐久度
	if not use_axe():
		print("劈砍失败：斧头已损坏或无法使用")
		return
	
	# 重置劈砍冷却时间（已注释掉，允许快速连续劈砍）
	# reset_chop_cooldown()
	
	# 初始化门耐久度（如果未初始化）
	if current_door_hp <= 0:
		initialize_plank_durability()
	
	# 直接执行劈砍逻辑，斧头动画由玩家攻击系统触发
	execute_chop_logic()

# 初始化木板耐久度
func initialize_plank_durability():
	current_door_hp = 门总耐久度
	print("门耐久度初始化完成，总耐久: ", current_door_hp, "，现有木板: ", out_planks.get_child_count())

# 执行劈砍逻辑 (重写版)
func execute_chop_logic():
	# 防止重入锁，避免怪物和玩家同时攻击
	if is_executing_chop:
		return
	
	# 门已被破坏，直接忽略后续攻击
	if is_destroyed:
		is_executing_chop = false
		return
	
	is_executing_chop = true
	
	# 1. 检查是否已经砍完了
	if current_door_hp <= 0:
		is_executing_chop = false
		return

	# 2. 扣除耐久度
	current_door_hp -= 1
	print("劈砍成功！剩余耐久: ", current_door_hp)
	
	# 3. 计算【截止到现在】应该一共掉落多少块木板
	var total_planks_count = out_planks.get_child_count() # 获取木板总数 (比如 6)
	var damage_taken = 门总耐久度 - current_door_hp        # 已经受到的伤害 (比如 1)
	
	# 公式：目标掉落数 = 总木板数 * (已受伤害 / 总血量)
	# 例如：6 * (1 / 3) = 2.0 -> 取整为 2
	var target_drop_count = int(float(total_planks_count) * float(damage_taken) / float(门总耐久度))
	
	# 特殊处理：如果是最后一刀，强制让所有剩余木板都掉落（防止除法小数误差）
	if current_door_hp <= 0:
		target_drop_count = total_planks_count

	# 4. 循环掉落：从当前索引一直掉落到目标索引
	# 比如当前 index 是 0，目标是 2，那么 index 0 和 1 的木板都会掉下去
	while current_plank_index < target_drop_count:
		# 播放当前这块木板的掉落动画
		play_synchronized_plank_animation(current_plank_index)
		
		# 只有第一块播放震动特效，或者每块都震动，看你喜好
		# play_chop_effect(current_plank_index)
		
		current_plank_index += 1
		
		# 小细节：如果是同时掉落多块，稍微加一点点延迟，不要像机器一样完全同步
		# 这里没有 await，因为我们希望视觉上几乎同时但有层次感
	
	# 5. 播放一次通用的劈砍音效/震动（不管掉几块，反正斧头砍上去了）
	if current_plank_index > 0:
		play_chop_effect(current_plank_index - 1)

	# 6. 检查门是否开启
	if current_door_hp <= 0:
		print("门已被破坏！")
		enable_door_interaction()
	
	# 释放重入锁
	is_executing_chop = false

# 播放劈砍效果
func play_chop_effect(plank_index: int):
	# 这里可以添加劈砍的音效、粒子效果等
	print("播放劈砍效果，木板索引: ", plank_index)
	
	# 简单的视觉反馈：让木板轻微震动
	var out_plank = out_planks.get_child(plank_index)
	var in_plank = in_planks.get_child(plank_index)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 外侧木板震动效果
	tween.tween_property(out_plank, "position:z", out_plank.position.z - 0.05, 0.1)
	tween.tween_property(out_plank, "position:z", out_plank.position.z, 0.1)
	
	# 内侧木板震动效果
	tween.tween_property(in_plank, "position:z", in_plank.position.z + 0.05, 0.1)
	tween.tween_property(in_plank, "position:z", in_plank.position.z, 0.1)

# 破坏木板
func destroy_plank(plank_index: int):
	print("木板 #", plank_index, " 已被破坏")
	
	var out_plank = out_planks.get_child(plank_index)
	var in_plank = in_planks.get_child(plank_index)
	
	# 在新的门总耐久度系统中，不需要单独标记木板破坏状态
	# 木板掉落由current_door_hp和current_plank_index控制
	
	# 添加到动画队列而不是直接播放
	add_to_animation_queue(func():
		# 记录动画开始前的状态
		print("动画开始前 - 外侧木板可见性:", out_plank.visible, " 位置Y:", out_plank.position.y)
		print("动画开始前 - 内侧木板可见性:", in_plank.visible, " 位置Y:", in_plank.position.y)
		
		# 播放木板掉落动画（该函数会在动画完成后自动隐藏木板）
		play_plank_fall_animation(out_plank, in_plank)
		
		print("木板 #", plank_index, " 动画播放完成")
	)

# 添加动画到队列（修改为立即执行，允许同步播放）
func add_to_animation_queue(animation_func):
	# 立即执行动画，允许同步播放（多线程效果）
	animation_func.call()
	
	# 注释掉原来的队列逻辑
	# animation_queue.append(animation_func)
	# if not is_animation_playing:
	# 	process_animation_queue()

# 处理动画队列
func process_animation_queue():
	if animation_queue.is_empty():
		is_animation_playing = false
		return
	
	is_animation_playing = true
	var next_animation = animation_queue.pop_front()
	
	# 延迟一帧执行，确保动画真正按顺序播放
	await get_tree().process_frame
	next_animation.call()

# 检查是否可以劈砍
func can_chop() -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	return current_time - 上次劈砍时间 >= 劈砍冷却时间

# 重置劈砍冷却时间
func reset_chop_cooldown():
	上次劈砍时间 = Time.get_ticks_msec() / 1000.0

# 播放木板掉落动画
func play_plank_fall_animation(out_plank, in_plank):
	print("开始播放木板掉落动画")
	
	# 记录动画开始时的状态
	print("动画开始时 - 外侧木板可见性:", out_plank.visible, " 位置Y:", out_plank.position.y)
	print("动画开始时 - 内侧木板可见性:", in_plank.visible, " 位置Y:", in_plank.position.y)
	
	# 确保木板在动画开始时是可见的
	out_plank.visible = true
	in_plank.visible = true
	
	var tween = create_tween()
	
	# 1. 设置为并行模式，让两个木板同时掉落
	tween.set_parallel(true)
	
	# 外侧木板掉落动画：显著向下移动（大幅增加移动距离和动画时间）
	tween.tween_property(out_plank, "position:y", out_plank.position.y - 5.0, 1.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# 内侧木板掉落动画：显著向下移动（大幅增加移动距离和动画时间）
	tween.tween_property(in_plank, "position:y", in_plank.position.y - 5.0, 1.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# 2. 关键修复：使用chain()等待之前的并行动画完成
	tween.chain().tween_callback(func():
		print("动画完成前 - 外侧木板可见性:", out_plank.visible, " 位置Y:", out_plank.position.y)
		print("动画完成前 - 内侧木板可见性:", in_plank.visible, " 位置Y:", in_plank.position.y)
		
		out_plank.visible = false
		in_plank.visible = false
		
		print("动画完成后 - 外侧木板可见性:", out_plank.visible, " 位置Y:", out_plank.position.y)
		print("动画完成后 - 内侧木板可见性:", in_plank.visible, " 位置Y:", in_plank.position.y)
		print("木板掉落完成")
		
		# 动画完成后处理队列中的下一个动画（已注释掉，改为同步播放）
		# process_animation_queue()
	)

# 播放木板动画（根据耐久度逐步播放）
func play_synchronized_plank_animation(plank_index: int):
	print("播放木板动画 #", plank_index)
	
	var out_plank = out_planks.get_child(plank_index)
	var in_plank = in_planks.get_child(plank_index)
	
	# 播放当前木板的掉落动画
	play_plank_fall_animation(out_plank, in_plank)
	
	print("木板 #", plank_index, " 动画播放完成")
