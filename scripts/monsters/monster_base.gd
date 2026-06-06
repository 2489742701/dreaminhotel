# ==============================================================================
# monster_base.gd - 怪物AI基类
# ==============================================================================
# 实现怪物的完整AI行为系统，包括：
# - 状态机：IDLE(空闲)、WANDER(巡逻)、CHASE(追击)、NAVIGATION(寻路回归)、BREAK_DOOR(破门)
# - 巡逻系统：支持巡逻点模式和随机游荡模式
# - 追击系统：检测玩家并追击，支持视线检测和距离限制
# - 门攻击系统：检测被封印的门并进行破坏
# - 导航系统：使用NavigationAgent3D进行智能寻路
# - 安全机制：卡住检测、场景边界检测、传送回导航区域
# 
# 适用于初学者：
# - 这是学习游戏AI状态机的绝佳范例
# - 理解怪物AI需要掌握：状态机模式、导航系统、射线检测、计时器系统
# - 建议先阅读状态枚举和_ready函数，理解整体流程
# ==============================================================================

@tool
extends CharacterBody3D

# ========== 基础移动属性 ==========
# 控制怪物的移动物理特性，影响移动的流畅度和手感

@export var 移动速度: float = 3.0
@export var 加速度: float = 10.0
@export var 摩擦力: float = 10.0

# ========== 重力设置 ==========
# 控制怪物的下落物理，确保怪物能在地形上正常行走

@export var 重力: float = 30.0
@export var 最大下落速度: float = 50.0

# ========== 追击设置 ==========
# 控制怪物追击玩家的行为参数
# 初学者提示：追击系统是恐怖游戏的核心，合理设置这些参数影响游戏难度

@export var 追击距离: float = 5.0          # 玩家进入此距离内，怪物开始追击
@export var 追击速度: float = 3.0           # 追击时的移动速度（通常比巡逻速度快）
@export var 失去目标距离: float = 20.0      # 玩家超出此距离，怪物放弃追击
@export var 追击模式: bool = true           # 是否启用追击功能（发现玩家后追击，初始化始终进入巡逻）
@export var avoidance_enabled: bool = false # 避障系统（已废弃，单怪物无需启用，开启会卡住）

# ========== 门攻击系统 ==========
# 怪物可以检测并破坏被封印的门
# 这是恐怖游戏的重要机制：玩家封门后怪物会尝试破门
# 初学者提示：门攻击系统涉及空间查询、计时器和状态切换，是学习复杂AI的好例子

var nearby_doors: Array = []              # 附近的门列表（已废弃，使用空间查询）
var nearby_door: Node = null              # 最近的门节点（已废弃，保留兼容）
var is_attacking_door: bool = false       # 是否正在攻击门
var target_door: Node = null              # 当前正在攻击的门节点
@export var 门检测范围: float = 10.0      # 怪物检测门的范围（米）
var _is_opening_door: bool = false        # 递归锁，防止 try_open_door 无限递归
var attack_timer: float = 0.0             # 攻击动画计时器
var attack_animation_duration: float = 3.0 # 攻击动画持续时间（秒）
var has_reached_door: bool = false        # 是否已到达门前（用于切换移动/攻击状态）
var door_check_timer: float = 0.0         # 门检测计时器（控制检测频率）
var door_check_interval: float = 0.2      # 门检测间隔（秒）- 缩短间隔防止穿门

# ========== 发现玩家等待系统 ==========
# 怪物发现玩家后，原地等待2秒再开始追击
# 这是恐怖游戏的重要节奏控制：给玩家反应逃跑的时间

var is_waiting_before_chase: bool = false  # 是否正在等待追击
var wait_before_chase_timer: float = 0.0   # 等待追击计时器
@export var 发现玩家等待时间: float = 2.0  # 发现玩家后等待时间（秒）
var has_played_alert_sound: bool = false   # 是否已播放警觉音效（防止重复播放）

# ========== 活动范围设置 ==========
# 限制怪物的活动区域，防止怪物跑出地图范围
# 初学者提示：活动范围是一种简单的AI约束机制

@export var 启用活动范围: bool = false
@export var 活动范围中心: Vector3 = Vector3.ZERO
@export var 活动半径: float = 10.0

# ========== 巡逻模式设置 ==========
# 巡逻是怪物在未发现玩家时的主要行为
# 支持两种模式：巡逻点模式（沿预设点移动）、随机游荡模式
# 初学者提示：巡逻点模式更容易控制怪物行为，推荐新手使用

@export var 巡逻模式: bool = true                  # false=随机寻路, true=巡逻点
@export var 巡逻点节点路径: NodePath = "../PatrolPoints" # 巡逻点容器的节点路径

# ========== 调试设置 ==========
# 用于开发调试，帮助理解怪物AI行为
# 初学者提示：遇到AI问题时，先开启这些调试选项查看日志

@export var 启用调试信息: bool = false      # 控制台输出调试日志
@export var 启用调试绘制: bool = false      # 绘制调试图形（如视线射线）
@export var 启用移动方向调试: bool = false  # 输出移动方向详细信息

# ========== 状态枚举 ==========
# 怪物AI的核心：有限状态机(FSM)
# 初学者提示：状态机是游戏AI的基础，每种状态对应一种行为模式
#
# 状态说明：
# - IDLE: 空闲状态，怪物静止不动
# - WANDER: 巡逻状态，怪物在场景中移动（巡逻点或随机游荡）
# - CHASE: 追击状态，怪物追踪玩家
# - NAVIGATION: 寻路回归状态，追击结束后回到巡逻路线
# - BREAK_DOOR: 破门状态，怪物正在攻击被封印的门
#
# 性能优化说明：
# NAVIGATION状态用于追击后回归巡逻点，此时需要检测门并攻击
# 只在追击和回归时检测门，避免巡逻模式下持续检测导致性能问题

enum State { IDLE, WANDER, CHASE, NAVIGATION, BREAK_DOOR }

# ========== 状态管理变量 ==========
# 当前状态和目标位置

