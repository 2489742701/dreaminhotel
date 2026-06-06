@tool
extends CharacterBody3D

# 怪物基础属性
@export var 移动速度: float = 3.0
@export var 加速度: float = 10.0
@export var 摩擦力: float = 10.0

# 重力设置
@export var 重力: float = 30.0
@export var 最大下落速度: float = 50.0

# 追击设置
@export var 追击距离: float = 5.0
@export var 追击速度: float = 3.0
@export var 失去目标距离: float = 20.0
@export var 追击模式: bool = true
@export var avoidance_enabled: bool = false

# 门攻击系统
var nearby_doors: Array = []  # 附近的门列表
var nearby_door: Node = null
var door_attack_cooldown: float = 0.0
var door_attack_cooldown_duration: float = 2.0
var is_attacking_door: bool = false

# 活动范围设置
@export var 启用活动范围: bool = false
@export var 活动范围中心: Vector3 = Vector3.ZERO
@export var 活动半径: float = 10.0

# 巡逻模式设置
@export var 巡逻模式: bool = true  # false=随机寻路, true=巡逻点
@export var 巡逻点节点路径: NodePath = "../PatrolPoints"  # 巡逻点容器的节点路径

# 调试设置
@export var 启用调试信息: bool = true
@export var 启用调试绘制: bool = true
@export var 启用移动方向调试: bool = false

# 状态枚举
# 注意：NAVIGATION状态用于追击后回归巡逻点，此时需要扫门攻击
# 性能优化：只在追击和回归时扫门，避免巡逻模式下持续扫门导致性能低下
enum State { IDLE, WANDER, CHASE, NAVIGATION }

# 移动相关变量
var current_state: State = State.IDLE
var target_position: Vector3
var wander_timer: float = 0.0
var wander_interval: float = 3.0

# 随机方向移动系统
var move_direction_timer: float = 0.0
var move_direction_interval: float = 1.0
var current_move_direction: Vector3 = Vector3.ZERO

# 巡逻点系统
var patrol_points: Array[Node3D] = []  # 巡逻点节点数组
var current_patrol_index: int = 0  # 当前巡逻点索引
var patrol_points_container: Node = null  # 巡逻点容器节点
var patrol_forward: bool = true  # true=正向(0->End), false=反向(End->0)
var patrol_wait_timer: float = 0.0  # 巡逻点等待计时器
var patrol_wait_duration: float = 2.0  # 巡逻点等待持续时间
var is_waiting_at_patrol: bool = false  # 是否正在巡逻点等待

# 追击系统
var chase_timer: float = 0.0
@export var chase_duration: float = 12.0
var was_chasing: bool = false  # 标记是否刚刚从追击状态切换回来

# 动画相关
@onready var animation_player: AnimationPlayer = get_node("MobA/AnimationPlayer")
@onready var skeleton: Skeleton3D = get_node("MobA/Skeleton3D")
@onready var navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D")

# 视线检测
@onready var vision_ray: RayCast3D = get_node("MobA/Skeleton3D/Ch36/RayCast3D")

# 导航区域
var navigation_region: NavigationRegion3D = null
var scene_boundary_timer: float = 0.0
var scene_boundary_check_interval: float = 1.0
var outside_scene_timer: float = 0.0
var outside_scene_timeout: float = 5.0
var is_outside_scene: bool = false

# 回到场景内后的稳定时间
var back_to_scene_timer: float = 0.0
var back_to_scene_duration: float = 3.0
var pause_random_direction: bool = false

# 追击冷却
var chase_cooldown_timer: float = 0.0
var chase_cooldown_duration: float = 3.0

# 卡住检测
var stuck_timer: float = 0.0
var stuck_timeout: float = 3.0
var last_position: Vector3 = Vector3.ZERO
var is_stuck: bool = false

# 回到导航点标记
var is_returning_to_patrol: bool = false

func _ready():
	target_position = global_position
	
	# 添加到monster分组，让门能够检测到怪物
	add_to_group("monster")
	
	# 防止视线检测射到自己
	if vision_ray:
		vision_ray.add_exception(self)
	
	setup_navigation_agent()
	find_navigation_region()
	
	# 等待导航地图同步完成后再开始巡逻
	if navigation_agent:
		var map = navigation_agent.get_navigation_map()
		var initial_iteration = NavigationServer3D.map_get_iteration_id(map)
		
		# 如果地图尚未同步，等待同步完成
		if initial_iteration == 0:
			navigation_agent.get_tree().create_timer(0.1).timeout.connect(_delayed_start_wander)
		else:
			_delayed_start_wander()
	else:
		_delayed_start_wander()

