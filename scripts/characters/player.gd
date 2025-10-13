# ==============================================================================
# player.gd
# 玩家角色控制器
# 功能：管理玩家角色的移动、摄像机控制、动画系统、体力系统、布娃娃系统和背包交互
# 优化：输入处理缓存、跳跃事件迁移到_unhandled_input、健壮的节点查找方式
# 继承：CharacterBody3D - Godot的3D物理角色基础类
# ==============================================================================
extends CharacterBody3D

# 注意：使用autoload的Global脚本，不需要手动获取单例

# ==============================================================================
# 游戏参数定义
# ==============================================================================

# -------------------- 移动参数 --------------------
# 基础行走速度（单位：米/秒）
const SPEED: float = 5.0
# 奔跑速度（单位：米/秒）
const RUN_SPEED: float = 10.0
# 重力加速度（单位：米/秒²，负值表示方向向下）
const GRAVITY: float = -30.0
# 跳跃初速度（单位：米/秒，正值表示方向向上）
const JUMP_VELOCITY: float = 8.0

# -------------------- 摄像机控制参数 --------------------
# 鼠标灵敏度系数（越高旋转越快）
@export var mouse_sensitivity: float = 0.1
# 摄像机最小俯仰角度（限制向下看的最大角度）
@export var min_pitch: float = -90.0
# 摄像机最大俯仰角度（限制向上看的最大角度）
@export var max_pitch: float = 90.0

# -------------------- 动画系统参数 --------------------
# 行走动画播放阈值（当速度大于此值时播放行走动画）
@export var walk_threshold: float = 0.1
# 奔跑动画播放阈值（当速度大于此值时播放奔跑动画）
@export var run_threshold: float = 7.0

# -------------------- 动画状态枚举 --------------------
enum AnimationState {
	IDLE,   # 闲置状态
	WALK,   # 行走状态
	RUN,    # 奔跑状态
	JUMP,   # 跳跃状态
	FALL    # 下落状态
}
# 当前动画状态跟踪变量
var current_animation: int = AnimationState.IDLE

# -------------------- 体力系统参数 --------------------
# 最大体力值上限
@export var max_stamina: float = 100.0
# 当前体力值（初始化为1用于快速测试体力耗尽效果）
var current_stamina: float = 1.0
# 体力恢复速率（每秒恢复量，单位：百分比）
var stamina_regen_rate: float = 1.0 / 200.0
# 体力消耗速率（每秒消耗量，单位：百分比）
var stamina_drain_rate: float = 1.0 / 8.0
# 奔跑允许标志（控制是否可以奔跑）
var can_sprint: bool = true

# -------------------- 节点引用 --------------------
# 动画播放器节点
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"
# 主摄像机节点
@onready var camera: Camera3D = $Skeleton3D/BoneAttachment3D/Camera3D
# 体力条UI控制器
@onready var stamina_ui: Control = $Skeleton3D/BoneAttachment3D/Camera3D/Control
# 背包数据节点
@onready var inventory_node: Node = $inventory

# -------------------- 内部状态变量 --------------------
# 摄像机俯仰角（垂直旋转，X轴）
var pitch: float = 0.0
# 角色偏航角（水平旋转，Y轴）
var yaw: float = 0.0
# 跳跃状态标志（用于动画切换）
var is_jumping: bool = false

# -------------------- 布娃娃系统变量 --------------------
# 布娃娃模式专用摄像机
@onready var ragdoll_cam: Camera3D = $RagdollCamera
# 骨骼物理模拟器（用于激活布娃娃物理）
@onready var simulator: PhysicalBoneSimulator3D = $Skeleton3D/PhysicalBoneSimulator3D
# 布娃娃状态标志
var ragdolling: bool = false
# 布娃娃恢复计时器
var ragdoll_timer: SceneTreeTimer



# ==============================================================================
# 生命周期方法
# ==============================================================================

# 节点进入场景树时的初始化方法
func _ready() -> void:
	# 设置鼠标捕获模式（隐藏鼠标并锁定在窗口中）
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 设置全局玩家引用（方便其他脚本访问）
	Global.player = self
	
	# 初始化摄像机朝向（重置为默认角度）
	camera.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	
	# 播放初始闲置动画
	animation_player.play("Main/Idle")
	
	# 初始化体力值并更新UI显示
	current_stamina = max_stamina
	stamina_ui.update_stamina(current_stamina, max_stamina)