var current_state: State = State.IDLE  # 当前AI状态
var target_position: Vector3            # 当前移动目标位置
var wander_timer: float = 0.0           # 空闲状态计时器
var wander_interval: float = 3.0        # 空闲状态持续时间

# ========== 随机方向移动系统 ==========
# 用于随机游荡模式

var move_direction_timer: float = 0.0       # 方向改变计时器
var move_direction_interval: float = 1.0    # 方向改变间隔
var current_move_direction: Vector3 = Vector3.ZERO # 当前移动方向

# ========== 巡逻点系统 ==========
# 巡逻点模式：怪物沿预设路径移动
# 初学者提示：在场景中放置Marker3D节点作为巡逻点，怪物会按顺序访问

var patrol_points: Array[Node3D] = []       # 巡逻点节点数组
var current_patrol_index: int = 0           # 当前巡逻点索引
var patrol_points_container: Node = null    # 巡逻点容器节点
var patrol_forward: bool = true             # 巡逻方向：true=正向(0->End), false=反向(End->0)
var patrol_wait_timer: float = 0.0          # 巡逻点等待计时器
var patrol_wait_duration: float = 2.0       # 巡逻点等待持续时间
var is_waiting_at_patrol: bool = false      # 是否正在巡逻点等待
var last_patrol_target: Node3D = null       # 记录上一次设置的巡逻目标，避免重复设置

# ========== 追击系统 ==========
# 追击玩家的计时器和状态

var chase_timer: float = 0.0                # 追击持续时间计时器
@export var chase_duration: float = 12.0    # 最大追击持续时间（超时放弃）
var was_chasing: bool = false               # 标记是否刚刚从追击状态切换回来

# ========== 动画组件 ==========
# 怪物模型的动画播放器和骨骼系统

@onready var animation_player: AnimationPlayer = get_node("MobA/AnimationPlayer")  # 动画播放器
@onready var skeleton: Skeleton3D = get_node("MobA/Skeleton3D")                     # 骨骼系统
@onready var navigation_agent: NavigationAgent3D = get_node("NavigationAgent3D")   # 导航代理

# ========== 视线检测 ==========
# 用于判断怪物是否能直接看到玩家（射线检测）
# 初学者提示：视线检测让怪物更"智能"，不会隔墙追击

@onready var vision_ray: RayCast3D = get_node("MobA/Skeleton3D/Ch36/RayCast3D")  # 视线射线

# ========== 导航区域管理 ==========
# 检测怪物是否跑出导航区域，防止跑出地图边界

var navigation_region: NavigationRegion3D = null      # 场景中的导航区域引用
var scene_boundary_timer: float = 0.0                 # 边界检测计时器
var scene_boundary_check_interval: float = 1.0        # 边界检测间隔
var outside_scene_timer: float = 0.0                  # 离开场景的累计时间
var outside_scene_timeout: float = 5.0                # 离开场景超时（超时传送回来）
var is_outside_scene: bool = false                    # 是否在场景外

# ========== 场景回归稳定系统 ==========
# 怪物回到场景内后，短暂保持当前方向避免抖动

var back_to_scene_timer: float = 0.0              # 回归稳定计时器
var back_to_scene_duration: float = 3.0           # 稳定持续时间
var pause_random_direction: bool = false          # 是否暂停随机方向变化

# ========== 追击冷却系统 ==========
# 追击结束后进入冷却，防止立即再次追击
# 初学者提示：冷却机制让玩家有喘息机会，调节游戏难度

var chase_cooldown_timer: float = 0.0             # 冷却计时器
var chase_cooldown_duration: float = 8.0          # 冷却持续时间

# ========== 卡住检测系统 ==========
# 检测怪物是否卡在障碍物中，超时自动传送回导航区域
# 初学者提示：这是AI的安全机制，防止怪物卡死在墙角

var stuck_timer: float = 0.0                      # 卡住计时器
var stuck_timeout: float = 3.0                    # 卡住超时时间
var last_position: Vector3 = Vector3.ZERO         # 上一帧位置（用于判断是否移动）
var is_stuck: bool = false                        # 是否卡住

# ========== 导航点回归标记 ==========
# 标记怪物是否正在从追击状态返回巡逻路线

var is_returning_to_patrol: bool = false          # 是否正在返回巡逻点

# ========== 巡逻卡死检测 ==========
# 检测巡逻时是否无法到达目标点，超时强制切换下一个

var patrol_stuck_timer: float = 0.0               # 巡逻卡死计时器
var patrol_stuck_timeout: float = 5.0             # 巡逻卡死超时
var last_distance_to_target: float = 0.0          # 上一帧到目标距离
var last_valid_target: Vector3 = Vector3.ZERO     # 上一个有效目标位置

# ==============================================================================
# 初始化函数
# ==============================================================================

func _ready():
	# 初始化目标位置为当前位置
	target_position = global_position
	
	# 添加到monster分组，让门能够检测到怪物
	# 初学者提示：分组是Godot中组织节点的常用方式，可用于批量查找和操作
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

# 查找场景中的导航区域
# 初学者提示：导航区域定义了怪物可以行走的区域
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

# 延迟启动巡逻，确保导航地图同步完成
# 初学者提示：使用延迟调用避免导航地图未加载完成的问题
func _delayed_start_wander():
	setup_patrol_points()
	change_state(State.WANDER)

# 导航代理计算速度的回调函数（避障系统）
# @param safe_velocity: 计算出的安全速度向量
func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity

# 设置导航代理参数
# 初学者提示：导航代理的参数影响寻路精度和性能，需要根据游戏场景调整
func setup_navigation_agent():
	if not navigation_agent:
		return
	
	# 基础导航设置
	navigation_agent.path_desired_distance = 0.5  # 增加距离，避免抖动
	navigation_agent.target_desired_distance = 0.5  # 增加距离，避免抖动
	navigation_agent.path_max_distance = 3.0
	
	# 高度设置 - 已通过调整导航网格位置解决，注释掉
	# navigation_agent.height = 2.0  # 设置导航代理高度
	# navigation_agent.path_height_offset = 0.0  # 路径高度偏移
	
	# 避障设置
	var use_avoidance = avoidance_enabled
	navigation_agent.avoidance_enabled = use_avoidance
	navigation_agent.radius = 0.5
	navigation_agent.neighbor_distance = 5.0
	navigation_agent.max_neighbors = 10
	navigation_agent.time_horizon = 0.5
	navigation_agent.max_speed = 追击速度
	
	# 连接速度计算信号（仅在启用避障时）
	if use_avoidance:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
	
	print("[Monster] 导航代理已启用，使用导航路径模式（只看XZ平面）")