func find_navigation_region():
	var root = get_tree().current_scene
	if not root:
		return
	
	# 查找场景中的 NavigationRegion3D
	var regions = root.find_children("*", "", true, false)
	for node in regions:
		if node is NavigationRegion3D:
			navigation_region = node
			return

func _delayed_start_wander():
	setup_patrol_points()
	change_state(State.WANDER)

func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity

func setup_navigation_agent():
	# 注释掉导航代理设置，改用直接移动（只看XZ平面）
	# 原因：导航代理可能导致怪物无法移动，中心点位置问题
	# 
	# if not navigation_agent:
	# 	return
	# 
	# # 基础导航设置
	# navigation_agent.path_desired_distance = 0.1
	# navigation_agent.target_desired_distance = 0.1
	# navigation_agent.path_max_distance = 3.0
	# 
	# # 避障设置
	# var use_avoidance = avoidance_enabled
	# navigation_agent.avoidance_enabled = use_avoidance
	# navigation_agent.radius = 0.5
	# navigation_agent.neighbor_distance = 5.0
	# navigation_agent.max_neighbors = 10
	# navigation_agent.time_horizon = 0.5
	# navigation_agent.max_speed = 追击速度
	# 
	# # 连接速度计算信号（仅在启用避障时）
	# if use_avoidance:
	# 	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	
	print("[Monster] 导航代理已禁用，使用直接移动模式（只看XZ平面）")

func setup_patrol_points():
	print("[Monster] setup_patrol_points() 被调用")
	print("[Monster] 巡逻模式: ", 巡逻模式)
	print("[Monster] 巡逻点节点路径: ", 巡逻点节点路径)
	
	if not 巡逻模式:
		print("[Monster] 巡逻模式未启用，跳过巡逻点设置")
		return
	
	if 巡逻点节点路径.is_empty():
		print("[Monster] 巡逻点节点路径为空")
		return
	
	patrol_points_container = get_node_or_null(巡逻点节点路径)
	if not patrol_points_container:
		print("[Monster] 未找到巡逻点容器节点: ", 巡逻点节点路径)
		return
	
	print("[Monster] 找到巡逻点容器: ", patrol_points_container.name)
	print("[Monster] 容器子节点数量: ", patrol_points_container.get_child_count())
	
	patrol_points.clear()
	for child in patrol_points_container.get_children():
		print("[Monster] 检查子节点: ", child.name, ", 类型: ", child.get_class(), ", 是否为Node3D: ", child is Node3D)
		if child is Node3D:
			patrol_points.append(child)
	
	print("[Monster] 找到 ", patrol_points.size(), " 个巡逻点")
	
	if patrol_points.size() > 0:
		current_patrol_index = 0
		# 延迟设置目标位置，确保所有节点都已加入场景树
		call_deferred("_set_initial_patrol_target")
		print("[Monster] 将在下一帧设置初始目标为巡逻点 ", current_patrol_index)

func _set_initial_patrol_target():
	if patrol_points.size() > 0 and current_patrol_index < patrol_points.size():
		var target = patrol_points[current_patrol_index]
		if target and target.is_inside_tree():
			target_position = target.global_position
			print("[Monster] 设置初始目标为巡逻点 ", current_patrol_index, " 位置: ", target_position)
		else:
			print("[Monster] 警告: 巡逻点尚未加入场景树，使用当前位置")
			target_position = global_position

func _process(_delta):
	pass

