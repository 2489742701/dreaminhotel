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
@export var 鼠标灵敏度: float = 0.1
# 摄像机最小俯仰角度（限制向下看的最大角度）
@export var 最小俯仰角: float = -70.0
# 摄像机最大俯仰角度（限制向上看的最大角度）
@export var 最大俯仰角: float = 120.0

# -------------------- 动画系统参数 --------------------
# 行走动画的播放阈值（速度低于此值时播放行走动画）
@export var 行走阈值: float = 0.1

# 奔跑动画的播放阈值（速度高于此值时播放奔跑动画）
@export var 奔跑阈值: float = 7.0

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
@export var 最大体力: float = 100.0
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
# 背包数据节点
@onready var inventory_node: Node = $inventory
# 手持装备显示节点（备用方案）
@onready var hand_take: MeshInstance3D = $Skeleton3D/BoneAttachment3D/Camera3D/HandTake
# 手电筒灯光节点
@onready var flashlight_light: SpotLight3D = $Skeleton3D/BoneAttachment3D/Camera3D/SpotLight3D

# -------------------- UI管理器 --------------------
# UI管理器（统一管理所有UI组件）
var ui_manager: Node = null
# 玩家ID（多人游戏支持）
var player_id: int = -1

# -------------------- 内部状态变量 --------------------
# 摄像机俯仰角（垂直旋转，X轴）
var pitch: float = 0.0
# 角色偏航角（水平旋转，Y轴）
var yaw: float = 0.0
# 跳跃状态标志（用于动画切换）
var is_jumping: bool = false
# 鼠标滚轮防抖计时器（防止频繁切换物品）
var wheel_cooldown: float = 0.0
const WHEEL_COOLDOWN_TIME: float = 0.2  # 防抖时间（秒）

# -------------------- 交互系统参数 --------------------
# 用于存储当前处于交互范围内的门（或其他可交互物体）
var nearby_doors: Array[Node] = []

# -------------------- 布娃娃系统变量 --------------------
# 布娃娃模式专用摄像机
@onready var ragdoll_cam: Camera3D = $RagdollCamera
# 骨骼物理模拟器（用于激活布娃娃物理）
@onready var simulator: PhysicalBoneSimulator3D = $Skeleton3D/PhysicalBoneSimulator3D
# 布娃娃状态标志
var ragdolling: bool = false
# 布娃娃恢复计时器
var ragdoll_timer: SceneTreeTimer

# -------------------- 移动端输入变量 --------------------
# 移动端输入向量（来自虚拟摇杆）
var _mobile_input_vector: Vector2 = Vector2.ZERO
# 移动端移动目标（来自点击地面）
var _mobile_move_target: Vector3 = Vector3.ZERO

# -------------------- 手电筒系统变量 --------------------
# 手电筒开关状态
var flashlight_on: bool = false
# 手电筒电量计时器（用于电量消耗）
var flashlight_battery_timer: float = 0.0



# ==============================================================================
# 生命周期方法
# ==============================================================================

# 节点进入场景树时的初始化方法
func _ready() -> void:
	# 设置鼠标捕获模式（隐藏鼠标并锁定在窗口中）
	Input.set_mouse_mode(Input.MouseMode.MOUSE_MODE_CAPTURED)
	
	# 将玩家添加到"player"组中，方便其他脚本检测
	add_to_group("player")
	
	# 初始化摄像机朝向（重置为默认角度）
	camera.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	
	# 创建UI管理器实例（每个玩家有自己的UI管理器）
	var ui_manager_script = load("res://scripts/ui/PlayerUIManager.gd")
	ui_manager = ui_manager_script.new()
	
	# 获取UI节点引用
	var stamina_ui = $Skeleton3D/BoneAttachment3D/Camera3D/Control
	var hotbar_ui = $Skeleton3D/BoneAttachment3D/Camera3D/Control/HotbarUI
	var inventory_gui = $InventoryGUI3D
	var hand_take_node = $Skeleton3D/BoneAttachment3D/Camera3D/HandTake
	
	# 绑定UI组件到管理器（传入玩家节点作为拥有者）
	ui_manager.bind_ui(stamina_ui, hotbar_ui, inventory_gui, hand_take_node, self)
	
	# 添加到玩家管理器
	player_id = Global.player_manager.add_player(self, true)
	Global.player_manager.set_player_ui_manager(player_id, ui_manager)
	
	# 播放初始闲置动画
	animation_player.play("Main/Idle")
	
	# 初始化体力值并更新UI显示
	current_stamina = 最大体力
	ui_manager.update_stamina(current_stamina, 最大体力)
	
	# 设置背包的拥有者玩家
	if inventory_node and inventory_node.has_method("set_owner_player"):
		inventory_node.set_owner_player(self)
	
	# 设置hand_take的拥有者玩家
	if hand_take_node and hand_take_node.has_method("set_owner_player"):
		hand_take_node.set_owner_player(self)
	
	# 初始化背包UI状态
	ui_manager.set_inventory_visible(false)
	ui_manager.set_inventory(inventory_node)
	
	# 初始化快捷栏背包引用
	ui_manager.set_hotbar_inventory(inventory_node)
	
	# 连接背包系统事件到UI管理器
	ui_manager.connect_inventory_signals(inventory_node)
	
	# 初始化移动端输入
	_mobile_input_vector = Vector2.ZERO
	_mobile_move_target = Vector3.ZERO
	
	# 初始化手电筒状态
	if flashlight_light:
		flashlight_light.visible = false

# ==============================================================================
# 输入处理方法
# ==============================================================================