# 设置巡逻点
# 从场景中获取巡逻点容器，并提取所有子节点作为巡逻点
# 初学者提示：巡逻点通常使用Marker3D或Node3D节点放置在场景中
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

# 设置初始巡逻目标
# 使用call_deferred延迟调用，确保节点完全加入场景树
func _set_initial_patrol_target():
	if patrol_points.size() > 0 and current_patrol_index < patrol_points.size():
		var target = patrol_points[current_patrol_index]
		if target and target.is_inside_tree():
			target_position = target.global_position
			print("[Monster] 设置初始目标为巡逻点 ", current_patrol_index, " 位置: ", target_position)
		else:
			print("[Monster] 警告: 巡逻点尚未加入场景树，使用当前位置")
			target_position = global_position

# ==============================================================================
# 主循环 - 物理帧处理
# ==============================================================================
# 每个物理帧执行，处理怪物的所有AI逻辑
# 初学者提示：这是理解怪物AI的入口点，按顺序执行各个子系统
#
# 处理顺序：
# 1. 冷却计时器递减
# 2. 卡住检测
# 3. 追击玩家检测
# 4. 场景边界检测
# 5. 门攻击检测
# 6. 破门状态处理
# 7. 移动处理
# 8. 动画处理
# ==============================================================================

func _physics_process(delta):
	# 在编辑器中不运行AI逻辑
	if Engine.is_editor_hint():
		return
	
	# 攻击/追击冷却计时器（无条件递减）
	if chase_cooldown_timer > 0:
		chase_cooldown_timer -= delta
		if chase_cooldown_timer < 0:
			chase_cooldown_timer = 0
	
	# 卡住检测
	if last_position == Vector3.ZERO:
		last_position = global_position
	else:
		var distance_moved = global_position.distance_to(last_position)
		if distance_moved < 0.01:
			stuck_timer += delta
		else:
			stuck_timer = 0.0
			is_stuck = false
		last_position = global_position
	
		# 如果卡住超时，传送回导航区域
		if stuck_timer >= stuck_timeout:
			print("[Monster] 卡住超时，传送回导航区域")
			teleport_back_to_scene()
			stuck_timer = 0.0
			is_stuck = false
	
	if 追击模式 and current_state != State.BREAK_DOOR and not is_attacking_door:
		check_and_chase_player(delta)
	
	# 检查是否跑离场景
	scene_boundary_timer += delta
	if scene_boundary_timer >= scene_boundary_check_interval:
		check_scene_boundary()
		scene_boundary_timer = 0.0
	
	# ========== 门检测系统 ==========
	# 追击和回归巡逻时，用球形范围检测附近是否有门
	# 如果附近有封板的门，优先去破门
	# 视线射线只判断能否看到玩家，不负责门检测
	var can_attack_door = (current_state == State.CHASE or is_returning_to_patrol)
	if can_attack_door and not is_waiting_at_patrol and not is_waiting_before_chase and not is_attacking_door and current_state != State.BREAK_DOOR:
		door_check_timer += delta
		if door_check_timer >= door_check_interval:
			door_check_timer = 0.0
			check_and_attack_door()
	
	# ========== 发现玩家等待处理 ==========
	# 破门锁定期间不触发等待追击
	if is_waiting_before_chase and current_state != State.BREAK_DOOR:
		wait_before_chase_timer += delta
		
		# 播放警觉音效（只播放一次）
		if not has_played_alert_sound:
			play_alert_sound()
			has_played_alert_sound = true
		
		# 等待时间结束，开始追击
		if wait_before_chase_timer >= 发现玩家等待时间:
			print("[Monster] 等待结束，开始追击!")
			_exit_wait_before_chase()
	
	# 处理破坏门状态的攻击动画和超时保护
	if current_state == State.BREAK_DOOR:
		# 1. 门失效检查（节点失效 / 未被封 / 已被破坏）
		var is_destroyed = false
		if is_instance_valid(target_door) and "is_destroyed" in target_door:
			is_destroyed = target_door.is_destroyed
		
		if not is_instance_valid(target_door) or not target_door.is_sealed or is_destroyed:
			_exit_break_door()
			return
		
		var distance_to_door = global_position.distance_to(target_door.global_position)
		
		# 2. 移动阶段：尚未到达门前
		if distance_to_door > 0.7:
			# 导航移动（直接复用你已有的移动代码）
			if navigation_agent and not navigation_agent.is_navigation_finished():
				var next_pos = navigation_agent.get_next_path_position()
				var dir = (next_pos - global_position).normalized()
				dir.y = 0
				velocity = velocity.move_toward(dir * 追击速度, 加速度 * delta)
			else:
				var dir = (target_door.global_position - global_position).normalized()
				dir.y = 0
				velocity = velocity.move_toward(dir * 移动速度, 加速度 * delta)
			
			rotate_toward_target(target_door.global_position, delta)
			move_and_slide()
			return
		
		# 3. 攻击阶段：已到达门前
		if not has_reached_door:
			has_reached_door = true
			attack_timer = 0.0
		
		# 停止移动
		velocity = velocity.move_toward(Vector3.ZERO, 摩擦力 * delta)
		move_and_slide()
		
		# 攻击动画计时
		attack_timer += delta
		if attack_timer >= attack_animation_duration:
			# 执行一次劈砍
			if is_instance_valid(target_door):
				target_door.execute_chop_logic()
			
			# 攻击结束：重置标志 + 进入冷却 + 切换回巡逻
			is_attacking_door = false
			target_door = null
			has_reached_door = false
			attack_timer = 0.0
			
			# 复用 chase_cooldown_timer 作为攻击冷却
			chase_cooldown_timer = chase_cooldown_duration
			
			change_state(State.WANDER)
	
	# 应用重力
	if not is_on_floor():
		velocity.y -= 重力 * delta
		velocity.y = max(velocity.y, -最大下落速度)
	
	handle_movement(delta)
	handle_animation()
	
	if current_state == State.WANDER:
		update_wander_timer(delta)

