extends CharacterBody3D

# 使用autoload的Global脚本，不需要手动获取单例


# ==============================================================================
# player.gd - 玩家控制脚本
# 扩展自CharacterBody3D类，负责管理玩家角色的移动、摄像机控制、动画、体力系统等
# 适用于初学者：理解玩家控制是游戏开发的核心部分，这个脚本展示了如何实现3D角色控制
# ==============================================================================

# 移动参数 #
# 初学者提示：这些常量定义了角色的基本移动属性，可以根据游戏设计调整
const SPEED: float = 5.0                # 基础行走速度
const RUN_SPEED: float = 10.0           # 奔跑速度（是行走速度的2倍）
const GRAVITY: float = -30.0            # 重力加速度（负值表示向下）
const JUMP_VELOCITY: float = 8          # 跳跃初速度（正值表示向上）

# 摄像机控制参数 #
# 初学者提示：使用@export关键字可以在Godot编辑器中直接调整这些值
@export var mouse_sensitivity: float = 0.1  # 鼠标灵敏度（可在编辑器调整）
@export var min_pitch: float = -90.0        # 最小俯仰角（防止摄像机翻转）
@export var max_pitch: float = 90.0         # 最大俯仰角（限制抬头角度）

# 动画参数 #
# 初学者提示：动画系统需要根据角色的移动状态切换不同的动画
@export var walk_threshold: float = 0.1  # 行走动画速度阈值（角色速度大于此值时播放行走动画）
@export var run_threshold: float = 7.0   # 奔跑动画速度阈值（角色速度大于此值时播放奔跑动画）

# 定义动画状态枚举，让代码更易读
enum AnimationState { 
	IDLE,   # 闲置状态
	WALK,   # 行走状态
	RUN,    # 奔跑状态
	JUMP,   # 跳跃状态
	FALL    # 下落状态
}  
var current_animation: int = AnimationState.IDLE     # 当前动画状态

# 体力系统参数 #
# 初学者提示：体力系统控制玩家的奔跑能力，增加游戏的策略性
@export var max_stamina: float = 100     # 最大体力值
var current_stamina: float = 1          # 当前体力值（初始化为1以便快速测试体力耗尽效果）
var stamina_regen_rate: float = 1.0 / 200.0  # 体力恢复速率（每秒恢复量）
var stamina_drain_rate: float = 1.0 / 8.0   # 体力消耗速率（每秒消耗量）
var can_sprint: bool = true                # 是否允许奔跑（用于控制恢复逻辑）

# 节点引用 #
# 初学者提示：使用@onready关键字确保节点在访问前已经准备好了
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"  # 动画播放器引用
@onready var camera: Camera3D = $Skeleton3D/BoneAttachment3D/Camera3D  # 摄像机节点引用
@onready var stamina_ui: Control =$Skeleton3D/BoneAttachment3D/Camera3D/Control   # 体力条UI引用
@onready var inventory_node: Node = $inventory  # 背包组件引用

# 内部状态 #
# 初学者提示：这些变量跟踪角色和摄像机的当前状态
var pitch: float = 0.0   # 摄像机俯仰角（X轴旋转）
var yaw: float = 0.0     # 角色偏航角（Y轴旋转）
var is_jumping: bool = false  # 跳跃状态标志

# --------------------  新增变量  --------------------
# 初学者提示：布娃娃系统让角色在特殊情况下（如体力耗尽）变得软绵绵
@onready var ragdoll_cam: Camera3D = $RagdollCamera  # 布娃娃模式下使用的摄像机
@onready var simulator: PhysicalBoneSimulator3D = $Skeleton3D/PhysicalBoneSimulator3D  # 骨骼物理模拟器
var ragdolling: bool = false          # 是否正在布娃娃状态
var ragdoll_timer: SceneTreeTimer     # 用来计时恢复时间
# --------------------  体力归零触发布娃娃  --------------------



func _ready():
	# 初始化鼠标模式
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# 设置全局玩家引用
	Global.player = self
	
	# 初始化摄像机朝向
	camera.rotation_degrees = Vector3(0.0, 0.0, 0.0)

	# 播放初始闲置动画
	animation_player.play("Main/Idle")
	
	# 初始化体力值并更新UI
	current_stamina = max_stamina
	stamina_ui.update_stamina(current_stamina, max_stamina)

# 恢复玩家体力的方法
# 参数：percent - 要恢复的体力百分比（0-100）
# 初学者提示：这个方法被消耗品效果调用，用于恢复玩家体力
func restore_stamina_percent(percent: float):
	# 计算恢复量，使用clamp确保百分比在0-100之间
	var recovery_amount = max_stamina * (clamp(percent, 0.0, 100.0) / 100.0)
	
	# 更新体力值，确保不超过最大值
	# 使用min函数确保体力不会超过最大值
	current_stamina = min(current_stamina + recovery_amount, max_stamina)
	
	# 安全地更新UI，先检查stamina_ui是否存在且有update_stamina方法
	if stamina_ui and stamina_ui.has_method("update_stamina"):
		stamina_ui.update_stamina(current_stamina, max_stamina)
	