func _physics_process(delta):
	# 在编辑器中不运行AI逻辑
	if Engine.is_editor_hint():
		return
	
	# 卡住检测 - 已关闭
	# if last_position == Vector3.ZERO:
	# 	last_position = global_position
	# else:
	# 	var distance_moved = global_position.distance_to(last_position)
	# 	if distance_moved < 0.01:
	# 		stuck_timer += delta
	# 	else:
	# 		stuck_timer = 0.0
	# 		is_stuck = false
	# 	last_position = global_position
	# 	
	# 	# 如果卡住超时，传送回导航区域
	# 	if stuck_timer >= stuck_timeout:
	# 		print("[Monster] 卡住超时，传送回导航区域")
	# 		teleport_back_to_scene()
	# 		stuck_timer = 0.0
	# 		is_stuck = false
	
	if 追击模式:
		check_and_chase_player(delta)
	
	# 检查是否跑离场景
	scene_boundary_timer += delta
	if scene_boundary_timer >= scene_boundary_check_interval:
		check_scene_boundary()
		scene_boundary_timer = 0.0
	
	# 检测和攻击门 - 只在追击状态或回到导航点时检查，且不在等待时
	var can_attack_door = (current_state == State.CHASE or is_returning_to_patrol)
	if can_attack_door and not is_waiting_at_patrol:
		door_attack_cooldown -= delta
		if door_attack_cooldown <= 0:
			check_and_attack_door()
	
	# 应用重力
	if not is_on_floor():
		velocity.y -= 重力 * delta
		velocity.y = max(velocity.y, -最大下落速度)
	
	handle_movement(delta)
	handle_animation()
	
	if current_state == State.WANDER:
		update_wander_timer(delta)

func change_state(new_state: State):
	if current_state == new_state:
		return
	
	# 如果是从追击变成巡逻，切换到寻路状态（回归状态）
	if current_state == State.CHASE and new_state == State.WANDER:
		was_chasing = true  # 标记刚刚从追击状态切换回来
		is_returning_to_patrol = true  # 标记正在回到导航点
		find_nearest_patrol_point()
		# 切换到寻路状态，使用导航代理进行避障
		current_state = State.NAVIGATION
		return
	
	# 如果从巡逻变成追击，清除追击标记
	if current_state == State.WANDER and new_state == State.CHASE:
		was_chasing = false
		is_returning_to_patrol = false  # 追击时不再回到导航点
	
	current_state = new_state
	
	match current_state:
		State.IDLE:
			pass
		State.WANDER:
			start_wander()
		State.CHASE:
			# 立即清除"正在回防"的标记，防止逻辑冲突
			is_returning_to_patrol = false
			
			# 注释掉导航代理相关代码
			# # 强制刷新导航目标，防止路径数据过期
			# if Global.player and navigation_agent:
			# 	navigation_agent.set_target_position(Global.player.global_position)
		State.NAVIGATION:
			# 寻路状态：直接朝向巡逻点移动（不使用导航代理）
			# 注释原因：导航代理可能导致怪物无法移动，中心点位置问题
			pass

func handle_movement(delta):
	# 处理怪物的移动逻辑，包括速度计算、碰撞检测和方向控制
	# 这个函数是怪物移动的核心，根据当前状态（IDLE/WANDER/CHASE）决定如何移动
	
	# 如果怪物正在攻击门，停止移动
	if is_attacking_door:
		velocity = velocity.move_toward(Vector3.ZERO, 摩擦力 * delta)
		move_and_slide()
		return
	
	# 如果怪物处于空闲状态，减速并停止
	if current_state == State.IDLE:
		# 使用摩擦力逐渐减速到零
		velocity = velocity.move_toward(Vector3.ZERO, 摩擦力 * delta)
		move_and_slide()
		return
	
	# 初始化移动方向和速度
	var move_direction: Vector3 = Vector3.ZERO
	# 根据状态选择速度：追击状态使用追击速度，否则使用普通移动速度
	var current_speed = 追击速度 if current_state == State.CHASE else 移动速度
	
	# 根据状态获取移动方向
	if current_state == State.WANDER:
		# 巡逻状态：使用巡逻点方向（沿着预设的巡逻点移动）
		if 巡逻模式:
			move_direction = get_patrol_direction(delta)
		else:
			# 如果没有巡逻模式，使用随机方向
			move_direction = get_wander_direction(delta)
	elif current_state == State.CHASE:
		# 追击状态：使用追击方向（朝向玩家）
		move_direction = get_chase_direction()
		print("[Monster] 追击状态 - 移动方向: ", move_direction, " 速度: ", current_speed)
	elif current_state == State.NAVIGATION:
		# 寻路状态：使用导航代理进行避障
		move_direction = get_navigation_direction()
		print("[Monster] 寻路状态 - 移动方向: ", move_direction, " 速度: ", current_speed)
	
	# 计算目标速度
	var target_velocity = Vector3.ZERO
	
	# 如果有有效的移动方向（长度大于0.1）
	if move_direction.length() > 0.1:
		# 计算目标速度 = 移动方向 * 当前速度
		target_velocity = move_direction * current_speed
		
		# 直接设置水平速度（x和z），保留垂直速度（y，用于重力）
		velocity.x = target_velocity.x
		velocity.z = target_velocity.z
	else:
		# 没有有效的移动方向时，停止移动
		# 清空水平速度，保留垂直速度（y，用于重力）
		velocity.x = 0
		velocity.z = 0
	
	# 旋转怪物朝向移动方向（如果有有效方向）
	if move_direction.length() > 0.1:
		rotate_toward_direction(move_direction, delta)
	
	# 执行移动并检测碰撞
	var collision = move_and_slide()
	
	# 检测是否卡死：在追击状态下速度接近0
	if current_state == State.CHASE:
		var horizontal_speed = Vector2(velocity.x, velocity.z).length()
		if horizontal_speed < 0.1:
			print("[Monster] 卡死警告 - 追击状态下速度接近0: ", horizontal_speed, " 移动方向: ", move_direction)
	
	# 检测是否撞墙（如果发生碰撞）
	if collision and collision is KinematicCollision3D:
		# 获取碰撞法线（碰撞面的法向量）
		var collision_normal = collision.get_normal()
		collision_normal.y = 0
		
		# 计算反方向（当前移动方向的相反方向）
		var reverse_direction = -current_move_direction
		reverse_direction.y = 0
		
		# 如果反方向与碰撞法线方向一致（点积大于0），使用法线方向
		# 这样可以避免怪物沿着墙壁滑动
		if reverse_direction.dot(collision_normal) > 0:
			current_move_direction = collision_normal.normalized()
		else:
			current_move_direction = reverse_direction.normalized()

