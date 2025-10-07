extends CharacterBody3D


### 移动参数 ###
const SPEED: float = 5.0                # 基础行走速度
const RUN_SPEED: float = 10.0           # 奔跑速度
const GRAVITY: float = -30.0            # 重力加速度（调整为适合你的场景）
const JUMP_VELOCITY: float = 8          # 跳跃初速度

### 摄像机控制参数 ###
@export var mouse_sensitivity: float = 0.1  # 鼠标灵敏度（可在编辑器调整）
@export var min_pitch: float = -90.0        # 最小俯仰角（防止摄像机翻转）
@export var max_pitch: float = 90.0         # 最大俯仰角

### 动画参数 ###
@export var walk_threshold: float = 0.1  # 行走动画速度阈值
@export var run_threshold: float = 7.0   # 奔跑动画速度阈值
enum AnimationState { IDLE, WALK, RUN, JUMP, FALL }  # 动画状态枚举
var current_animation: int = AnimationState.IDLE     # 当前动画状态

### 体力系统参数 ###
@export var max_stamina: float = 100     # 最大体力值
var current_stamina: float = 1         # 当前体力值
var stamina_regen_rate: float = 1.0 / 200.0  # 体力恢复速率（每秒恢复量）
var stamina_drain_rate: float = 1.0 / 8.0  # 体力消耗速率（每秒消耗量）
var can_sprint: bool = true                # 是否允许奔跑

### 节点引用 ###
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"  # 动画播放器
@onready var camera: Camera3D = $Skeleton3D/BoneAttachment3D/Camera3D  # 摄像机节点
@onready var stamina_ui: Control =$Skeleton3D/BoneAttachment3D/Camera3D/Control   # 体力条UI
@onready var inventory_node: Node = $inventory  # 背包组件

### 内部状态 ###
var pitch: float = 0.0   # 摄像机俯仰角（X轴旋转）
var yaw: float = 0.0     # 角色偏航角（Y轴旋转）
var is_jumping: bool = false  # 跳跃状态标志

# --------------------  新增变量  --------------------
@onready var ragdoll_cam: Camera3D = $RagdollCamera
@onready var simulator: PhysicalBoneSimulator3D = $Skeleton3D/PhysicalBoneSimulator3D
var ragdolling: bool = false          # 是否正在布娃娃状态
var ragdoll_timer: SceneTreeTimer     # 用来计时恢复
# --------------------  体力归零触发布娃娃  --------------------



func _ready():
	# 初始化鼠标模式
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 初始化摄像机朝向
	# 注意：这里摄像机旋转180度是因为角色和摄像机放反了，这是正常的设计
	camera.rotation_degrees = Vector3(0.0, -180.0, 0.0)

	# 播放初始闲置动画
	animation_player.play("Main/Idle")
	
	# 初始化体力值并更新UI
	current_stamina = max_stamina
	stamina_ui.update_stamina(current_stamina, max_stamina)

# 恢复玩家体力的方法
# 参数：percent - 要恢复的体力百分比（0-100）
func restore_stamina_percent(percent: float):
	# 计算恢复量
	var recovery_amount = max_stamina * (clamp(percent, 0.0, 100.0) / 100.0)
	# 更新体力值，确保不超过最大值
	current_stamina = min(current_stamina + recovery_amount, max_stamina)
	# 更新UI
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
func handle_stamina(delta: float):
	# 判断当前是否处于有效奔跑状态
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
func start_ragdoll_sequence() -> void:
	ragdolling = true
	
	# 1. 立即瘫软
	$Skeleton3D/PhysicalBoneSimulator3D.active = true
	simulator.physical_bones_start_simulation()

	# 2. 关闭角色输入、动画
	set_physics_process(false)        # 不让移动逻辑再跑
	animation_player.stop()
	
	# 3. 切相机
	camera.current = false
	ragdoll_cam.current = true
	
	# 4. 开始计时器，一段时间后恢复
	ragdoll_timer = get_tree().create_timer(2.0)
	ragdoll_timer.timeout.connect(end_ragdoll_sequence)

func end_ragdoll_sequence() -> void:
	# 重置相机位置
	reset_ragdoll_camera()
	
	# 等待一段时间让相机平稳过渡
	await get_tree().create_timer(0.5).timeout
	
	# 停止物理模拟并禁用布娃娃系统
	simulator.physical_bones_stop_simulation()
	$Skeleton3D/PhysicalBoneSimulator3D.active = false
	
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
func reset_ragdoll_camera() -> void:
	# 1. 先确定“看哪里”——这里选角色脚底再往上 1.8 m，相当于胸口/锁骨高度
	#    如果你想看头，就把 1.8 改成 1.9~2.0；想看腰，就 1.0~1.2
	var center: Vector3 = $"Skeleton3D/PhysicalBoneSimulator3D/Physical Bone mixamorig_Spine".global_position


	# 2. 再把相机摆到“斜上方 45°”的一个点，这里是：
	#    → 角色右前方 2 m（X 轴 +2）
	#    → 再抬高 1.5 m（Y 轴 +1.5）
	#    → 同时往后 2 m（Z 轴 +2，世界坐标系下）
	#    你可以把这三个数字当成“半径/高度/前后”旋钮，随意放大缩小
	ragdoll_cam.global_position = center + Vector3(0.3,0.5, 0.3)

	# 3. 让相机永远盯着 center（胸口），UP 向量保持世界“头顶”方向
	#    如果你想让相机带点俯仰角，可以在这里再手动加：
	#    ragdoll_cam.rotate_x(deg_to_rad(10))   // 再往下压 10°
	ragdoll_cam.look_at(center,Vector3.UP )

# --------------------  恢复站立  --------------------
func recover_from_ragdoll() -> void:
	$Skeleton3D/PhysicalBoneSimulator3D.active = false
	simulator.physical_bones_stop_simulation()
	# 把角色本体移到 Skeleton 的 hips 位置，防止瞬移
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
var inventory_gui: Node = null
var is_inventory_open: bool = false

func toggle_inventory(force_state = null):
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