# ==============================================================================
# 状态机 - 状态切换
# ==============================================================================
# 切换怪物的AI状态，并根据新状态执行相应的初始化
# @param new_state: 要切换到的目标状态
# 初学者提示：状态切换是状态机的核心，每种状态可能有不同的初始化逻辑
# ==============================================================================

func change_state(new_state: State):
	if current_state == new_state:
		return
	
	current_state = new_state
	
	match current_state:
		State.IDLE:
			pass
		State.WANDER:
			start_wander()
		State.CHASE:
			# 立即清除"正在回防"的标记，防止逻辑冲突
			is_returning_to_patrol = false
			
			# 强制刷新导航目标，防止路径数据过期
			if Global.player and navigation_agent:
				var player_position = Global.player.global_position
				var target_xz = Vector3(player_position.x, player_position.y, player_position.z)
				navigation_agent.set_target_position(target_xz)
		State.NAVIGATION:
			# 寻路状态：使用导航代理进行智能寻路
			# 切换到NAVIGATION状态时，确保导航代理目标正确设置
			if navigation_agent and patrol_points.size() > 0:
				var return_target = patrol_points[current_patrol_index]
				navigation_agent.set_target_position(return_target.global_position)
		State.BREAK_DOOR:
			# 破坏门状态，停止移动
			pass

# ==============================================================================
# 移动处理 - 核心移动逻辑
# ==============================================================================
# 根据当前状态计算移动方向和速度，并执行移动
# @param delta: 帧时间间隔
# 初学者提示：这是怪物移动的核心函数，理解它就能理解怪物的移动机制
#
# 处理流程：
# 1. 检查特殊状态（攻击门、空闲）→ 停止移动
# 2. 根据状态获取移动方向（巡逻/追击/寻路）
# 3. 计算目标速度
# 4. 旋转朝向移动方向
# 5. 执行移动并检测碰撞
# ==============================================================================

func handle_movement(delta):
	# 处理怪物的移动逻辑，包括速度计算、碰撞检测和方向控制
	# 这个函数是怪物移动的核心，根据当前状态（IDLE/WANDER/CHASE）决定如何移动
	
	# 如果怪物正在攻击门且已到达门前，停止移动
	if is_attacking_door and has_reached_door:
		velocity = velocity.move_toward(Vector3.ZERO, 摩擦力 * delta)
		move_and_slide()
		return
	
	# 如果怪物正在门前等待（发现玩家后），停止移动
	if is_waiting_before_chase:
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

# ==============================================================================
# 巡逻方向计算
# ==============================================================================

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
	# 巡逻点寻路系统：使用导航代理进行智能寻路
	# 只看XZ平面，忽略高度差
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
	
	# 使用导航代理进行智能寻路
	var current_target = patrol_points[current_patrol_index]
	
	# 卡死检测：如果距离目标距离没有明显减少，计时器累加
	var current_distance = global_position.distance_to(current_target.global_position)
	if abs(current_distance - last_distance_to_target) < 0.05:
		patrol_stuck_timer += _delta
	else:
		patrol_stuck_timer = 0.0
	last_distance_to_target = current_distance
	
	# 超时强制切换目标
	if patrol_stuck_timer >= patrol_stuck_timeout:
		print("[Monster] 巡逻卡死超时，强制切换到下一个巡逻点")
		switch_to_next_patrol_point()
		patrol_stuck_timer = 0.0
		# 重新获取新目标
		current_target = patrol_points[current_patrol_index]
	
	# 只在目标改变时才设置导航代理的目标位置，避免重复设置
	if last_patrol_target != current_target:
		navigation_agent.set_target_position(current_target.global_position)
		last_patrol_target = current_target
		print("[Monster] 巡逻 - 设置新目标: ", current_patrol_index, " 位置: ", current_target.global_position)
	
	# 检查导航代理是否有有效路径
	if navigation_agent.is_navigation_finished():
		# 没有路径，但尚未到达目标 → 启用直线移动
		var direction_to_target = (current_target.global_position - global_position).normalized()
		direction_to_target.y = 0
		if direction_to_target.length() > 0.1:
			# 强制刷新路径请求
			navigation_agent.set_target_position(current_target.global_position)
			print("[Monster] 巡逻 - 路径无效，使用直线移动")
			return direction_to_target
		else:
			# 非常接近，直接判定到达
			switch_to_next_patrol_point()
			return Vector3.ZERO
	
	# 检查是否到达当前巡逻点
	var distance_to_target_xz = Vector2(global_position.x, global_position.z).distance_to(
		Vector2(current_target.global_position.x, current_target.global_position.z)
	)
	if distance_to_target_xz < navigation_agent.target_desired_distance:
		# 到达巡逻点，立即切换到下一个巡逻点（不等待）
		switch_to_next_patrol_point()
		# 重新获取新目标
		current_target = patrol_points[current_patrol_index]
	
	# 获取下一个路径点
	var next_path_position = navigation_agent.get_next_path_position()
	
	# 只看XZ平面，忽略高度差
	var target_xz = Vector3(next_path_position.x, global_position.y, next_path_position.z)
	var direction = (target_xz - global_position).normalized()
	direction.y = 0  # 确保只看XZ平面
	
	return direction