func get_wander_direction(delta: float) -> Vector3:
	# 获取巡逻状态的移动方向
	# 根据巡逻模式选择不同的移动方式
	# 
	# 参数:
	#   delta: 上一帧的时间间隔（秒）
	# 
	# 返回:
	#   Vector3: 移动方向（归一化的向量）
	
	# 直接使用巡逻点寻路系统
	return get_patrol_direction(delta)

func get_random_wander_direction(delta: float) -> Vector3:
	# 只有在刚刚从追击状态切换回来时，才强制返回向导航区域的方向
	# 正常巡逻模式下，允许怪物在导航区域外活动
	if is_outside_scene and was_chasing and navigation_region:
		var map_rid = navigation_region.get_navigation_map()
		var closest_point = NavigationServer3D.map_get_closest_point(map_rid, global_position)
		var direction_to_nav = (closest_point - global_position).normalized()
		direction_to_nav.y = 0
		if direction_to_nav.length() > 0.1:
			# 保存向导航区域的方向，回到场景内后保持这个方向
			current_move_direction = direction_to_nav
			return direction_to_nav
		return Vector3.ZERO
	
	# 如果暂停随机方向，不改变方向
	if pause_random_direction:
		back_to_scene_timer += delta
		if back_to_scene_timer >= back_to_scene_duration:
			pause_random_direction = false
			back_to_scene_timer = 0.0
		return current_move_direction
	
	# 更新方向计时器
	move_direction_timer += delta
	
	# 每隔一段时间改变方向
	if move_direction_timer >= move_direction_interval or current_move_direction == Vector3.ZERO:
		generate_random_direction()
		move_direction_timer = 0.0
	
	return current_move_direction

func generate_random_direction():
	# 生成随机方向，包括反方向和侧方向
	var random_angle = randf_range(0, 360)
	var random_direction = Vector3(
		cos(deg_to_rad(random_angle)),
		0,
		sin(deg_to_rad(random_angle))
	).normalized()
	current_move_direction = random_direction