func _unhandled_input(event):
	# ESC键切换鼠标捕获模式
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
		# 如果背包打开，关闭背包
		toggle_inventory(false)
	
	# openbag键打开/关闭背包
	if Input.is_action_just_pressed("openbag"):
		toggle_inventory()
	
	# 处理鼠标移动
	if event is InputEventMouseMotion:
		# 应用鼠标灵敏度
		var delta = event.relative * mouse_sensitivity
		yaw -= delta.x   # 水平旋转（左右移动鼠标）
		pitch -= delta.y # 垂直旋转（上下移动鼠标，调整为正常视角）
		
		# 限制俯仰角度
		pitch = clamp(pitch, min_pitch, max_pitch)

func _physics_process(delta: float) -> void:
	#region 重力系统
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	#endregion

	#region 跳跃处理
	if Input.is_action_just_pressed("ui_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		is_jumping = true
	#endregion

	#region 移动处理
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	#var current_speed = RUN_SPEED if Input.is_action_pressed("ui_run") else SPEED
	
	# 根据体力状态决定是否允许奔跑
	var want_to_sprint = Input.is_action_pressed("ui_run") and can_sprint
	var current_speed = SPEED  # 默认行走速度
	
	if want_to_sprint and velocity.length() > walk_threshold:
		current_speed = RUN_SPEED
	
	# 基于摄像机方向计算移动向量
	var direction = (-camera.global_transform.basis.z * input_dir.y + 
					 camera.global_transform.basis.x * input_dir.x).normalized()
	
	# 应用水平速度
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# 平滑停止
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	#endregion

	# 执行物理移动
	move_and_slide()

	#region 更新旋转
	# 角色水平旋转（保持与摄像机偏航同步）
	rotation_degrees.y = yaw
	# 摄像机俯仰旋转（保持相对角色角度）
	camera.rotation_degrees.x = pitch
	# 注意：摄像机保持180度反转，因为角色和摄像机放反了，这是正常的设计
	camera.rotation_degrees.y = -180.0
	#endregion

	# 更新动画状态
	update_animation()
	
	# 更新体力系统
	handle_stamina(delta)
	
# 体力系统核心逻辑
# 参数：delta - 帧间隔时间（秒）
# 初学者提示：体力系统根据玩家的动作动态调整体力值
func handle_stamina(delta: float):
	# 判断当前是否处于有效奔跑状态
	# 玩家必须按下奔跑键、能够奔跑、并且正在移动
	var is_sprinting = Input.is_action_pressed("ui_run") && can_sprint && velocity.length() > walk_threshold
	
	if is_sprinting:
		
		# 消耗体力（每秒消耗 stamina_drain_rate%）
		current_stamina = clamp(current_stamina - (delta * stamina_drain_rate * 100), 0, max_stamina)
		
		# 当体力耗尽时禁止奔跑
		if current_stamina <= 0 and not ragdolling:
			start_ragdoll_sequence()      # <—— 新增
		
	else:
		# 恢复体力（每秒恢复 stamina_regen_rate%）
		current_stamina = clamp(current_stamina + (delta * stamina_regen_rate * 100), 0, max_stamina)
		
		
		
	
	# 更新UI显示
	stamina_ui.update_stamina(current_stamina, max_stamina)
	

func update_animation():
	var speed = velocity.length()
	var is_moving = speed > walk_threshold
	
	# 状态判断逻辑
	if is_jumping:
		set_animation(AnimationState.JUMP)
	elif not is_on_floor():
		set_animation(AnimationState.FALL)
	elif is_moving:
		set_animation(AnimationState.RUN if speed > run_threshold else AnimationState.WALK)
	else:
		set_animation(AnimationState.IDLE)

func set_animation(state: AnimationState):
	if current_animation == state: return
	
	current_animation = state
	match state:
		AnimationState.IDLE: animation_player.play("Main/Idle")
		AnimationState.WALK: animation_player.play("Main/Walk")
		AnimationState.RUN:  animation_player.play("Main/Run")
		AnimationState.JUMP: animation_player.play("Main/Jump")
		AnimationState.FALL: animation_player.play("Main/Fall")

func _on_animation_finished(anim_name: String):
	if anim_name == "Main/Jump":
		is_jumping = false

# --------------------  布娃娃序列总控  --------------------
# 初学者提示：布娃娃系统是一种物理模拟，让角色在特殊情况下（如体力耗尽）变得软绵绵
func start_ragdoll_sequence() -> void:
	# 设置布娃娃状态标志
	ragdolling = true
	
	# 1. 立即瘫软 - 激活骨骼物理模拟
	$Skeleton3D/PhysicalBoneSimulator3D.active = true
	simulator.physical_bones_start_simulation()  # 开始物理模拟

	# 2. 关闭角色输入、动画
	set_physics_process(false)  # 禁用物理处理，停止移动逻辑
	animation_player.stop()     # 停止当前动画
	
	# 3. 切相机 - 切换到布娃娃专用摄像机
	camera.current = false      # 禁用主摄像机
	ragdoll_cam.current = true # 启用布娃娃摄像机
	
	# 4. 开始计时器，一段时间后自动恢复
	ragdoll_timer = get_tree().create_timer(2.0)  # 创建2秒的计时器
	ragdoll_timer.timeout.connect(end_ragdoll_sequence)  # 连接计时器结束信号

# 结束布娃娃状态，恢复正常角色控制
# 初学者提示：这个方法负责平滑地从布娃娃状态过渡回正常状态
func end_ragdoll_sequence() -> void:
	# 重置相机位置 - 确保相机位置合适
	reset_ragdoll_camera()
	
	# 等待一段时间让相机平稳过渡
	# 使用await关键字等待计时器完成，这是GDScript的协程功能
	await get_tree().create_timer(0.5).timeout
	
	# 停止物理模拟并禁用布娃娃系统
	simulator.physical_bones_stop_simulation()  # 停止骨骼物理模拟
	$Skeleton3D/PhysicalBoneSimulator3D.active = false  # 禁用物理模拟器
	
	# 切回主相机
	ragdoll_cam.current = false
	camera.current = true
	
	# 等待一会儿让角色姿态稳定
	await get_tree().create_timer(0.5).timeout
	
	# 恢复控制
	set_physics_process(true)
	animation_player.play("Main/Idle")
	
	# 重置状态
	ragdolling = false
	can_sprint = false
	
	# 设置一个延迟恢复奔跑能力的计时器
	var regen_timer = get_tree().create_timer(3.0)
	regen_timer.timeout.connect(func():
		can_sprint = true
		print("奔跑能力已恢复")
	)

# --------------------  摆正第三人称相机（可选）  --------------------
# 初学者提示：这个方法确保在布娃娃模式下，相机会以合适的角度观察角色
func reset_ragdoll_camera() -> void:
	# 1. 确定相机的观察点（注视目标）
	# 这里选择角色的脊柱位置作为目标点，大约是胸口位置
	var center: Vector3 = $"Skeleton3D/PhysicalBoneSimulator3D/Physical Bone mixamorig_Spine".global_position

	# 2. 设置相机位置 - 将相机放在角色附近的合适位置
	# 这里使用了相对位置偏移，让相机在角色的右前方稍高位置
	ragdoll_cam.global_position = center + Vector3(0.3, 0.5, 0.3)

	# 3. 设置相机朝向
	# look_at方法让相机朝向指定点，Vector3.UP确保相机的顶部朝向世界上方
	ragdoll_cam.look_at(center, Vector3.UP)

# --------------------  恢复站立  --------------------
# 初学者提示：这个方法提供了一种立即从布娃娃状态恢复的方式
func recover_from_ragdoll() -> void:
	# 禁用布娃娃系统
	$Skeleton3D/PhysicalBoneSimulator3D.active = false
	simulator.physical_bones_stop_simulation()
	
	# 把角色本体移到骨骼的位置，防止瞬移
	global_position = $Skeleton3D.global_position
	# 还原相机
	ragdoll_cam.current = false
	camera.current = true
	# 还原控制
	set_physics_process(true)
	ragdolling = false
	# 给一点体力避免立刻又归零
	current_stamina = max_stamina * 0.1
	can_sprint = true
	set_animation(AnimationState.IDLE)

# --------------------  背包控制  --------------------
# 初学者提示：背包系统让玩家可以查看和使用收集到的物品
var inventory_gui: Node = null      # 背包界面引用
var is_inventory_open: bool = false # 背包是否打开的标志

# 切换背包的显示状态
# 参数：force_state - 强制设置的状态，null表示切换当前状态
func toggle_inventory(force_state = null):
	# 尝试通过相对路径查找背包界面
	inventory_gui = $"../../InventoryGUI3D"
	
	# 如果相对路径没找到，尝试从根节点查找
	if inventory_gui == null:
		inventory_gui = get_tree().root.get_node_or_null("InventoryGUI3D")
		
	# 如果找到了背包界面，设置它的inventory引用
	if inventory_gui != null and inventory_node != null and inventory_gui.has_method("set_inventory"):
		inventory_gui.set_inventory(inventory_node)
		
	if inventory_gui == null:
		print("警告: 未找到背包界面节点，请确保InventoryGUI3D场景已添加到主场景中")
		return
	
	# 确定目标状态
	var target_state = not is_inventory_open if force_state == null else force_state
	
	if target_state == is_inventory_open:
		return
	
	is_inventory_open = target_state
	inventory_gui.visible = target_state
	
	# 当打开背包时，刷新内容显示
	if target_state and inventory_gui.has_method("refresh"):
		inventory_gui.refresh()
	
	# 更新鼠标模式
	if target_state:
		# 打开背包时，显示鼠标
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# 暂停游戏或减少移动灵敏度
		# 这里可以根据需要调整，比如降低移动速度或暂停某些游戏逻辑
	else:
		# 关闭背包时，捕获鼠标
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	# 刷新背包内容
	if target_state and inventory_gui is Control and inventory_gui.has_method("refresh"):
		inventory_gui.refresh()