func switch_to_next_patrol_point():
	if patrol_points.size() == 0:
		return
	
	# 根据方向更新索引
	if patrol_forward:
		current_patrol_index += 1
	else:
		current_patrol_index -= 1
	
	# 边界处理
	if current_patrol_index >= patrol_points.size():
		current_patrol_index = patrol_points.size() - 1
		patrol_forward = false
	elif current_patrol_index < 0:
		current_patrol_index = 0
		patrol_forward = true
	
	var next_target = patrol_points[current_patrol_index]
	navigation_agent.set_target_position(next_target.global_position)
	last_patrol_target = next_target
	patrol_stuck_timer = 0.0
	print("[Monster] 切换到巡逻点 ", current_patrol_index)

# 找到最近的巡逻点
# 追击结束后，怪物会传送到最近的巡逻点继续巡逻
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

# ==============================================================================
# 追击系统
# ==============================================================================

# 获取追击方向
# 使用导航代理计算朝向玩家的路径
# @return: 追击方向的归一化向量
func get_chase_direction() -> Vector3:
	if not Global.player:
		print("[Monster] 追击失败 - 玩家不存在")
		return Vector3.ZERO
	
	var player_position = Global.player.global_position
	
	# 近距离门检测：检测前方1.5米内是否有关闭的门
	# 防止NavMesh路径穿门，在到达门前先开门
	if not is_attacking_door:
		var front_door = _detect_door_in_front()
		if front_door:
			var is_sealed = false
			var is_destroyed = false
			if "is_sealed" in front_door:
				is_sealed = front_door.is_sealed
			if "is_destroyed" in front_door:
				is_destroyed = front_door.is_destroyed
			
			if is_sealed and not is_destroyed:
				print("[Monster] 前方有封板的门，破门")
				attack_door(front_door)
				return Vector3.ZERO
			elif not is_sealed and not is_destroyed:
				print("[Monster] 前方有关闭的门，开门")
				try_open_door(front_door)
	
	navigation_agent.set_target_position(player_position)
	
	if navigation_agent.is_navigation_finished():
		return Vector3.ZERO
	
	var next_path_position = navigation_agent.get_next_path_position()
	var target_xz = Vector3(next_path_position.x, global_position.y, next_path_position.z)
	var direction = (target_xz - global_position).normalized()
	direction.y = 0
	
	return direction

# ==============================================================================
# 寻路回归系统
# ==============================================================================

# 获取寻路回归方向
# 追击结束后，使用导航代理返回巡逻路线
# @return: 寻路方向的归一化向量
func get_navigation_direction() -> Vector3:
	# 寻路状态：使用导航代理进行智能寻路
	# 只看XZ平面，忽略高度差
	
	if not navigation_agent:
		print("[Monster] 寻路失败 - 导航代理不存在")
		return Vector3.ZERO
	
	if patrol_points.size() == 0:
		return Vector3.ZERO
	
	# 获取目标巡逻点
	var return_target = patrol_points[current_patrol_index]
	print("[Monster] 寻路 - 目标巡逻点: ", current_patrol_index, " 位置: ", return_target.global_position)
	print("[Monster] 寻路 - 怪物当前位置: ", global_position)
	
	# 设置导航代理的目标位置（保留原始Y坐标）
	navigation_agent.set_target_position(return_target.global_position)
	
	# 如果导航代理没有有效路径，直线移动回退
	if navigation_agent.is_navigation_finished():
		var direction_to_target = (return_target.global_position - global_position).normalized()
		direction_to_target.y = 0
		if direction_to_target.length() > 0.1:
			print("[Monster] 寻路 - 路径无效，使用直线移动")
			navigation_agent.set_target_position(return_target.global_position)
			return direction_to_target
		else:
			print("[Monster] 寻路 - 已到达巡逻点，切换到巡逻状态")
			is_returning_to_patrol = false
			change_state(State.WANDER)
			return Vector3.ZERO
	
	# 获取下一个路径点
	var next_path_position = navigation_agent.get_next_path_position()
	print("[Monster] 寻路 - 下一个路径点: ", next_path_position)
	
	# 只看XZ平面，忽略高度差
	var target_xz = Vector3(next_path_position.x, global_position.y, next_path_position.z)
	var direction = (target_xz - global_position).normalized()
	direction.y = 0  # 确保只看XZ平面
	print("[Monster] 寻路 - 计算后的方向: ", direction)
	
	# 到达检测
	var distance_to_target_xz = Vector2(global_position.x, global_position.z).distance_to(
		Vector2(return_target.global_position.x, return_target.global_position.z)
	)
	if distance_to_target_xz < navigation_agent.target_desired_distance:
		print("[Monster] 寻路 - 已到达巡逻点，切换到巡逻状态")
		is_returning_to_patrol = false
		change_state(State.WANDER)
		return Vector3.ZERO
	
	return direction

func rotate_toward_direction(direction: Vector3, delta: float):
	var target_quat = Quaternion(Basis.looking_at(-direction, Vector3.UP))
	get_node("MobA").quaternion = get_node("MobA").quaternion.slerp(target_quat, delta * 10.0)

func rotate_toward_target(door_position: Vector3, delta: float):
	# 朝向目标位置（用于面向门）
	var direction = (door_position - global_position).normalized()
	direction.y = 0  # 只在XZ平面旋转
	var target_quat = Quaternion(Basis.looking_at(-direction, Vector3.UP))
	get_node("MobA").quaternion = get_node("MobA").quaternion.slerp(target_quat, delta * 10.0)

func handle_animation():
	var is_actually_moving = velocity.length() > 0.1
	
	# 如果在破坏门状态
	if current_state == State.BREAK_DOOR:
		# 如果已经到达门前，播放攻击动画
		if has_reached_door:
			play_anim(["怪物全集", "怪物拳击", "怪物旋风踢"])
		else:
			# 还在移动到门的过程中，播放奔跑动画
			play_anim(["怪物奔跑", "怪物娘炮奔跑", "怪物全集"])
		return
	
	if is_actually_moving:
		# 如果在追击状态，优先播放"怪物娘炮奔跑"动画
		if current_state == State.CHASE:
			play_anim(["怪物娘炮奔跑", "怪物奔跑", "怪物全集"])
		else:
			# 巡逻状态，播放普通奔跑动画
			play_anim(["怪物奔跑", "怪物娘炮奔跑", "怪物全集"])
	else:
		# 不移动时，播放待机动画（优先抚摸，不要倒地）
		play_anim(["怪物抚摸掉体力", "怪物全集", "RESET"])