func get_patrol_direction(_delta: float) -> Vector3:
	# 巡逻点寻路系统：直接朝向巡逻点移动（不使用导航代理）
	# 注释原因：导航代理可能导致怪物无法移动，中心点位置问题
	# 改用直接移动，只看XZ平面，忽略高度差
	# 巡逻点不等待：到达后立即切换到下一个巡逻点
	
	# 场景外检测：只有在刚刚从追击状态切换回来时，才强制返回向导航区域的方向
	# 正常巡逻模式下，允许怪物在导航区域外活动
	if is_outside_scene and was_chasing and navigation_region:
		var map_rid = navigation_region.get_navigation_map()
		var closest_point = NavigationServer3D.map_get_closest_point(map_rid, global_position)
		var direction_to_nav = (closest_point - global_position).normalized()
		direction_to_nav.y = 0
		if direction_to_nav.length() > 0.1:
			return direction_to_nav
		return Vector3.ZERO
	
	# 如果没有巡逻点，返回零向量
	if patrol_points.size() == 0:
		return Vector3.ZERO
	
	# 正常巡逻：直接朝向巡逻点移动，不计算路径
	var current_target = patrol_points[current_patrol_index]
	var target_xz = Vector3(current_target.global_position.x, global_position.y, current_target.global_position.z)
	var direction = (target_xz - global_position).normalized()
	direction.y = 0  # 确保只看XZ平面
	
	# 检查是否到达当前巡逻点
	var distance_to_target_xz = Vector2(global_position.x, global_position.z).distance_to(
		Vector2(current_target.global_position.x, current_target.global_position.z)
	)
	if distance_to_target_xz < 1.0:
		# 到达巡逻点，立即切换到下一个巡逻点（不等待）
		
		# 根据当前方向更新索引
		if patrol_forward:
			current_patrol_index += 1
		else:
			current_patrol_index -= 1
		
		# 检查是否到达终点（最后一个点）
		if current_patrol_index >= patrol_points.size() - 1:
			current_patrol_index = patrol_points.size() - 1
			patrol_forward = false
		
		# 检查是否到达起点（第一个点）
		elif current_patrol_index <= 0:
			current_patrol_index = 0
			patrol_forward = true
		
		# 获取新的目标点
		var next_target = patrol_points[current_patrol_index]
		
		# 获取下一个巡逻点的x和z坐标（只看XZ平面）
		var next_target_xz = Vector3(next_target.global_position.x, global_position.y, next_target.global_position.z)
		direction = (next_target_xz - global_position).normalized()
		direction.y = 0  # 确保只看XZ平面
		
		print("[Monster] 到达巡逻点，立即移动到巡逻点 ", current_patrol_index)
	
	return direction

func find_nearest_patrol_point():
	if patrol_points.is_empty():
		return
	
	var nearest_index = 0
	var min_distance = 999999.0
	
	# 遍历所有巡逻点，找最近的
	for i in range(patrol_points.size()):
		var point = patrol_points[i]
		# 只计算 XZ 平面距离
		var dist = Vector2(global_position.x, global_position.z).distance_to(
			Vector2(point.global_position.x, point.global_position.z)
		)
		
		if dist < min_distance:
			min_distance = dist
			nearest_index = i
	
	# 更新当前目标索引
	current_patrol_index = nearest_index
	# 智能判断方向：如果最近点是最后一个，设为反向走；如果是第一个，设为正向走
	if current_patrol_index >= patrol_points.size() - 1:
		patrol_forward = false
	elif current_patrol_index <= 0:
		patrol_forward = true
	
	print("[Monster] 追逐结束，重新定位到最近巡逻点: ", nearest_index)

func get_chase_direction() -> Vector3:
	# 获取玩家位置 - 追击状态下的核心逻辑
	# 注释原因：不使用导航代理，直接朝向玩家移动（只看XZ平面）
	# 原因：导航代理可能导致怪物无法移动，中心点位置问题
	
	if not Global.player:
		print("[Monster] 追击失败 - 玩家不存在")
		return Vector3.ZERO
	
	# 获取玩家当前位置（只获取一次，避免多次调用）
	var player_position = Global.player.global_position
	print("[Monster] 追击 - 怪物位置: ", global_position, " 玩家位置: ", player_position)
	
	# 注释掉导航代理相关代码
	# # 计算到玩家的距离
	# var dist = global_position.distance_to(Global.player.global_position)
	# 
	# # 检查是否到达玩家位置
	# if dist < navigation_agent.target_desired_distance:
	# 	print("[Monster] 追击 - 已到达玩家位置，停止移动")
	# 	return Vector3.ZERO
	
	# 直接朝向玩家移动（不使用导航代理，只看XZ平面）
	var target_xz = Vector3(player_position.x, global_position.y, player_position.z)
	var direction = (target_xz - global_position).normalized()
	direction.y = 0  # 确保只看XZ平面
	print("[Monster] 追击 - 计算后的方向: ", direction)
	
	return direction