# 处理未被其他节点处理的输入事件
# @param event: 输入事件对象
func _unhandled_input(event: InputEvent) -> void:
	# ESC键处理 - 优先处理背包关闭，然后切换鼠标模式
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		# 如果背包打开，先关闭背包
		if is_inventory_open:
			toggle_inventory(false)
		else:
			# 如果背包未打开，切换鼠标捕获状态
			Input.set_mouse_mode(
				Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
				else Input.MOUSE_MODE_CAPTURED
			)
	
	# 背包按键处理 - 使用event对象检查按键，确保UI焦点状态下也能正确响应
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		toggle_inventory()
	
	# ========== 统一的鼠标按键处理 ==========
	# 根据当前手持物品类型，动态决定左键和右键的行为
	if event is InputEventMouseButton and event.pressed:
		# 左键处理
		if event.button_index == MOUSE_BUTTON_LEFT:
			Global.debug_print("检测到左键点击", "Player")
			_handle_left_click()
		
		# 右键处理
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			Global.debug_print("检测到右键点击", "Player")
			_handle_right_click()
		
		# 鼠标滚轮切换手持物
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			switch_equipped_item(event.button_index == MOUSE_BUTTON_WHEEL_UP)
	
	# 丢弃物品按键处理（G键）
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		drop_equipped_item()
	
	# 手电筒开关按键处理（F键）
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		toggle_flashlight()
	
	# 鼠标移动处理（视角控制）
	if event is InputEventMouseMotion:
		# 应用鼠标灵敏度系数
		var delta = event.relative * 鼠标灵敏度
		yaw -= delta.x   # 水平旋转（左右视角）
		pitch -= delta.y # 垂直旋转（上下视角）
		
		# 限制俯仰角度范围，防止摄像机翻转
		pitch = clamp(pitch, 最小俯仰角, 最大俯仰角)
	
# 恢复玩家体力的方法
# @param percent: 要恢复的体力百分比（0-100）
# @description: 被消耗品效果调用，用于按百分比恢复玩家体力
# @description: 包含安全检查确保百分比在有效范围内，并避免UI更新时的空引用错误
func restore_stamina_percent(percent: float) -> void:
	# 计算恢复量，使用clamp确保百分比在有效范围内
	var recovery_amount = 最大体力 * (clamp(percent, 0.0, 100.0) / 100.0)
	
	# 更新体力值，确保不超过最大值
	current_stamina = min(current_stamina + recovery_amount, 最大体力)
	
	# 安全地更新UI，避免空引用错误
	if ui_manager:
		ui_manager.update_stamina(current_stamina, 最大体力)

# ==============================================================================
# 物理处理方法
# ==============================================================================