func play_anim(anim_list: Array):
	for anim_name in anim_list:
		if animation_player.has_animation(anim_name):
			if animation_player.current_animation != anim_name:
				animation_player.play(anim_name)
			return  # 找到可用的动画后返回
	# 如果没有找到任何动画，播放默认动画
	if animation_player.has_animation("怪物全集"):
		animation_player.play("怪物全集")

func update_wander_timer(delta):
	if current_state == State.IDLE:
		wander_timer += delta
		if wander_timer >= wander_interval:
			change_state(State.WANDER)
			wander_timer = 0.0

func start_wander():
	pass

# 获取怪物自身及所有子碰撞体的RID，用于射线排除
func _get_self_exclude_rids() -> Array:
	var rids = [self.get_rid()]
	# 递归收集所有CollisionObject3D的RID
	_collect_collision_rids(self, rids)
	if has_node("MobA"):
		_collect_collision_rids(get_node("MobA"), rids)
	return rids

func _collect_collision_rids(node: Node, rids: Array):
	for child in node.get_children():
		if child is CollisionObject3D:
			rids.append(child.get_rid())
		_collect_collision_rids(child, rids)

# 动态视线检测：从怪物向玩家方向发射射线
# 检测中间是否有墙壁/门阻挡视线
# @param distance: 到玩家的距离
# @return: true=视线畅通(能看到玩家), false=视线被阻挡
func _check_line_of_sight_to_player(distance: float) -> bool:
	if not Global.player:
		return false
	
	# 超出追击距离，直接不可见
	if distance > 追击距离:
		return false
	
	var player_pos = Global.player.global_position
	var monster_pos = global_position
	
	# 射线起点：怪物胸口高度（1.2米）
	var from = monster_pos + Vector3(0, 1.2, 0)
	# 射线终点：玩家胸口高度
	var to = player_pos + Vector3(0, 1.2, 0)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	# 碰撞层：检测墙壁(1层)和门(2层)，不检测玩家
	query.collision_mask = 1 | 2
	# 排除怪物自身及子碰撞体
	query.exclude = _get_self_exclude_rids()
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		# 射线没碰到任何东西，视线畅通
		return true
	
	# 碰到了东西，检查是否是玩家
	var collider = result["collider"]
	if collider and (collider == Global.player or collider.is_in_group("player")):
		return true
	
	# 碰到了墙壁或门，视线被阻挡
	return false

func check_and_chase_player(delta):
	if not 追击模式:
		return
	
	if not Global.player:
		return
	
	# 破门锁定：正在攻击门时，不被追击逻辑打断
	if current_state == State.BREAK_DOOR or is_attacking_door:
		return
	
	# 计算到玩家的距离
	var distance_to_player = global_position.distance_to(Global.player.global_position)
	
	# 检测视线是否被阻挡
	# 使用动态射线：从怪物向玩家方向发射，检测中间是否有墙壁/门
	var has_line_of_sight = _check_line_of_sight_to_player(distance_to_player)
	
	if current_state != State.CHASE:
		# 如果玩家在追击距离内且视线未被阻挡，开始追击
		if distance_to_player < 追击距离 and has_line_of_sight:
			# 发现玩家后，先等待2秒（给玩家逃跑时间）
			if not is_waiting_before_chase:
				print("[Monster] 发现玩家! 等待", 发现玩家等待时间, "秒后追击")
				_start_wait_before_chase()
	else:
		# 追击状态：持续锁定玩家
		chase_timer += delta
		
		# 追击中视线被阻挡时，检查阻挡物是否是门
		# 如果是门：开门/破门继续追击
		# 如果是墙壁：放弃追击回到巡逻
		if not has_line_of_sight:
			var blocking_door = _find_blocking_door_in_sight()
			if blocking_door:
				# 视线被门阻挡，处理门（开门或破门）
				_handle_door_during_chase(blocking_door)
			else:
				# 视线被墙壁阻挡，放弃追击
				print("[Monster] 视线被墙壁阻挡，停止追击，回到巡逻")
				change_state(State.WANDER)
				chase_timer = 0.0
				chase_cooldown_timer = chase_cooldown_duration
				return
		
		# 只有在非攻击门状态下才会因为超时而停止追击
		if chase_timer >= chase_duration and not is_attacking_door:
			print("[Monster] 追击超时 - 停止追击")
			change_state(State.WANDER)
			chase_timer = 0.0
			chase_cooldown_timer = chase_cooldown_duration
		# 失去目标距离检测：如果距离过远，放弃追击
		if distance_to_player > 失去目标距离:
			print("[Monster] 失去目标 - 距离玩家: ", distance_to_player, " 失去目标距离: ", 失去目标距离)
			change_state(State.WANDER)
			chase_timer = 0.0

# 检测怪物前方是否有关闭的门
# 导航网格不知道门的状态，所以需要用射线手动检测
# @return: 门节点 或 null
func _detect_door_in_front() -> Node:
	# 获取怪物朝向
	var forward = -get_node("MobA").global_basis.z.normalized()
	forward.y = 0
	if forward.length() < 0.01:
		return null
	forward = forward.normalized()
	
	# 射线：从胸口高度向前射1.5米
	var from = global_position + Vector3(0, 1.2, 0)
	var to = from + forward * 1.5
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = 2  # 门在第2层
	query.exclude = _get_self_exclude_rids()
	
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return null
	
	# 向上查找门控制节点
	var collider = result["collider"]
	var current_node = collider
	for i in range(5):
		if current_node == null:
			break
		if current_node.has_method("try_open_door"):
			# 只返回关闭或被封的门
			if "state" in current_node:
				if current_node.state == "CLOSED" or current_node.is_sealed:
					return current_node
			return current_node
		current_node = current_node.get_parent()
	
	return null