func get_navigation_direction() -> Vector3:
	# 寻路状态：直接朝向巡逻点移动（不使用导航代理）
	# 注释原因：导航代理可能导致怪物无法移动，中心点位置问题
	# 改用直接移动，只看XZ平面，忽略高度差
	
	if patrol_points.size() == 0:
		return Vector3.ZERO
	
	# 获取目标巡逻点
	var return_target = patrol_points[current_patrol_index]
	print("[Monster] 寻路 - 目标巡逻点: ", current_patrol_index, " 位置: ", return_target.global_position)
	print("[Monster] 寻路 - 怪物当前位置: ", global_position)
	
	# 注释掉导航代理调用
	# # 设置导航代理的目标位置
	# navigation_agent.set_target_position(return_target.global_position)
	# 
	# # 检查是否到达目标
	# if navigation_agent.is_navigation_finished():
	# 	print("[Monster] 寻路 - 已到达巡逻点，切换到巡逻状态")
	# 	is_returning_to_patrol = false
	# 	change_state(State.WANDER)
	# 	return Vector3.ZERO
	# 
	# # 获取下一个路径点
	# var next_path_position = navigation_agent.get_next_path_position()
	# print("[Monster] 寻路 - 下一个路径点: ", next_path_position)
	# 
	# # 水平化目标点，忽略高度差
	# var target_xz = Vector3(next_path_position.x, global_position.y, next_path_position.z)
	
	# 改用直接朝向目标点移动（只看XZ平面）
	var target_xz = Vector3(return_target.global_position.x, global_position.y, return_target.global_position.z)
	var direction = (target_xz - global_position).normalized()
	direction.y = 0  # 确保只看XZ平面
	print("[Monster] 寻路 - 计算后的方向: ", direction)
	
	# 检查是否到达当前巡逻点
	var return_distance = Vector2(global_position.x, global_position.z).distance_to(
		Vector2(return_target.global_position.x, return_target.global_position.z)
	)
	if return_distance < 1.0:
		# 到达巡逻点，切换到巡逻状态
		is_returning_to_patrol = false
		change_state(State.WANDER)
		print("[Monster] 寻路 - 已到达巡逻点，切换到巡逻状态")
	
	return direction

func check_and_chase_player(delta):
	# 检测玩家是否在追击范围内，如果是则切换到追击状态
	# 这个函数每帧都会被调用，用于持续检测玩家位置
	
	# 如果没有启用追击模式，直接返回
	if not 追击模式:
		return
	
	# 获取玩家节点
	if not Global.player:
		return
	
	# 计算到玩家的距离
	var distance_to_player = global_position.distance_to(Global.player.global_position)
	
	# 如果玩家在追击范围内，切换到追击状态
	if distance_to_player <= 追击距离:
		if current_state != State.CHASE:
			print("[Monster] 发现玩家，开始追击！距离: ", distance_to_player)
			change_state(State.CHASE)
		
		# 更新追击计时器
		chase_timer += delta
		
		# 检查是否超过追击时长
		if chase_timer >= chase_duration:
			print("[Monster] 追击超时，停止追击")
			change_state(State.WANDER)
			chase_timer = 0.0
	else:
		# 如果玩家超出追击范围，检查是否应该停止追击
		if current_state == State.CHASE:
			# 如果玩家超出失去目标距离，停止追击
			if distance_to_player >= 失去目标距离:
				print("[Monster] 玩家超出范围，停止追击。距离: ", distance_to_player)
				change_state(State.WANDER)
				chase_timer = 0.0

func check_scene_boundary():
	# 检查怪物是否跑离导航区域
	# 如果跑离导航区域，尝试返回导航区域
	
	if not navigation_region:
		return
	
	var map_rid = navigation_region.get_navigation_map()
	var closest_point = NavigationServer3D.map_get_closest_point(map_rid, global_position)
	var distance_to_nav = global_position.distance_to(closest_point)
	
	# 定义一个阈值，判断是否跑离导航区域
	var boundary_threshold = 5.0
	
	if distance_to_nav > boundary_threshold:
		if not is_outside_scene:
			print("[Monster] 警告：怪物跑离导航区域！距离: ", distance_to_nav)
			is_outside_scene = true
			outside_scene_timer = 0.0
	else:
		if is_outside_scene:
			print("[Monster] 怪物回到导航区域")
			is_outside_scene = false
			outside_scene_timer = 0.0
			back_to_scene_timer = 0.0
			pause_random_direction = true