# 物理帧处理，每物理帧调用一次
# @param delta: 帧间隔时间（秒）
func _physics_process(delta: float) -> void:
	# 跳跃输入处理 - 在物理帧中处理更可靠
	if Input.is_action_just_pressed("ui_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		is_jumping = true
	
	# 优化：缓存输入状态（每帧只查询一次）
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	var is_running_held = Input.is_action_pressed("ui_run")
	
	# 优先使用移动端输入
	if _mobile_input_vector != Vector2.ZERO:
		input_dir = _mobile_input_vector
	elif _mobile_move_target != Vector3.ZERO:
		# 计算到目标的移动方向
		var to_target = _mobile_move_target - global_position
		to_target.y = 0
		var distance = to_target.length()
		
		if distance > 0.5:
			input_dir = Vector2(to_target.x, to_target.z).normalized()
		else:
			# 到达目标，清除移动目标
			_mobile_move_target = Vector3.ZERO
			input_dir = Vector2.ZERO
	
	# -------------------- 重力系统 --------------------
	# 应用重力加速度
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	
	# -------------------- 移动处理 --------------------
	# 奔跑状态判断
	var want_to_sprint = is_running_held and can_sprint
	var current_speed = SPEED  # 默认行走速度
	
	# 检查摄像机俯仰角度，如果低头或抬头则强制步行
	var is_looking_up_or_down = abs(pitch) > 30.0  # 俯仰角超过30度视为低头或抬头
	
	# 只有在不低头/抬头且满足奔跑条件时，才切换到奔跑速度
	if want_to_sprint and velocity.length() > 行走阈值 and not is_looking_up_or_down:
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
	
	# 更新手电筒系统
	handle_flashlight(delta)
	
# 体力系统核心逻辑
# @param delta: 帧间隔时间（秒）
# @param is_running_held: 奔跑按键是否被按住
# @description: 根据玩家动作动态调整体力值，并在体力耗尽时触发布娃娃系统
func handle_stamina(delta: float, is_running_held: bool) -> void:
	# 有效奔跑状态判断条件：
	# 1. 按住奔跑键
	# 2. 允许奔跑（can_sprint为true）
	# 3. 角色正在移动（速度大于行走阈值）
	var is_sprinting = is_running_held && can_sprint && velocity.length() > 行走阈值
	
	if is_sprinting:
		# 奔跑时消耗体力
		current_stamina = clamp(current_stamina - (delta * stamina_drain_rate * 100), 0, 最大体力)
		
		# 体力耗尽时触发布娃娃系统（玩家瘫倒）
		if current_stamina <= 0 and not ragdolling:
			start_ragdoll_sequence()
	else:
		# 不奔跑时恢复体力
		current_stamina = clamp(current_stamina + (delta * stamina_regen_rate * 100), 0, 最大体力)
	
	# 更新UI显示
	if ui_manager:
		ui_manager.update_stamina(current_stamina, 最大体力)
	

# 更新动画状态
# @description: 根据角色当前状态选择合适的动画播放
func update_animation() -> void:
	var speed = velocity.length()
	var is_moving = speed > 行走阈值
	
	# 检查是否低头或抬头
	var is_looking_up_or_down = abs(pitch) > 30.0
	
	# 动画状态判断逻辑（优先级：跳跃 > 下落 > 移动 > 闲置）
	if is_jumping:
		set_animation(AnimationState.JUMP)
	elif not is_on_floor():
		set_animation(AnimationState.FALL)
	elif is_moving:
		# 如果低头或抬头，强制使用步行动画
		if is_looking_up_or_down:
			set_animation(AnimationState.WALK)
		else:
			# 根据速度选择行走或奔跑动画
			set_animation(AnimationState.RUN if speed > 奔跑阈值 else AnimationState.WALK)
	else:
		set_animation(AnimationState.IDLE)
	
	# 额外的跳跃状态安全检查：确保角色在落地时重置跳跃状态
	if not is_jumping and not is_on_floor():
		# 确保跳跃状态与实际物理状态一致
		if velocity.y > 0:
			is_jumping = true

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
		AnimationState.FALL: animation_player.play("Main/Idle")  # 临时方案：使用Idle代替Fall动画

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
	

	
	# 恢复玩家控制
	set_physics_process(true)
	
	# 显式重置动画状态并播放闲置动画，确保角色有动画
	current_animation = AnimationState.IDLE
	animation_player.play("Main/Idle")
	
	# 重置跳跃状态
	is_jumping = false
	
	# 重置布娃娃相关状态
	ragdolling = false
	can_sprint = false  # 初始禁用奔跑能力
	
	# 设置延迟恢复奔跑能力的计时器（3秒后恢复）
	var regen_timer = get_tree().create_timer(3.0)
	regen_timer.timeout.connect(func():
		can_sprint = true
		Global.debug_print("奔跑能力已恢复", "Player")
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
	current_stamina = 最大体力 * 0.1
	can_sprint = true
	
	# 6. 重置动画状态
	set_animation(AnimationState.IDLE)

# ==============================================================================
# 背包控制系统
# ==============================================================================

# 背包打开状态标志
var is_inventory_open: bool = false
# 当前装备的物品资源
var current_equipped_item: Item = null

# 切换背包的显示状态
# @param force_state: 强制设置的状态，null表示切换当前状态
# @description: 管理背包的打开和关闭逻辑，包括UI显示、鼠标模式切换和内容刷新
func toggle_inventory(force_state = null) -> void:
	# 确定目标显示状态
	var target_state = not is_inventory_open if force_state == null else force_state
	
	# 避免不必要的状态切换
	if target_state == is_inventory_open:
		return
	
	# 更新背包状态和可见性
	is_inventory_open = target_state
	ui_manager.set_inventory_visible(target_state)
	
	# 根据状态切换鼠标模式
	if target_state:
		# 打开背包时显示鼠标，便于UI交互
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# 打开背包时刷新内容显示
		if ui_manager:
			ui_manager.refresh_inventory()
	else:
		# 关闭背包时重新捕获鼠标，恢复游戏控制
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# 关闭背包时重置滚轮切换状态，确保使用最新的背包顺序
		_reset_wheel_switch_state()
		# 【核心修复】强制重置手持物动画状态，防止左键被锁定
		_reset_hand_take_animation_state()
		# # 重要：释放UI焦点，确保鼠标左键能正常工作
		# if get_viewport():
		# 	get_viewport().gui_release_focus()

# ==============================================================================
# 装备显示系统
# ==============================================================================

# 装备物品并在手中显示
# @param item: 要装备的物品
func equip_item(item: Item) -> void:
	# 安全检查
	if not item:
		Global.debug_print("尝试装备空物品", "Player")
		return
	
	# 检查是否已经装备了相同的物品
	if current_equipped_item == item:
		Global.debug_print("已经装备了 " + item.名称翻译键 + "，无需重复装备", "Player")
		return
	
	# 先卸下当前装备的物品
	unequip_item()
	
	# 设置当前装备的物品
	current_equipped_item = item
	
	# 更新背包系统的装备索引
	if inventory_node and is_instance_valid(inventory_node):
		# 查找物品在背包中的索引
		var item_index = -1
		for i in range(inventory_node.items.size()):
			var item_entry = inventory_node.items[i]
			if item_entry and item_entry.has("item") and item_entry.item == item:
				item_index = i
				break
		
		if item_index >= 0:
			# 调用背包系统的装备方法，确保equipped_id正确更新
			inventory_node.equip(item_index)
			
			# 更新快捷栏选中状态
			if ui_manager:
				ui_manager.set_hotbar_inventory(inventory_node)
			
			# 确保索引不超过前三个槽位
			var hotbar_index = item_index if item_index < 3 else -1
			if hotbar_index >= 0:
				# 通过UI管理器装备物品
				if ui_manager:
					ui_manager.show_item_mesh(item)
					ui_manager.update_item_name(item.名称翻译键)
		else:
			Global.debug_print("无法在背包中找到物品 " + item.名称翻译键, "Player")
	
	# 显示物品在手中
	show_item_in_hand(item)
	
	# 更新UI显示物品名称
	更新UI物品名称显示(item.名称翻译键)
	
	# 从背包获取物品状态信息并显示
	更新物品状态显示()
	
	# 如果装备的是手电筒，应用手电筒设置
	if item.物品类型 == Item.Kind.FLASHLIGHT:
		apply_flashlight_settings()
		# 如果手电筒之前是开启状态且还有电，保持开启
		if flashlight_on and item.当前电量 > 0:
			if flashlight_light:
				flashlight_light.visible = true
		else:
			# 否则关闭手电筒
			flashlight_on = false
			if flashlight_light:
				flashlight_light.visible = false
	else:
		# 装备非手电筒物品时，关闭手电筒
		flashlight_on = false
		if flashlight_light:
			flashlight_light.visible = false
	
	Global.debug_print("已装备: " + item.名称翻译键, "Player")

# 卸下当前装备的物品
func unequip_item() -> void:
	if current_equipped_item:
		Global.debug_print("卸下: " + current_equipped_item.名称翻译键, "Player")
		current_equipped_item = null
	
	# # 重置背包系统的装备状态，确保下次装备能正确工作
	# if inventory_node and is_instance_valid(inventory_node):
	# 	inventory_node.equipped_id = -1
	
	# 隐藏手中的物品显示
	hide_item_in_hand()
	
	# 更新UI显示为"空手"
	更新UI物品名称显示("空手")

# 在手中显示物品的Mesh
# 显示手中的物品
func show_item_in_hand(item: Item) -> void:
	# 安全检查
	if not hand_take or not is_instance_valid(hand_take):
		Global.debug_print("HandTake节点无效", "Player")
		return
	
	# 检查物品是否有Mesh资源
	if not item or not item.模型:
		Global.debug_print("物品没有模型资源", "Player")
		return
	
	# 通过UI管理器显示物品
	if ui_manager:
		ui_manager.show_item_mesh(item)
	else:
		Global.debug_print("UI管理器未初始化", "Player")
		# 备用方案：直接设置Mesh
		var model_resource = item.模型 if item.get("模型") != null else null
		if model_resource:
			# 直接使用Mesh
			hand_take.mesh = model_resource
			hand_take.visible = true
			if hand_take.get("hand_item_scale") != null:
				var scale_value = hand_take.hand_item_scale
				hand_take.scale = Vector3(scale_value, scale_value, scale_value)
			else:
				hand_take.scale = Vector3.ONE

# 获取当前装备的物品（供外部调用）
func get_equipped_item() -> Item:
	return current_equipped_item

# 隐藏手中的物品显示
func hide_item_in_hand() -> void:
	if ui_manager:
		ui_manager.clear_item()
	elif hand_take and is_instance_valid(hand_take):
		# 备用方案：直接隐藏Mesh
		hand_take.visible = false
		hand_take.mesh = null
		# 如果hand_take有is_showing_item属性，也设置为false
		if hand_take.get("is_showing_item") != null:
			hand_take.is_showing_item = false

# 检查玩家是否装备了斧头
# @return: 如果装备了斧头返回true，否则返回false
func has_axe() -> bool:
	# 斧头现在是TOOL类型，检查TOOL类型物品
	if current_equipped_item and current_equipped_item.物品类型 == Item.Kind.TOOL:
		# 检查是否是斧头（可以根据物品名称或ID判断）
		var is_axe = "axe" in current_equipped_item.名称翻译键.to_lower() or "斧头" in current_equipped_item.名称翻译键
		Global.debug_print("斧头检测 - 当前装备物品：" + current_equipped_item.名称翻译键 + " 是否是斧头：" + str(is_axe), "Player")
		return is_axe
	Global.debug_print("斧头检测失败：没有装备工具或物品无效", "Player")
	return false

# 获取玩家相机前方方向（供攻击检测系统使用）
func get_camera_forward() -> Vector3:
	# 如果有相机节点，使用相机的前方方向
	if has_node("camera") and is_instance_valid(get_node("camera")):
		var cam = get_node("camera")
		# 由于相机被旋转了180度（y = -180.0），我们需要修正方向
		# 相机的前方应该是 -Z 轴，但旋转后需要取反
		return cam.global_transform.basis.z.normalized()
	# 备用方案：使用玩家自身的前方
	return -global_transform.basis.z.normalized()

# ==============================================================================
# 统一的鼠标按键处理系统
# ==============================================================================
# 根据手持物品类型，智能决定左键和右键的行为
# 初学者提示：这种设计模式叫"策略模式"，不同物品有不同的交互策略

# 处理左键点击
# @description: 根据物品类型执行不同操作
# - 武器/工具: 攻击/使用
# - 消耗品: 攻击（不推荐，但允许）
# - 封门物品: 攻击（不推荐，但允许）
func _handle_left_click() -> void:
	if not current_equipped_item:
		Global.debug_print("左键：没有装备物品", "Player")
		return
	
	match current_equipped_item.物品类型:
		Item.Kind.WEAPON, Item.Kind.TOOL:
			# 武器和工具：攻击/使用
			Global.debug_print("左键：执行攻击/使用 - " + current_equipped_item.名称翻译键, "Player")
			attack_with_equipped_item()
		Item.Kind.CONSUMABLE:
			# 消耗品：左键也可以使用（备选方案）
			Global.debug_print("左键：使用消耗品 - " + current_equipped_item.名称翻译键, "Player")
			use_equipped_item()
		Item.Kind.SEAL_ITEM:
			# 封门物品：左键提示应该用右键封门
			Global.debug_print("左键：封门物品请使用右键对门进行封印", "Player")
		Item.Kind.FLASHLIGHT:
			# 手电筒：左键切换开关
			toggle_flashlight()
		_:
			Global.debug_print("左键：该物品类型无交互行为", "Player")

# 处理右键点击
# @description: 根据物品类型执行不同操作
# - 消耗品: 使用/饮用
# - 封门物品: 封门（需要面对门）
# - 武器/工具: 特殊功能（预留）
# - 手电筒: 切换开关
func _handle_right_click() -> void:
	if not current_equipped_item:
		Global.debug_print("右键：没有装备物品", "Player")
		return
	
	match current_equipped_item.物品类型:
		Item.Kind.CONSUMABLE:
			# 消耗品：使用/饮用
			Global.debug_print("右键：使用消耗品 - " + current_equipped_item.名称翻译键, "Player")
			use_equipped_item()
		Item.Kind.SEAL_ITEM:
			# 封门物品：封门功能（由门控制系统处理）
			Global.debug_print("右键：封门物品 - 等待门控制系统响应", "Player")
			# 不在这里处理，让 doorcontrol.gd 的 _input 响应
		Item.Kind.WEAPON, Item.Kind.TOOL:
			# 武器和工具：右键预留特殊功能（如瞄准）
			Global.debug_print("右键：武器/工具特殊功能（未实现）", "Player")
		Item.Kind.FLASHLIGHT:
			# 手电筒：右键切换开关
			toggle_flashlight()
		_:
			Global.debug_print("右键：该物品类型无交互行为", "Player")

# ==============================================================================
# 物品使用系统
# ==============================================================================

# 使用当前装备的物品
# @description: 消耗品需要先拿到手上，右键才能使用
func use_equipped_item() -> void:
	if not current_equipped_item:
		Global.debug_print("没有装备任何物品，无法使用", "Player")
		return
	
	if current_equipped_item.物品类型 != Item.Kind.CONSUMABLE:
		Global.debug_print("当前装备的物品不是消耗品，无法使用", "Player")
		return
	
	if not current_equipped_item.消耗品效果:
		Global.debug_print("当前物品没有配置消耗品效果", "Player")
		return
	
	var item_index = inventory_node.equipped_id
	if item_index < 0:
		Global.debug_print("无法找到装备物品的索引", "Player")
		return
	
	play_item_use_animation(current_equipped_item, func():
		if not is_instance_valid(self) or not is_instance_valid(current_equipped_item):
			Global.debug_print("玩家或物品在动画播放期间失效", "Player")
			return
		
		if not current_equipped_item.消耗品效果:
			Global.debug_print("物品消耗品效果在动画播放期间失效", "Player")
			return
		
		current_equipped_item.消耗品效果.apply(self)
		
		var used_item = current_equipped_item
		inventory_node.use_item(item_index)
		Global.debug_print("消耗品使用完成: " + used_item.名称翻译键, "Player")
		unequip_item()
	)

# 攻击/使用装备物品
# @description: 使用当前装备的物品进行攻击或使用，支持武器类和工具类物品
func attack_with_equipped_item() -> void:
	# 防御性编程：多重安全检查
	if not is_instance_valid(self):
		push_error("攻击失败：玩家节点无效")
		return
	
	# 检查是否有装备的物品
	if not current_equipped_item:
		Global.debug_print("没有装备任何物品，无法使用", "Player")
		return
	
	# 检查物品实例是否有效
	if not is_instance_valid(current_equipped_item):
		push_error("攻击失败：装备物品无效")
		current_equipped_item = null
		return
	
	# 检查物品类型是否为武器或工具
	var is_weapon = current_equipped_item.物品类型 == Item.Kind.WEAPON
	var is_tool = current_equipped_item.物品类型 == Item.Kind.TOOL
	
	if not is_weapon and not is_tool:
		Global.debug_print("当前装备的物品不是武器或工具，无法使用", "Player")
		return
	
	# 武器类型检查：需要武器攻击效果
	if is_weapon:
		if not current_equipped_item.武器攻击效果:
			push_warning("当前武器没有配置攻击效果")
			return
		
		if not is_instance_valid(current_equipped_item.武器攻击效果):
			push_error("攻击失败：武器攻击效果资源无效")
			return
	
	# 工具类型：斧头等工具直接执行攻击逻辑（通过AxeDoorBreakEffect）
	var attack_effect = null
	if is_weapon:
		attack_effect = current_equipped_item.武器攻击效果
	elif is_tool:
		# 工具类物品如果有武器攻击效果，也使用它（斧头的破门效果）
		if current_equipped_item.get("武器攻击效果") and is_instance_valid(current_equipped_item.武器攻击效果):
			attack_effect = current_equipped_item.武器攻击效果
		else:
			Global.debug_print("工具类物品没有攻击效果配置", "Player")
			return
	
	# 检查是否正在攻击动画中（防止重复攻击）
	if ui_manager and hand_take and hand_take.has_method("is_animating"):
		if hand_take.is_animating():
			Global.debug_print("攻击失败：正在播放攻击动画", "Player")
			return
	
	var action_name = "攻击" if is_weapon else "使用"
	Global.debug_print("开始执行" + action_name + "，物品：" + current_equipped_item.名称翻译键, "Player")
	
	# 播放使用动画
	play_item_use_animation(current_equipped_item, func():
		# 动画完成后执行攻击效果（带错误处理）
		if not is_instance_valid(self) or not is_instance_valid(current_equipped_item):
			Global.debug_print("玩家或物品在动画播放期间失效", "Player")
			return
		
		if not is_instance_valid(attack_effect):
			Global.debug_print("攻击效果在动画播放期间失效", "Player")
			return
		
		var result = attack_effect.execute_attack(self, current_equipped_item)
		Global.debug_print(action_name + "效果执行结果：" + str(result), "Player")
	)

# 测试斧头攻击（调试方法）
# @description: 专门用于测试斧头攻击动画和效果
func test_axe_attack() -> void:
	Global.debug_print("=== 开始斧头攻击测试 ===", "Player")
	
	# 检查当前装备
	if not current_equipped_item:
		Global.debug_print("测试失败：没有装备物品", "Player")
		return
	
	Global.debug_print("当前装备：" + current_equipped_item.名称翻译键, "Player")
	Global.debug_print("物品类型：" + str(current_equipped_item.物品类型), "Player")
	Global.debug_print("是否是工具：" + str(current_equipped_item.物品类型 == Item.Kind.TOOL), "Player")
	Global.debug_print("是否有攻击效果：" + str(current_equipped_item.get("武器攻击效果") != null), "Player")
	Global.debug_print("是否有手持动画：" + str(current_equipped_item.get("手持动画") != null), "Player")
	
	if current_equipped_item.get("武器攻击效果"):
		Global.debug_print("攻击效果类型：" + current_equipped_item.武器攻击效果.get_class(), "Player")
	
	if current_equipped_item.get("手持动画"):
		Global.debug_print("手持动画类型：" + current_equipped_item.手持动画.get_class(), "Player")
	
	# 检查HandTake状态
	if hand_take:
		Global.debug_print("HandTake节点有效", "Player")
		if hand_take.has_method("is_animating"):
			Global.debug_print("是否正在动画：" + str(hand_take.is_animating()), "Player")
		if hand_take.has_method("can_play_animation"):
			Global.debug_print("是否可以播放动画：" + str(hand_take.can_play_animation()), "Player")
	else:
		Global.debug_print("HandTake节点无效", "Player")
	
	Global.debug_print("=== 执行使用 ===", "Player")
	attack_with_equipped_item()
	Global.debug_print("=== 测试完成 ===", "Player")

# 播放物品使用动画
# @param item: 要使用的物品
# @param on_complete: 动画完成后的回调函数
func play_item_use_animation(item: Item, on_complete: Callable = Callable()) -> void:
	# 防御性编程：参数检查
	if not is_instance_valid(item):
		push_error("play_item_use_animation: 物品参数无效")
		if on_complete:
			on_complete.call()
		return
	
	# 检查HandTake节点是否存在
	if not hand_take or not is_instance_valid(hand_take):
		push_warning("HandTake节点无效，无法播放动画")
		if on_complete:
			on_complete.call()
		return
	
	# 检查是否可以播放动画
	if ui_manager and hand_take and hand_take.has_method("can_play_animation"):
		if not hand_take.can_play_animation():
			print("无法播放物品使用动画：正在动画中或不可见")
			if on_complete:
				on_complete.call()
			return
	
	print("开始播放物品使用动画，物品：", item.名称翻译键)
	
	# 通过UI管理器播放动画
	if ui_manager:
		ui_manager.play_item_animation(on_complete)
	elif hand_take and hand_take.has_method("try_play_item_animation"):
		hand_take.try_play_item_animation(on_complete)
	else:
		print("警告: 无法播放动画")
		if on_complete:
			on_complete.call()

# ==============================================================================
# UI更新系统
# ==============================================================================

# 更新UI显示物品名称
# @param 物品名称: 要显示的物品名称
func 更新UI物品名称显示(物品名称: String) -> void:
	if ui_manager:
		ui_manager.update_item_name(物品名称)

# 更新UI显示状态文本
# @param 状态文本: 要显示的状态文本
func 更新UI状态文本显示(状态文本: String) -> void:
	if ui_manager:
		ui_manager.update_status_text(状态文本)

# 更新UI显示字幕文本
# @param 字幕文本: 要显示的字幕文本
func 更新UI字幕文本显示(字幕文本: String) -> void:
	if ui_manager:
		ui_manager.update_subtitle_text(字幕文本)

# 从背包获取物品状态信息并更新UI显示
func 更新物品状态显示() -> void:
	# 如果没有装备物品，清除状态文本
	if not current_equipped_item:
		清除UI状态文本()
		return
	
	# 获取背包系统
	var inv = get_node("inventory")
	if not inv:
		print("警告: 无法找到背包系统")
		清除UI状态文本()
		return
	
	# 查找当前装备的物品在背包中的状态信息
	for entry in inv.items:
		if entry and entry.has("item") and entry.item == current_equipped_item:
			# 获取物品状态
			var _item_state = entry.get("state")
			
			# 根据物品类型显示不同的状态信息
			if current_equipped_item.物品类型 == Item.Kind.CONSUMABLE:
				# 消耗品：显示剩余饮用次数
				if current_equipped_item.get("可饮用次数") != null:
					var 剩余次数 = current_equipped_item.可饮用次数
					var 最大次数 = current_equipped_item.最大饮用次数 if current_equipped_item.get("最大饮用次数") != null else current_equipped_item.可饮用次数
					# 显示格式：当前剩余次数-最大次数（如 3-3, 2-3, 1-3）
					显示UI剩余水量(剩余次数, 最大次数)
				else:
					清除UI状态文本()
			else:
				# 其他类型物品：显示物品类型
				var 类型文本 = ""
				match current_equipped_item.物品类型:
					Item.Kind.WEAPON:
						类型文本 = "武器"
					Item.Kind.KEY:
						类型文本 = "钥匙"
					Item.Kind.CONSUMABLE:
						类型文本 = "消耗品"
					Item.Kind.TOOL:
						类型文本 = "工具"
					Item.Kind.FLASHLIGHT:
						类型文本 = "手电筒"
					_:
						类型文本 = "道具"
				更新UI状态文本显示(类型文本)
			return
	
	# 如果没有找到物品，清除状态文本
	清除UI状态文本()

# 显示门状态文本
# @param 门名称: 门的名称
# @param 门状态: 门的状态（"已解锁"、"已上锁"等）
func 显示UI门状态(门名称: String, 门状态: String) -> void:
	if ui_manager:
		ui_manager.show_door_state(门名称, 门状态)

# 显示剩余水量
# @param 当前水量: 当前剩余水量
# @param 最大水量: 最大水量
func 显示UI剩余水量(当前水量: float, 最大水量: float) -> void:
	if ui_manager:
		ui_manager.show_water_remaining(当前水量, 最大水量)

# 清除状态文本
func 清除UI状态文本() -> void:
	if ui_manager:
		ui_manager.clear_status_text()

# 清除字幕文本
func 清除UI字幕文本() -> void:
	if ui_manager:
		ui_manager.clear_subtitle_text()

# ==============================================================================
# 物品丢弃系统
# ==============================================================================

# 丢弃当前装备的物品
# @description: 按G键丢弃当前装备的物品，在玩家前方生成掉落物
# @description: 如果前方有障碍物，则无法丢弃
func drop_equipped_item() -> void:
	# 步骤1: 检查是否有装备的物品
	# 如果没有装备物品，则无法执行丢弃操作
	if not current_equipped_item:
		Global.debug_print("没有装备任何物品，无法丢弃", "Player")
		return
	
	# 步骤2: 检查背包系统是否存在
	# 确保背包系统有效，否则无法移除物品
	if not inventory_node or not is_instance_valid(inventory_node):
		Global.debug_print("背包系统无效，无法丢弃物品", "Player")
		return
	
	# 步骤3: 使用玩家前方位置作为掉落位置
	# 获取摄像机前方方向
	var forward_dir = -camera.global_transform.basis.z.normalized()
	# 只保留水平方向
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()
	# 计算前方0.3米处的位置
	var drop_position = global_position + forward_dir * 0.3
	
	# 步骤4: 获取要丢弃的物品信息
	# 保存物品引用和索引，用于后续操作
	var item_to_drop = current_equipped_item
	var item_index = inventory_node.equipped_id
	
	Global.debug_print("准备丢弃物品: " + item_to_drop.名称翻译键, "Player")
	
	# 步骤5: 生成掉落物
	# 在计算好的位置创建可拾取的物品实例
	spawn_droppable_item(item_to_drop, drop_position)
	
	# 步骤6: 从背包中移除物品
	# 调用背包系统的移除方法，触发相应信号
	if item_index >= 0:
		inventory_node.remove_item(item_index)
	
	# 步骤7: 卸下当前装备
	# 清空手持物品显示，重置装备状态
	unequip_item()
	
	Global.debug_print("物品已丢弃: " + item_to_drop.名称翻译键, "Player")

# 获取物品掉落位置
# @return: 如果前方无障碍物返回掉落位置，否则返回Vector3.INF
# @description: 使用射线检测检查玩家前方是否有障碍物
func get_drop_position() -> Vector3:
	# 丢弃距离配置（玩家前方多远）
	# 距离过近可能导致物品与玩家重叠，过远可能导致物品在墙外
	var drop_distance = 0.5
	
	# 获取摄像机前方方向
	# 注意：Godot摄像机的basis.z向量默认指向后方，需要取反获取前方方向
	var forward_dir = -camera.global_transform.basis.z.normalized()
	
	# 计算目标位置（从玩家位置开始）
	# 使用玩家位置而不是摄像机位置，确保掉落物在地面高度
	var target_position = global_position + forward_dir * drop_distance
	
	# 使用射线检测检查前方是否有障碍物
	# PhysicsRayQueryParameters3D用于配置射线检测参数
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,  # 射线起点：玩家位置
		target_position,  # 射线终点：目标掉落位置
		1,  # 碰撞层：只检测建筑层（layer 1）
		[self]  # 排除列表：忽略玩家自身，防止检测到自己
	)
	
	# 执行射线检测
	var result = space_state.intersect_ray(query)
	
	# 判断检测结果
	# 如果射线检测到碰撞，说明前方有障碍物，无法放置物品
	if result:
		Global.debug_print("前方检测到障碍物，距离: " + str(result.position.distance_to(camera.global_position)), "Player")
		return Vector3.INF  # 返回特殊值表示位置无效
	
	# 可选扩展：检查目标位置是否在导航区域内
	# 如果需要确保掉落物在可走区域内，可以添加导航检测逻辑
	# var nav_region = get_tree().current_scene.find_child("NavigationRegion3D", true, false)
	# if nav_region:
	# 	var nav_map = nav_region.get_navigation_map()
	# 	var closest_point = NavigationServer3D.map_get_closest_point(nav_map, target_position)
	# 	if target_position.distance_to(closest_point) > 0.5:
	# 		return Vector3.INF
	
	# 返回有效的掉落位置
	return target_position

# 生成掉落物
# @param item: 要生成的物品资源
# @param drop_pos: 生成位置（世界坐标）
# @description: 在指定位置创建可拾取的物品实例，并配置其属性
func spawn_droppable_item(item: Item, drop_pos: Vector3) -> void:
	# 步骤1: 加载掉落物场景
	# DroppableItem.tscn是可拾取物品的场景模板
	var droppable_scene = load("res://scenes/items/DroppableItem.tscn")
	if not droppable_scene:
		Global.debug_print("无法加载掉落物场景", "Player")
		return
	
	# 步骤2: 实例化掉落物
	# 从场景模板创建实际的节点实例
	var droppable = droppable_scene.instantiate()
	if not droppable:
		Global.debug_print("无法实例化掉落物", "Player")
		return
	
	# 步骤3: 将掉落物添加到场景中
	# 重要：必须先添加到场景树，才能设置global_position等属性
	# 否则会报错 "is_inside_tree() is true"
	get_tree().current_scene.add_child(droppable)
	
	# 步骤4: 设置掉落物位置
	# 从玩家脚部位置开始，向上偏移固定高度
	# 只使用X和Z坐标，Y坐标从脚部开始加偏移
	droppable.global_position = Vector3(drop_pos.x, 1.5, drop_pos.z)
	
	# 步骤4.5: 给掉落物一个向前的推力
	# 获取摄像机前方方向
	var forward_dir = -camera.global_transform.basis.z.normalized()
	# 只保留水平方向
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()
	# 应用推力（力度更大，让物品滑得更远）
	if droppable.has_method("set_push_force"):
		droppable.set_push_force(forward_dir, 5.0)
	
	# 步骤5: 等待一帧确保节点完全添加到场景树
	# 这一步很重要，确保后续操作时节点已经完全初始化
	await get_tree().process_frame
	
	# 步骤6: 设置物品资源
	# 将物品数据传递给掉落物，使其知道要显示哪个物品
	if droppable.has_method("set"):
		droppable.set("物品资源", item)
		Global.debug_print("已设置物品资源: " + item.名称翻译键, "Player")
	
	# 步骤7: 手动加载物品模型
	# 调用掉落物的模型加载方法，确保3D模型正确显示
	# 由于节点可能在_ready()之后才设置物品资源，需要手动触发加载
	if droppable.has_method("_auto_load_model_from_item"):
		droppable._auto_load_model_from_item()
		Global.debug_print("已调用模型加载方法", "Player")
	
	# 步骤8: 检查模型节点状态
	# 调试信息：验证模型是否正确加载和显示
	if droppable.has_node("MeshInstance3D"):
		var mesh_node = droppable.get_node("MeshInstance3D")
		Global.debug_print("模型节点存在: " + str(mesh_node != null) + ", 可见: " + str(mesh_node.visible if mesh_node else false), "Player")
		if mesh_node and mesh_node.mesh:
			Global.debug_print("模型资源已加载: " + str(mesh_node.mesh.get_class()), "Player")
		else:
			Global.debug_print("警告: 模型节点存在但没有加载模型资源", "Player")
	else:
		Global.debug_print("警告: 未找到MeshInstance3D节点", "Player")
	
	# 步骤9: 延迟启用碰撞检测
	# 防止掉落物被立即拾取（玩家还在物品附近）
	# 先禁用Area3D的monitoring，0.5秒后再启用
	if droppable.has_node("Area3D"):
		var area = droppable.get_node("Area3D")
		if area:
			# 使用set_deferred延迟禁用，避免在当前帧修改
			area.set_deferred("monitoring", false)
			# 创建定时器，0.5秒后启用碰撞检测
			await get_tree().create_timer(0.5).timeout
			# 检查节点是否仍然有效（可能已被拾取）
			if is_instance_valid(area):
				area.monitoring = true
	
	Global.debug_print("已生成掉落物在位置: " + str(droppable.global_position), "Player")

# ==============================================================================
# 鼠标滚轮切换手持物系统
# ==============================================================================

# 鼠标滚轮切换手持物
# @param is_up: 是否为向上滚动（true=向上，false=向下）
# @description: 优先使用快捷栏切换，如果快捷栏有物品则按快捷栏顺序切换
func switch_equipped_item(is_up: bool) -> void:
	# 优先使用快捷栏切换
	if ui_manager:
		# 检查快捷栏是否有物品
		if inventory_node and inventory_node.items.size() > 0:
			ui_manager.switch_hotbar_item(is_up)
			print("使用快捷栏切换物品")
			return
	
	# 备用方案：使用原来的背包切换逻辑
	# 安全检查：确保背包系统存在
	if not inventory_node or not is_instance_valid(inventory_node):
		print("警告: 背包系统无效，无法切换手持物")
		return
	
	# 获取背包中的物品列表（每次切换都使用最新的背包顺序）
	var items = inventory_node.items
	if items.size() == 0:
		print("背包为空，无法切换手持物")
		return
	
	# 直接使用当前装备的物品索引，而不是通过名称查找
	var current_index = inventory_node.equipped_id
	
	# 计算下一个要装备的物品索引
	var next_index = 0
	if current_index >= 0 and current_index < items.size():
		# 根据滚动方向计算下一个索引
		if is_up:
			# 向上滚动：切换到前一个物品
			next_index = (current_index - 1 + items.size()) % items.size()
		else:
			# 向下滚动：切换到后一个物品
			next_index = (current_index + 1) % items.size()
	else:
		# 当前没有装备物品，从第一个开始
		next_index = 0
	
	# 获取下一个要装备的物品
	var next_item_entry = items[next_index]
	if not next_item_entry or not next_item_entry.has("item"):
		print("警告: 无法获取下一个物品")
		return
	
	var next_item = next_item_entry.item
	if not next_item:
		print("警告: 下一个物品无效")
		return
	
	# 装备新物品（使用统一的装备流程确保状态一致性）
	if hand_take and hand_take.has_method("show_item_mesh"):
		# 使用统一的装备流程，确保状态管理一致
		equip_item(next_item)
	else:
		# 备用方案：使用原来的equip_item流程
		equip_item(next_item)
	
	print("切换手持物: ", next_item.名称翻译键, " (索引: ", next_index, ")")

# 重置滚轮切换状态
# 在背包关闭时调用，确保滚轮切换使用最新的背包顺序
func _reset_wheel_switch_state() -> void:
	# 重置当前装备物品引用，强制下次切换时重新查找
	current_equipped_item = null
	print("重置滚轮切换状态，下次切换将使用最新背包顺序")

# 重置手持物动画状态
# 在背包关闭时调用，防止动画状态残留导致左键无法使用
func _reset_hand_take_animation_state() -> void:
	# 检查HandTake节点是否存在且有效
	if not hand_take or not is_instance_valid(hand_take):
		print("警告: HandTake节点无效，跳过动画状态重置")
		return
	
	# 强制取消当前正在播放的动画
	if hand_take.has_method("cancel_current_animation"):
		hand_take.cancel_current_animation()
		print("强制取消手持物动画")
	
	# 重置动画状态变量（如果存在）
	if hand_take.has_method("get_is_animating"):
		var was_animating = hand_take.get_is_animating()
		if was_animating:
			print("检测到残留动画状态，已强制重置")

# ==============================================================================
# 背包系统事件处理
# ==============================================================================

# 处理物品被移除的事件
func _on_inventory_item_removed(item_index: int, item: Item) -> void:
	print("[事件] 物品被移除: ", item.名称翻译键 if item else "未知物品", " (索引: ", item_index, ")")
	
	# 如果被移除的物品是当前装备的物品，需要卸下
	if current_equipped_item == item:
		print("[事件] 被移除的物品是当前装备的物品，执行卸下")
		unequip_item()
	
	# 通知手持物品系统更新显示
	_update_hand_take_display()

# 处理物品被使用的事件
func _on_inventory_item_used(item_index: int, item: Item) -> void:
	print("[事件] 物品被使用: ", item.名称翻译键 if item else "未知物品", " (索引: ", item_index, ")")
	
	# 物品使用后可能需要更新显示状态
	_update_hand_take_display()

# 处理装备状态改变的事件
func _on_inventory_equipment_changed(equipped_item: Item, equipped_index: int) -> void:
	print("[事件] 装备状态改变: ", equipped_item.名称翻译键 if equipped_item else "无装备", " (索引: ", equipped_index, ")")
	
	# 更新当前装备物品引用
	current_equipped_item = equipped_item
	
	# 通知手持物品系统更新显示
	_update_hand_take_display()

# 更新手持物品显示
func _update_hand_take_display() -> void:
	# 通过UI管理器更新显示
	if ui_manager:
		if current_equipped_item:
			print("[事件] 更新显示: 装备物品 ", current_equipped_item.名称翻译键)
			ui_manager.show_item_mesh(current_equipped_item)
		else:
			print("[事件] 更新显示: 无装备物品，清除显示")
			ui_manager.clear_item()
	elif hand_take and is_instance_valid(hand_take):
		# 备用方案：直接调用hand_take
		if current_equipped_item:
			print("[事件] 更新显示: 装备物品 ", current_equipped_item.名称翻译键)
			if hand_take.has_method("show_item_mesh"):
				hand_take.show_item_mesh(current_equipped_item)
			else:
				show_item_in_hand(current_equipped_item)
		else:
			print("[事件] 更新显示: 无装备物品，清除显示")
			if hand_take.has_method("clear_item"):
				hand_take.clear_item()
			else:
				hide_item_in_hand()

# ==============================================================================
# 门交互系统 - 事件驱动架构
# ==============================================================================

# 注册门到玩家附近的门列表
# @param door_node: 要注册的门节点
func register_door(door_node: Node) -> void:
	if not nearby_doors.has(door_node):
		nearby_doors.append(door_node)
		print("进入门的范围: ", door_node.name)

# 从玩家附近的门列表中注销门
# @param door_node: 要注销的门节点
func unregister_door(door_node: Node) -> void:
	if nearby_doors.has(door_node):
		nearby_doors.erase(door_node)
		print("离开门的范围: ", door_node.name)

# ==============================================================================
# 移动端输入系统
# ==============================================================================

# 设置移动端移动方向（来自虚拟摇杆）
# @param direction: 移动方向（2D向量，-1到1）
func set_mobile_move_direction(direction: Vector2) -> void:
	_mobile_input_vector = direction

# 设置移动端移动目标（来自点击地面）
# @param target_pos: 目标位置（3D世界坐标）
func set_mobile_move_target(target_pos: Vector3) -> void:
	_mobile_move_target = target_pos
	# 清除摇杆输入，避免冲突
	_mobile_input_vector = Vector2.ZERO

# ==============================================================================
# 手电筒系统
# ==============================================================================

# 切换手电筒开关
# @description: 按F键切换手电筒开关状态
func toggle_flashlight() -> void:
	# 检查当前装备的物品是否为手电筒
	if not current_equipped_item or current_equipped_item.物品类型 != Item.Kind.FLASHLIGHT:
		Global.debug_print("当前装备的不是手电筒，无法使用", "Player")
		return
	
	# 检查手电筒是否有电
	if current_equipped_item.当前电量 <= 0:
		Global.debug_print("手电筒没电了，无法开启", "Player")
		flashlight_on = false
		if flashlight_light:
			flashlight_light.visible = false
		return
	
	# 切换开关状态
	flashlight_on = not flashlight_on
	
	# 更新灯光状态
	if flashlight_light:
		flashlight_light.visible = flashlight_on
		if flashlight_on:
			apply_flashlight_settings()
	
	Global.debug_print("手电筒" + ("开启" if flashlight_on else "关闭"), "Player")

# 应用手电筒设置到灯光节点
# @description: 根据当前装备的手电筒属性设置灯光参数
func apply_flashlight_settings() -> void:
	if not flashlight_light or not current_equipped_item:
		return
	
	# 应用手电筒属性到灯光
	flashlight_light.light_energy = current_equipped_item.亮度
	flashlight_light.spot_range = current_equipped_item.范围
	flashlight_light.spot_angle = current_equipped_item.射程

# 处理手电筒电量消耗
# @param delta: 帧间隔时间（秒）
# @description: 每秒消耗手电筒电量，没电时自动关闭
func handle_flashlight(delta: float) -> void:
	# 如果手电筒未开启或没有装备手电筒，不处理
	if not flashlight_on or not current_equipped_item or current_equipped_item.物品类型 != Item.Kind.FLASHLIGHT:
		return
	
	# 累加电量消耗计时器
	flashlight_battery_timer += delta
	
	# 每秒消耗一次电量
	if flashlight_battery_timer >= 1.0:
		flashlight_battery_timer = 0.0
		
		# 消耗电量
		current_equipped_item.当前电量 -= current_equipped_item.电量消耗率
		
		# 检查是否没电
		if current_equipped_item.当前电量 <= 0:
			current_equipped_item.当前电量 = 0
			flashlight_on = false
			if flashlight_light:
				flashlight_light.visible = false
			Global.debug_print("手电筒电量耗尽，已自动关闭", "Player")