# 找到阻挡视线的门（追击中视线被阻挡时调用）
# 发射射线从怪物到玩家，如果碰到的是门节点则返回该门
# @return: 门节点 或 null（碰到的是墙壁或其他物体）
func _find_blocking_door_in_sight() -> Node:
	if not Global.player:
		return null
	
	var from = global_position + Vector3(0, 1.2, 0)
	var to = Global.player.global_position + Vector3(0, 1.2, 0)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = 1 | 2  # 检测墙壁(1层)和门(2层)
	query.exclude = _get_self_exclude_rids()
	
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return null
	
	# 碰到的是玩家，不算阻挡
	var collider = result["collider"]
	if collider and (collider == Global.player or collider.is_in_group("player")):
		return null
	
	# 向上查找门控制节点
	var current_node = collider
	for i in range(5):
		if current_node == null:
			break
		if current_node.has_method("try_open_door"):
			return current_node
		current_node = current_node.get_parent()
	
	# 碰到的是墙壁，不是门
	return null


# 处理追击中遇到的门
# @param door: 门节点
func _handle_door_during_chase(door: Node):
	if not is_instance_valid(door):
		return
	
	# 破门锁定：已经在攻击门时不重复触发
	if is_attacking_door or current_state == State.BREAK_DOOR:
		return
	
	var is_sealed = false
	var is_destroyed = false
	if "is_sealed" in door:
		is_sealed = door.is_sealed
	if "is_destroyed" in door:
		is_destroyed = door.is_destroyed
	
	# 门被封且没被破坏 → 破门
	if is_sealed and not is_destroyed:
		print("[Monster] 门被封，开始破门")
		attack_door(door)
	# 门没被封 → 开门
	elif not is_sealed and not is_destroyed:
		print("[Monster] 门没封，直接开门")
		try_open_door(door)

func check_scene_boundary():
	if not navigation_region:
		return
	
	# 检查怪物是否在导航区域内
	var map_rid = navigation_region.get_navigation_map()
	var closest_point = NavigationServer3D.map_get_closest_point(map_rid, global_position)
	var distance_to_nav = global_position.distance_to(closest_point)
	var in_region = distance_to_nav < 1.0
	
	if not in_region:
		# 不管是不是追击状态，只要在外面，就强制引导回导航区域
		is_outside_scene = true
		outside_scene_timer += scene_boundary_check_interval
		
		# 强制临时切换目标为最近导航点
		if current_state != State.NAVIGATION and not is_returning_to_patrol:
			# 记录当前目标，回到导航区域后恢复
			if patrol_points.size() > 0 and current_patrol_index < patrol_points.size():
				last_valid_target = patrol_points[current_patrol_index].global_position
			# 强制设置导航代理目标为最近导航点
			if navigation_agent:
				navigation_agent.set_target_position(closest_point)
			is_returning_to_patrol = true
			print("[Monster] 超出导航区域，强制引导回最近导航点")
		
		# 超时强制传送（建议保留，避免无限卡死）
		if outside_scene_timer >= outside_scene_timeout:
			print("[Monster] 超出导航区域过久，强制传送")
			teleport_back_to_scene()
			outside_scene_timer = 0.0
	else:
		if is_outside_scene:
			# 成功回到导航区域，恢复巡逻/追击
			is_outside_scene = false
			outside_scene_timer = 0.0
			is_returning_to_patrol = false
			# 恢复之前的目标（如果是巡逻模式）
			if last_valid_target != Vector3.ZERO:
				if navigation_agent:
					navigation_agent.set_target_position(last_valid_target)
				last_valid_target = Vector3.ZERO
				print("[Monster] 回到导航区域，恢复原目标")
		outside_scene_timer = 0.0

func teleport_back_to_scene():
	if not navigation_region:
		return
	
	# 获取导航地图的 RID
	var map_rid = navigation_region.get_navigation_map()
	
	# 获取导航区域内的一个有效点
	var closest_point = NavigationServer3D.map_get_closest_point(map_rid, global_position)
	
	# 传送回导航区域内的点
	global_position = closest_point
	
	# 确保怪物落地
	global_position.y = 0.0
	
	# 保持当前移动方向，不停止
	# 如果当前没有移动方向，生成一个随机方向
	if current_move_direction == Vector3.ZERO:
		generate_random_direction()

# ========== 门攻击系统 ==========