# ==============================================================================
# 输入处理方法
# ==============================================================================

# 处理未被其他节点处理的输入事件
# @param event: 输入事件对象
func _unhandled_input(event: InputEvent) -> void:
	# ESC键处理 - 切换鼠标捕获状态
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		# 切换鼠标可见性状态
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
		# 如果背包打开，关闭背包
		toggle_inventory(false)
	
	# 背包按键处理
	if Input.is_action_just_pressed("openbag"):
		toggle_inventory()
	
	# 跳跃输入处理（优化：移到_unhandled_input以避免每帧查询）
	if event is InputEventAction and event.action == "ui_jump" and event.pressed and is_on_floor():
		# 设置跳跃初速度
		velocity.y = JUMP_VELOCITY
		is_jumping = true
	
	# 鼠标移动处理（视角控制）
	if event is InputEventMouseMotion:
		# 应用鼠标灵敏度系数
		var delta = event.relative * mouse_sensitivity
		yaw -= delta.x   # 水平旋转（左右视角）
		pitch -= delta.y # 垂直旋转（上下视角）
		
		# 限制俯仰角度范围，防止摄像机翻转
		pitch = clamp(pitch, min_pitch, max_pitch)
	
# 恢复玩家体力的方法
# @param percent: 要恢复的体力百分比（0-100）
# @description: 被消耗品效果调用，用于按百分比恢复玩家体力
# @description: 包含安全检查确保百分比在有效范围内，并避免UI更新时的空引用错误
func restore_stamina_percent(percent: float) -> void:
	# 计算恢复量，使用clamp确保百分比在有效范围内
	var recovery_amount = max_stamina * (clamp(percent, 0.0, 100.0) / 100.0)
	
	# 更新体力值，确保不超过最大值
	current_stamina = min(current_stamina + recovery_amount, max_stamina)
	
	# 安全地更新UI，避免空引用错误
	if stamina_ui and is_instance_valid(stamina_ui) and stamina_ui.has_method("update_stamina"):
		stamina_ui.update_stamina(current_stamina, max_stamina)

# ==============================================================================
# 物理处理方法
# ==============================================================================

# 物理帧处理，每物理帧调用一次
# @param delta: 帧间隔时间（秒）
func _physics_process(delta: float) -> void:
	# 优化：缓存输入状态（每帧只查询一次）
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	var is_running_held = Input.is_action_pressed("ui_run")
	
	# -------------------- 重力系统 --------------------
	# 应用重力加速度
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# -------------------- 移动处理 --------------------
	# 奔跑状态判断
	var want_to_sprint = is_running_held and can_sprint
	var current_speed = SPEED  # 默认行走速度
	
	# 如果满足奔跑条件，切换到奔跑速度
	if want_to_sprint and velocity.length() > walk_threshold:
		current_speed = RUN_SPEED
	
	# 计算移动方向向量（基于摄像机视角）
	var direction = (-camera.global_transform.basis.z * input_dir.y + 
			 camera.global_transform.basis.x * input_dir.x).normalized()
	
	# 应用水平速度
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# 平滑停止效果
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	# 执行物理移动（自动处理碰撞）
	move_and_slide()

	# -------------------- 旋转更新 --------------------
	# 角色水平旋转（跟随摄像机偏航）
	rotation_degrees.y = yaw
	# 摄像机俯仰旋转
	camera.rotation_degrees.x = pitch
	# 摄像机特殊处理：需要180度旋转以修正方向
	camera.rotation_degrees.y = -180.0
	
	# 更新动画状态
	update_animation()
	
	# 更新体力系统（传入缓存的奔跑状态，避免重复查询）
	handle_stamina(delta, is_running_held)
	
