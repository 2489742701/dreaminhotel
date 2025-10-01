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
@export var max_stamina: float = 100.0     # 最大体力值
var current_stamina: float = 100.0         # 当前体力值
var stamina_regen_rate: float = 1.0 / 200.0  # 体力恢复速率（每秒恢复量）
var stamina_drain_rate: float = 1.0 / 8.0  # 体力消耗速率（每秒消耗量）
var can_sprint: bool = true                # 是否允许奔跑

### 节点引用 ###
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"  # 动画播放器
@onready var camera: Camera3D = $Skeleton3D/BoneAttachment3D/Camera3D  # 摄像机节点
@onready var stamina_ui: Control =$Skeleton3D/BoneAttachment3D/Camera3D/Control   # 体力条UI

### 内部状态 ###
var pitch: float = 0.0   # 摄像机俯仰角（X轴旋转）
var yaw: float = 0.0     # 角色偏航角（Y轴旋转）
var is_jumping: bool = false  # 跳跃状态标志

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
	
func _unhandled_input(event):
	# ESC键切换鼠标捕获模式
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
	
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
		if current_stamina <= 0:
			can_sprint = false
	else:
		# 恢复体力（每秒恢复 stamina_regen_rate%）
		current_stamina = clamp(current_stamina + (delta * stamina_regen_rate * 100), 0, max_stamina)
		
		# 体力完全恢复后重新允许奔跑
		if current_stamina >= max_stamina:
			can_sprint = true
	
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