func teleport_back_to_scene():
	# 将怪物传送回导航区域
	if not navigation_region:
		return
	
	var map_rid = navigation_region.get_navigation_map()
	var closest_point = NavigationServer3D.map_get_closest_point(map_rid, global_position)
	
	print("[Monster] 传送回导航区域: ", closest_point)
	global_position = closest_point
	velocity = Vector3.ZERO

func check_and_attack_door():
	# 检查附近是否有门，如果有则攻击
	# 这个函数只在追击状态或回到导航点时调用，避免性能问题
	
	if nearby_doors.is_empty():
		return
	
	# 找到最近的门
	var nearest_door = null
	var min_distance = 999999.0
	
	for door_node in nearby_doors:
		var distance = global_position.distance_to(door_node.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_door = door_node
	
	# 如果找到门且距离足够近，攻击门
	if nearest_door and min_distance < 2.0:
		print("[Monster] 发现门，开始攻击！距离: ", min_distance)
		attack_door(nearest_door)

func attack_door(door_node: Node):
	# 攻击门
	# 这个函数会被调用，当怪物发现门时
	
	if not door_node:
		return
	
	# 检查门是否有攻击方法
	if door_node.has_method("take_damage"):
		print("[Monster] 攻击门: ", door_node.name)
		door_node.take_damage(10)  # 造成10点伤害
		door_attack_cooldown = door_attack_cooldown_duration
	else:
		print("[Monster] 门没有take_damage方法")

func _on_area_3d_body_entered(body):
	# 当物体进入怪物的检测区域时调用
	# 用于检测附近的门
	
	if body.is_in_group("door"):
		print("[Monster] 门进入检测区域: ", body.name)
		nearby_doors.append(body)

func _on_area_3d_body_exited(body):
	# 当物体离开怪物的检测区域时调用
	# 用于移除不再附近的门
	
	if body.is_in_group("door"):
		print("[Monster] 门离开检测区域: ", body.name)
		nearby_doors.erase(body)

func start_wander():
	# 开始巡逻状态
	# 这个函数在切换到WANDER状态时调用
	
	print("[Monster] 开始巡逻")
	wander_timer = 0.0
	
	# 如果有巡逻点，设置初始目标
	if patrol_points.size() > 0:
		var target = patrol_points[current_patrol_index]
		target_position = target.global_position
		print("[Monster] 设置巡逻目标: ", target_position)

func update_wander_timer(delta):
	# 更新巡逻计时器
	# 这个函数在WANDER状态下每帧调用
	
	wander_timer += delta
	
	# 如果巡逻计时器超时，切换到空闲状态
	if wander_timer >= wander_interval:
		print("[Monster] 巡逻超时，切换到空闲状态")
		change_state(State.IDLE)
		wander_timer = 0.0

func handle_animation():
	# 处理动画
	# 根据怪物的移动状态播放相应的动画
	
	var is_moving = velocity.length() > 0.1
	
	if is_moving:
		if animation_player:
			if animation_player.current_animation != "walk":
				animation_player.play("walk")
	else:
		if animation_player:
			if animation_player.current_animation != "idle":
				animation_player.play("idle")

func rotate_toward_direction(direction: Vector3, delta: float):
	# 旋转怪物朝向移动方向
	# 使用四元数进行平滑旋转
	
	if direction.length() < 0.1:
		return
	
	# 计算目标旋转
	var target_rotation = atan2(direction.x, direction.z)
	
	# 获取当前旋转
	var current_rotation = rotation.y
	
	# 平滑旋转到目标方向
	var rotation_speed = 10.0
	var new_rotation = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)
	
	# 应用旋转
	rotation.y = new_rotation

func _on_area_3d_area_entered(area):
	# 当区域进入怪物的检测区域时调用
	# 用于检测附近的门
	
	if area.is_in_group("door"):
		print("[Monster] 门区域进入检测区域: ", area.name)
		nearby_doors.append(area)

func _on_area_3d_area_exited(area):
	# 当区域离开怪物的检测区域时调用
	# 用于移除不再附近的门
	
	if area.is_in_group("door"):
		print("[Monster] 门区域离开检测区域: ", area.name)
		nearby_doors.erase(area)