# 体力系统核心逻辑
# @param delta: 帧间隔时间（秒）
# @param is_running_held: 奔跑按键是否被按住
# @description: 根据玩家动作动态调整体力值，并在体力耗尽时触发布娃娃系统
func handle_stamina(delta: float, is_running_held: bool) -> void:
	# 有效奔跑状态判断条件：
	# 1. 按住奔跑键
	# 2. 允许奔跑（can_sprint为true）
	# 3. 角色正在移动（速度大于行走阈值）
	var is_sprinting = is_running_held && can_sprint && velocity.length() > walk_threshold
	
	if is_sprinting:
		# 奔跑时消耗体力
		current_stamina = clamp(current_stamina - (delta * stamina_drain_rate * 100), 0, max_stamina)
		
		# 体力耗尽时触发布娃娃系统（玩家瘫倒）
		if current_stamina <= 0 and not ragdolling:
			start_ragdoll_sequence()
	else:
		# 不奔跑时恢复体力
		current_stamina = clamp(current_stamina + (delta * stamina_regen_rate * 100), 0, max_stamina)
	
	# 更新UI显示
	if stamina_ui and is_instance_valid(stamina_ui) and stamina_ui.has_method("update_stamina"):
		stamina_ui.update_stamina(current_stamina, max_stamina)
	

# 更新动画状态
# @description: 根据角色当前状态选择合适的动画播放
func update_animation() -> void:
	var speed = velocity.length()
	var is_moving = speed > walk_threshold
	
	# 动画状态判断逻辑（优先级：跳跃 > 下落 > 移动 > 闲置）
	if is_jumping:
		set_animation(AnimationState.JUMP)
	elif not is_on_floor():
		set_animation(AnimationState.FALL)
	elif is_moving:
		# 根据速度选择行走或奔跑动画
		set_animation(AnimationState.RUN if speed > run_threshold else AnimationState.WALK)
	else:
		set_animation(AnimationState.IDLE)

# 设置动画状态
# @param state: 要切换到的动画状态
# @description: 切换动画播放，并更新当前动画状态变量
func set_animation(state: AnimationState) -> void:
	# 避免重复设置相同的动画状态
	if current_animation == state:
		return
	
	# 更新状态变量
	current_animation = state
	
	# 根据状态播放对应动画
	match state:
		AnimationState.IDLE: animation_player.play("Main/Idle")
		AnimationState.WALK: animation_player.play("Main/Walk")
		AnimationState.RUN:  animation_player.play("Main/Run")
		AnimationState.JUMP: animation_player.play("Main/Jump")
		AnimationState.FALL: animation_player.play("Main/Fall")

# 动画播放完成回调
# @param anim_name: 已完成播放的动画名称
# @description: 处理动画结束后的逻辑，如重置跳跃状态
func _on_animation_finished(anim_name: String) -> void:
	# 跳跃动画播放完成后，重置跳跃状态
	if anim_name == "Main/Jump":
		is_jumping = false

# ==============================================================================
# 布娃娃系统方法
# ==============================================================================

# 开始布娃娃模式序列
# @description: 当体力耗尽时，触发布娃娃系统让角色瘫倒
func start_ragdoll_sequence() -> void:
	# 设置布娃娃状态标志
	ragdolling = true
	
	# 1. 激活骨骼物理模拟
	# 使用缓存的simulator变量，避免硬编码路径
	simulator.active = true
	simulator.physical_bones_start_simulation()

	# 2. 暂停角色控制和动画
	set_physics_process(false)  # 禁用物理处理，停止移动逻辑
	animation_player.stop()     # 停止当前动画
	
	# 3. 切换到布娃娃专用摄像机
	camera.current = false      # 禁用主摄像机
	ragdoll_cam.current = true  # 启用布娃娃摄像机
	
	# 4. 设置自动恢复计时器
	ragdoll_timer = get_tree().create_timer(1.0)  # 创建1秒计时器
	ragdoll_timer.timeout.connect(end_ragdoll_sequence)

# 结束布娃娃状态，恢复正常控制
# @description: 平滑地从布娃娃物理状态过渡回正常角色控制
# @note: 使用协程实现平滑过渡
func end_ragdoll_sequence() -> void:
	# 重置布娃娃相机位置，为过渡做准备
	reset_ragdoll_camera()
	
	# 等待1秒让相机平稳过渡
	await get_tree().create_timer(1.0).timeout
	
	# 停止物理模拟并禁用布娃娃系统
	simulator.physical_bones_stop_simulation()
	simulator.active = false
	
	# 切换回主摄像机
	ragdoll_cam.current = false
	camera.current = true
	
	# 等待一小段时间让角色姿态稳定
	await get_tree().create_timer(0.1).timeout
	
	# 恢复玩家控制和动画
	set_physics_process(true)
	animation_player.play("Main/Idle")
	
	# 重置布娃娃相关状态
	ragdolling = false
	can_sprint = false  # 初始禁用奔跑能力
	
	# 设置延迟恢复奔跑能力的计时器（3秒后恢复）
	var regen_timer = get_tree().create_timer(3.0)
	regen_timer.timeout.connect(func():
		can_sprint = true
		print("奔跑能力已恢复")
	)