func check_and_attack_door():
	# 只在追击或回归巡逻状态检测门
	if current_state not in [State.CHASE, State.NAVIGATION]:
		return
	
	# 正在攻击 / 攻击冷却中 / 等待追击中
	if is_attacking_door or chase_cooldown_timer > 0 or is_waiting_before_chase:
		return
	

	# 使用空间查询检测范围内的门
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# 创建球形碰撞形状用于检测
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 门检测范围
	query.shape = sphere_shape
	query.transform = global_transform
	query.collision_mask = 2  # 门在第2层碰撞层
	
	# 执行空间查询
	var results = space_state.intersect_shape(query, 100)
	
	# Debug: 打印查询结果数量
	if 启用调试信息:
		print("[Monster] 空间查询结果数量: ", results.size(), " 检测范围: ", 门检测范围)
		for i in range(min(results.size(), 3)):  # 最多打印3个结果
			var collider = results[i]["collider"]
			print("[Monster] 检测到碰撞体: ", collider.name, " 类型: ", collider.get_class())
	
	# 过滤出门节点
	var nearby_doors_in_range = []
	for result in results:
		var collider = result["collider"]
		# 向上查找门脚本节点
		var current_node = collider
		for i in range(5):  # 向上查找最多5层
			if current_node == null:
				break
			# 检查节点是否有 try_open_door 方法
			if current_node.has_method("try_open_door"):
				# 过滤掉怪物自己
				if current_node != self:
					nearby_doors_in_range.append(current_node)
					if 启用调试信息:
						print("[Monster] 找到门节点: ", current_node.name, " 距离: ", global_position.distance_to(current_node.global_position))
				break
			current_node = current_node.get_parent()
	
	if nearby_doors_in_range.is_empty():
		return
	
	# 找到最近的门
	var nearest_door = null
	var min_dist = INF
	
	for door in nearby_doors_in_range:
		var dist = global_position.distance_to(door.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_door = door
	
	if not nearest_door:
		return
	
	# 关键：只攻击 **被封且未被破坏** 的门
	var is_sealed = false
	var is_destroyed = false
	
	if "is_sealed" in nearest_door:
		is_sealed = nearest_door.is_sealed
	if "is_destroyed" in nearest_door:
		is_destroyed = nearest_door.is_destroyed
	
	# 追击状态下，只对阻挡追击路径的门开门
	# 使用射线检测：从怪物到玩家方向，如果碰到门就开门
	if current_state == State.CHASE and not is_sealed and not is_destroyed:
		# 检查门是否在怪物和玩家之间（阻挡追击路径）
		if _is_door_blocking_chase_path(nearest_door):
			print("[Monster] 追击路径被门阻挡，开门: ", nearest_door.name)
			try_open_door(nearest_door)
		return
	
	# 回归巡逻状态下，对关闭的门也开门（防止被门挡住）
	if current_state == State.NAVIGATION and not is_sealed and not is_destroyed:
		print("[Monster] 回归巡逻遇到关闭的门，开门: ", nearest_door.name)
		try_open_door(nearest_door)
		return
	
	# 门有木板且未被破坏，直接破门
	if is_sealed and not is_destroyed:
		print("[Monster] 发现被封的门，开始破坏")
		attack_door(nearest_door)
		return

# 检查门是否阻挡追击路径（门在怪物和玩家之间）
# @param door: 门节点
# @return: true=门阻挡追击路径
func _is_door_blocking_chase_path(door: Node) -> bool:
	if not Global.player or not is_instance_valid(door):
		return false
	
	var monster_pos = global_position + Vector3(0, 1.2, 0)
	var player_pos = Global.player.global_position + Vector3(0, 1.2, 0)
	
	# 从怪物向玩家发射射线
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = monster_pos
	query.to = player_pos
	query.collision_mask = 1 | 2  # 墙壁和门
	query.exclude = _get_self_exclude_rids()
	
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return false
	
	# 检查射线碰到的碰撞体是否属于该门
	var collider = result["collider"]
	var current_node = collider
	for i in range(5):
		if current_node == null:
			break
		if current_node == door:
			return true
		current_node = current_node.get_parent()
	
	return false

func find_nearby_door() -> Node:
	# 1. 修正方向：确保取的是怪物模型的朝向
	var forward_direction = -get_node("MobA").global_basis.z.normalized()
	
	# 2. 增加射线长度：从2.0增加到2.5
	var ray_length = 2.5
	
	# 3. 关键修复：抬高射线高度（防止贴地射空）
	var ray_height_offset = Vector3(0, 1.2, 0)  # 1.2米大约是胸口高度
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	
	query.from = global_position + ray_height_offset
	query.to = query.from + forward_direction * ray_length
	query.collision_mask = 2  # 确保门在第2层
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return null
	
	var collider = result.collider
	
	# 4. 鲁棒性修复：向上查找 DoorControl，不假设它一定是直接父节点
	var current_node = collider
	for i in range(3):  # 向上查找最多3层
		if current_node == null:
			break
		
		# 检查节点是否有 DoorControl 脚本（通过类名或文件名判断）
		if current_node is DoorControl:
			return current_node
		
		# 也可以通过脚本路径判断，防止循环引用问题
		if current_node.get_script() and "doorcontrol.gd" in current_node.get_script().resource_path:
			return current_node
		
		current_node = current_node.get_parent()
	
	return null

func _exit_break_door():
	is_attacking_door = false
	target_door = null
	has_reached_door = false
	attack_timer = 0.0
	# 破门结束后进入冷却，防止立即再次追击/破门
	chase_cooldown_timer = chase_cooldown_duration
	change_state(State.WANDER)

func attack_door(door_node: Node):
	is_attacking_door = true
	target_door = door_node
	has_reached_door = false
	attack_timer = 0.0
	
	if 启用调试信息:
		print("[Monster] 攻击目标: ", door_node.name)
	
	change_state(State.BREAK_DOOR)
	
	if navigation_agent and is_instance_valid(target_door):
		navigation_agent.set_target_position(target_door.global_position)

func try_open_door(door_node: Node):
	# 递归锁，防止无限递归
	if _is_opening_door:
		return
	_is_opening_door = true
	
	# 检查门是否有开门方法
	if door_node and door_node.has_method("try_open_door"):
		door_node.try_open_door(self)
	
	_is_opening_door = false

# ========== 发现玩家等待系统函数 ==========

# 开始等待追击（发现玩家后的反应时间）
func _start_wait_before_chase():
	if is_waiting_before_chase:
		return
	
	is_waiting_before_chase = true
	wait_before_chase_timer = 0.0
	has_played_alert_sound = false
	
	# 面向玩家
	if Global.player:
		rotate_toward_target(Global.player.global_position, 0.1)
	
	print("[Monster] 开始等待追击...")

# 退出等待状态，正式开始追击
func _exit_wait_before_chase():
	if not is_waiting_before_chase:
		return
	
	# 重置状态
	is_waiting_before_chase = false
	wait_before_chase_timer = 0.0
	has_played_alert_sound = false
	
	# 直接追击，不再检查视线
	print("[Monster] 正式开始追击!")
	change_state(State.CHASE)
	chase_timer = 0.0

# 播放警觉音效（发现玩家时）
# TODO: 当前音效资源未配置，需要后续添加
func play_alert_sound():
	# 预留音效播放位置
	# 示例代码（需要在项目中添加音效资源后启用）：
	# if has_node("AlertAudio"):
	#     var audio = get_node("AlertAudio")
	#     audio.play()
	
	print("[Monster] 播放警觉音效（音效资源待配置）")

func play_door_attack_animation():
	# 播放攻击门的动画
	if animation_player.has_animation("怪物拳击"):
		animation_player.play("怪物拳击")
	elif animation_player.has_animation("怪物旋风踢"):
		animation_player.play("怪物旋风踢")