# 重置布娃娃相机位置和朝向
# @description: 确保布娃娃模式下相机以合适的角度和距离观察角色
# @note: 在布娃娃模式切换回正常模式前调用，以提供良好的视觉过渡
func reset_ragdoll_camera() -> void:
	# 1. 确定相机的注视目标点
	# 选择角色脊柱位置作为目标，提供自然的角色观察视角
	var center: Vector3 = $"Skeleton3D/PhysicalBoneSimulator3D/Physical Bone mixamorig_Spine".global_position

	# 2. 设置相机位置
	# 将相机定位在角色右前方稍高处，提供良好的第三人称视角
	ragdoll_cam.global_position = center + Vector3(0.3, 0.5, 0.3)

	# 3. 设置相机朝向
	# 确保相机朝向角色中心，且顶部朝上（保证画面方向正确）
	ragdoll_cam.look_at(center, Vector3.UP)

# 立即从布娃娃状态恢复站立
# @description: 提供一种从布娃娃状态快速恢复的机制，无需等待自动恢复
# @note: 可用于开发调试或特殊游戏机制
func recover_from_ragdoll() -> void:
	# 1. 停止布娃娃物理模拟
	simulator.active = false
	simulator.physical_bones_stop_simulation()
	
	# 2. 确保角色位置正确
	# 将角色移到骨骼位置，避免位置不一致导致的瞬移
	global_position = $Skeleton3D.global_position
	
	# 3. 切换回主摄像机
	ragdoll_cam.current = false
	camera.current = true
	
	# 4. 恢复角色控制
	set_physics_process(true)
	ragdolling = false
	
	# 5. 恢复体力和状态
	# 给予少量体力，避免立即再次进入布娃娃状态
	current_stamina = max_stamina * 0.1
	can_sprint = true
	
	# 6. 重置动画状态
	set_animation(AnimationState.IDLE)

# ==============================================================================
# 背包控制系统
# ==============================================================================

# 背包界面引用（使用缓存优化性能）
var inventory_gui: Node = null
# 背包打开状态标志
var is_inventory_open: bool = false

# 切换背包的显示状态
# @param force_state: 强制设置的状态，null表示切换当前状态
# @description: 管理背包的打开和关闭逻辑，包括UI显示、鼠标模式切换和内容刷新
func toggle_inventory(force_state = null) -> void:
	# 健壮性检查：如果背包界面引用无效，尝试重新获取
	if inventory_gui == null or not is_instance_valid(inventory_gui):
		# 优化：优先使用组查询查找背包界面（健壮性更高）
		var inventory_nodes = get_tree().get_nodes_in_group("inventory_gui")
		if inventory_nodes.size() > 0:
			inventory_gui = inventory_nodes[0]
		else:
			# 后备方案：使用路径查找
			inventory_gui = get_tree().root.get_node_or_null("InventoryGUI3D")
		
	# 安全设置背包数据引用
	if inventory_gui != null and inventory_node != null and inventory_gui.has_method("set_inventory"):
		inventory_gui.set_inventory(inventory_node)
		
	# 错误处理：如果仍未找到背包界面，打印警告
	if inventory_gui == null:
		print("警告: 未找到背包界面节点，请确保InventoryGUI3D场景已添加到主场景中")
		return
	
	# 确定目标显示状态
	var target_state = not is_inventory_open if force_state == null else force_state
	
	# 避免不必要的状态切换
	if target_state == is_inventory_open:
		return
	
	# 更新背包状态和可见性
	is_inventory_open = target_state
	inventory_gui.visible = target_state
	
	# 根据状态切换鼠标模式
	if target_state:
		# 打开背包时显示鼠标，便于UI交互
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# 打开背包时刷新内容显示
		if inventory_gui.has_method("refresh"):
			inventory_gui.refresh()
	else:
		# 关闭背包时重新捕获鼠标，恢复游戏控制
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
