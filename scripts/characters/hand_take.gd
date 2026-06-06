# ==============================================================================
# hand_take.gd
# HandTake节点控制器（模块化动画版）
# 功能：管理玩家手中物品的Mesh显示，支持实时切换不同物品的Mesh
# 优化：与玩家装备系统集成，自动响应装备/卸下物品事件
# 重构：使用模块化动画资源系统，将动画逻辑与显示逻辑分离
# 继承：MeshInstance3D - Godot的3D网格实例节点
# ==============================================================================

extends MeshInstance3D

# ==============================================================================
# 公开属性
# ==============================================================================

# 调试模式开关
@export var debug_mode: bool = false

# 调试定位Mesh
@export var debug_mesh: Mesh = null

# 手持物品的等比缩放比例
@export_range(0.01, 10.0, 0.01) var hand_item_scale: float = 1.0

# ==============================================================================
# 内部状态
# ==============================================================================

var player_node: Node = null
var owner_player: Node = null
var is_animating: bool = false
var last_item_name: String = ""
var current_tween: Tween = null
var _current_anim_resource: Resource = null

# 记录初始状态，用于复位
var default_pos: Vector3
var default_rot: Vector3
var default_scale: Vector3

# 设置拥有者玩家
# @param player: 玩家节点
func set_owner_player(player: Node) -> void:
	owner_player = player

# 获取拥有者玩家
# @return: 玩家节点
func get_owner_player() -> Node:
	return owner_player

# 动画取消方法
func cancel_current_animation() -> void:
	if is_animating:
		print("[动画] 取消当前动画")
		if current_tween:
			current_tween.kill()
		
		# 调用动画资源的取消方法（如果存在）
	if _current_anim_resource and _current_anim_resource.has_method("cancel"):
		_current_anim_resource.cancel(self)
	
	_reset_visuals()
	is_animating = false
	_current_anim_resource = null
	last_item_name = ""

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	find_player_node()
	
	# 记录初始 Transform
	default_pos = position
	default_rot = rotation_degrees
	default_scale = scale
	
	print("HandTake 初始位置记录: ", default_pos) # <--- 加上这一行看看
	
	if debug_mode and debug_mesh:
		show_debug_mesh()
	else:
		_reset_visuals()

func _physics_process(_delta: float) -> void:
	# 移除持续检查，改为事件驱动
	# update_display_based_on_equipment()
	pass

# ==============================================================================
# 核心逻辑：动画播放
# ==============================================================================

# 尝试播放当前装备物品的动画
# 这个函数供外部调用（例如 player.gd 在点击鼠标时调用）
# @param on_complete: 动画完成后的回调函数（可选）
func try_play_item_animation(on_complete: Callable = Callable()) -> void:
	if is_animating:
		print("动画正在播放中，取消当前动画并重新开始")
		cancel_current_animation()
		# 短暂延迟后重新开始，确保状态重置完成
		var tween = create_tween()
		tween.tween_interval(0.05)
		tween.tween_callback(func():
			try_play_item_animation(on_complete)
		)
		return
	
	# 1. 获取当前物品
	var item = _get_current_item()
	if not item: 
		if on_complete:
			on_complete.call()
		return
	
	# 2. 获取物品上的动画资源
	var anim_res = null
	if "手持动画" in item:
		anim_res = item.手持动画
	
	if not anim_res:
		print("该物品没有配置 '手持动画' 资源")
		if on_complete:
			on_complete.call()
		return
	
	# 3. 播放动画资源
	_play_anim_resource(anim_res, on_complete)

# 执行具体的动画资源
# @param anim_res: 动画资源
# @param on_complete: 动画完成后的回调函数（可选）
func _play_anim_resource(anim_res: Resource, on_complete: Callable = Callable()):
	# 防御性编程：参数检查
	if not is_instance_valid(anim_res):
		push_error("_play_anim_resource: 动画资源无效")
		if on_complete:
			on_complete.call()
		return
	
	if not anim_res.has_method("apply"):
		push_error("动画资源无效：缺少apply方法")
		if on_complete:
			on_complete.call()
		return

	is_animating = true
	_current_anim_resource = anim_res
	print("开始播放物品动画，资源类型：", anim_res.get_class())
	
	var tween = create_tween()
	if not tween:
		push_error("创建Tween失败")
		is_animating = false
		_current_anim_resource = null
		if on_complete:
			on_complete.call()
		return
	
	tween.set_parallel(false) # 默认串行，与原逻辑一致
	
	# 设置Tween完成回调，确保动画状态正确重置
	tween.tween_callback(func():
		is_animating = false
		_current_anim_resource = null
		# 强制复位，消除累积误差（双重保险）
		position = default_pos
		rotation_degrees = default_rot
		scale = default_scale # 别忘了重置缩放！
		# 【关键修复】确保它是可见的！
		visible = true
		print("物品动画播放完成，已复位")
	)
	
	# 调用资源的 apply 方法，把 target(self) 和 tween 传进去
	if anim_res != null and anim_res.has_method("apply"):
		anim_res.apply(self, tween, on_complete)
	else:
		push_error("动画资源apply方法执行失败")
		is_animating = false
		_current_anim_resource = null
		if on_complete:
			on_complete.call()

# ==============================================================================
# 显示逻辑（保持原有的切换动画逻辑）
# ==============================================================================

func show_item_mesh(item: Object) -> void:
	# 安全检查
	if not item:
		print("[EVENT] 显示物品: 物品为空，清除显示")
		clear_item()
		return
	
	var model = item.get("模型") if item.get("模型") else (item.get_model() if item.has_method("get_model") else null)
	if not model:
		print("[EVENT] 显示物品: 物品没有模型，清除显示")
		clear_item()
		return

	var item_name = item.get("名称翻译键") if item.get("名称翻译键") else "未命名"
	
	# 防止重复显示同一物品
	if is_animating and last_item_name == item_name:
		print("[EVENT] 正在显示同一物品，跳过重复显示: ", item_name)
		return
	
	print("[EVENT] 显示物品: ", item_name)
	
	# 如果当前有物品显示，先播放放下动画
	if mesh != null and mesh != model:
		print("[EVENT] 当前有物品，先播放放下动画")
		# 如果正在动画中，直接取消当前动画开始新动画
		if is_animating:
			print("[EVENT] 正在动画中，取消当前动画直接拿起新物品")
			cancel_current_animation()
			play_pick_up_animation(model, item_name)
		else:
			# 播放放下动画，完成后播放拿起动画
			play_put_down_animation()
			# 使用动画完成回调来播放拿起动画
			var wait_tween = create_tween()
			wait_tween.tween_interval(0.15) # 等待放下动画完成
			wait_tween.tween_callback(func():
				play_pick_up_animation(model, item_name)
			)
	else:
		# 没有当前物品或物品相同，直接播放拿起动画
		print("[EVENT] 没有当前物品或物品相同，直接播放拿起动画")
		play_pick_up_animation(model, item_name)
	
	last_item_name = item_name

# 放下动画：将当前物品放下
func play_put_down_animation() -> void:
	if is_animating: 
		print("[动画] 正在动画中，跳过放下动画")
		return
	is_animating = true
	
	print("[动画] 开始播放放下动画")
	
	current_tween = create_tween()
	current_tween.set_parallel(false)
	
	# 1. 缩小 + 下落（更快）
	current_tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.1)
	current_tween.parallel().tween_property(self, "position:y", default_pos.y - 0.3, 0.1)
	
	# 2. 完成放下
	current_tween.tween_callback(func():
		mesh = null
		position = default_pos
		scale = Vector3.ONE * hand_item_scale
		is_animating = false
		current_tween = null
		last_item_name = "" # 清除最后显示的物品名称
		print("[动画] 放下动画完成")
	)

# 拿起动画：拿起新物品
func play_pick_up_animation(new_mesh: Mesh, item_name: String) -> void:
	# 防止重复播放同一物品的动画
	if is_animating and last_item_name == item_name:
		print("[动画] 正在播放同一物品的动画，跳过重复: ", item_name)
		return
	
	# 如果正在动画中，直接取消当前动画并开始新的拿起动画
	if is_animating:
		print("[动画] 正在动画中，取消当前动画并开始拿起新物品: ", item_name)
		cancel_current_animation()
	
	is_animating = true
	last_item_name = item_name
	
	print("[动画] 开始播放拿起动画: ", item_name)
	
	# 先设置新模型（但不可见）
	mesh = new_mesh
	scale = Vector3.ONE * hand_item_scale
	position = default_pos
	visible = false
	
	current_tween = create_tween()
	current_tween.set_parallel(false)
	
	# 1. 从下方开始（不可见位置）
	position.y = default_pos.y - 0.3
	scale = Vector3(0.1, 0.1, 0.1)
	visible = true
	
	# 2. 上升 + 放大（更快）
	current_tween.tween_property(self, "position:y", default_pos.y, 0.15)
	current_tween.parallel().tween_property(self, "scale", Vector3.ONE * hand_item_scale, 0.15)
	
	current_tween.tween_callback(func():
		is_animating = false
		current_tween = null
		print("[动画] 拿起动画完成: ", item_name)
	)

# ==============================================================================
# 辅助函数
# ==============================================================================

func _get_current_item() -> Object:
	# 优先使用owner_player，如果没有则使用player_node（向后兼容）
	var target_player = owner_player if owner_player else player_node
	if target_player and target_player.has_method("get_equipped_item"):
		var item = target_player.get_equipped_item()
		print("[DEBUG] _get_current_item - 玩家节点: ", target_player != null, ", 方法存在: ", target_player.has_method("get_equipped_item"), ", 物品: ", item != null)
		if item:
			print("[DEBUG] 物品名称: ", item.名称翻译键 if "名称翻译键" in item else "未知")
		return item
	print("[DEBUG] _get_current_item - 玩家节点无效或没有get_equipped_item方法")
	return null

func _set_mesh_visuals(new_mesh: Mesh):
	mesh = new_mesh
	visible = true
	scale = Vector3.ONE * hand_item_scale
	# 确保动画状态正确重置
	is_animating = false
	print("[DEBUG] _set_mesh_visuals - 设置Mesh: ", new_mesh != null, ", 可见: ", visible, ", 时间: ", Time.get_ticks_msec())

func clear_item() -> void:
	print("[EVENT] 清除物品显示")
	
	# 如果有当前显示的物品，播放放下动画
	if mesh != null:
		# 如果正在动画中，直接重置状态
		if is_animating:
			print("[EVENT] 正在动画中，直接重置状态")
			cancel_current_animation()
		else:
			play_put_down_animation()
	else:
		# 如果没有物品，直接重置
		_reset_visuals()

func _reset_visuals():
	print("[DEBUG] _reset_visuals - 重置前: 可见: ", visible, ", Mesh: ", mesh != null, ", 时间: ", Time.get_ticks_msec())
	
	# 【关键修复】重置所有表面覆盖材质
	if mesh != null:
		var surface_count = mesh.get_surface_count()
		for i in range(surface_count):
			set_surface_override_material(i, null)
		print("[DEBUG] 已重置 ", surface_count, " 个表面覆盖材质")
	
	mesh = null
	# 不要自动隐藏，让事件驱动决定可见性
	# visible = false
	print("[DEBUG] _reset_visuals - 重置后: 可见: ", visible, ", Mesh: ", mesh != null, ", 时间: ", Time.get_ticks_msec())

# 清除动画：物品消失时的动画效果（已弃用，使用放下动画替代）
# func play_clear_animation() -> void:
# 	if is_animating: 
# 		print("[动画] 正在动画中，跳过清除动画")
# 		return
# 	is_animating = true
# 	
# 	print("[动画] 开始播放清除动画")
# 	
# 	var tween = create_tween()
# 	tween.set_parallel(false)
# 	
# 	# 1. 缩小 + 下落
# 	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.2)
# 	tween.parallel().tween_property(self, "position:y", default_pos.y - 0.3, 0.2)
# 	
# 	# 2. 清除模型并重置
# 	tween.tween_callback(func():
# 		mesh = null
# 		position = default_pos
# 		scale = Vector3.ONE * hand_item_scale
# 		print("[动画] 清除模型完成")
# 	)
# 	
# 	# 3. 完成动画
# 	tween.tween_callback(func():
# 		is_animating = false
# 		print("[动画] 清除动画完成")
# 	)

func find_player_node() -> void:
	print("[DEBUG] find_player_node - 开始查找玩家节点")
	
	# 主要方法：直接使用Global.player（推荐方式）
	if Global and is_instance_valid(Global.player):
		player_node = Global.player
		print("[DEBUG] 通过Global.player找到玩家节点")
		return
	
	# 备用方法：通过player组查找
	var found_player = get_tree().get_first_node_in_group("player")
	if found_player and is_instance_valid(found_player):
		player_node = found_player
		print("[DEBUG] 通过player组找到玩家节点")
		# 同时更新Global.player以便后续使用
		if Global:
			Global.player = found_player
		return
	
	# 最后备用：向上查找父节点（保持向后兼容）
	var parent = get_parent()
	while parent and is_instance_valid(parent):
		if parent.has_method("get_equipped_item"):
			player_node = parent
			print("[DEBUG] 通过父节点找到玩家节点")
			# 同时更新Global.player以便后续使用
			if Global:
				Global.player = parent
			return
		parent = parent.get_parent()
	
	print("[DEBUG] 警告: 未找到有效的玩家节点")
	print("[DEBUG] 建议检查Global.player是否在player.gd的_ready中正确设置")

func update_display_based_on_equipment() -> void:
	if not is_instance_valid(player_node): 
		print("[DEBUG] 玩家节点无效，跳过更新")
		return
	var item = _get_current_item()
	var has_item = item != null
	print("[DEBUG] 更新显示 - 有物品: ", has_item, ", 可见: ", visible, ", Mesh: ", mesh != null, ", 时间: ", Time.get_ticks_msec())
	
	if item:
		# 如果有装备物品，显示对应的Mesh
		var model = item.get_model()
		var _item_name = item.名称翻译键  # 添加下划线表示未使用
		print("[DEBUG] 物品: ", _item_name, ", 模型: ", model != null)
		
		# 如果当前显示的Mesh和要装备的Mesh不同，直接切换（注释掉动画）
		if mesh != model:
			print("[DEBUG] Mesh不同，直接设置新模型")
			# play_switch_animation(model, _item_name)  # 注释掉切换动画
			_set_mesh_visuals(model)  # 直接设置Mesh
		else:
			print("[DEBUG] Mesh相同，保持显示")
			_set_mesh_visuals(model)
	else:
		print("[DEBUG] 没有物品，重置显示")
		if debug_mode and debug_mesh: 
			show_debug_mesh()
		else: 
			_reset_visuals()

func show_debug_mesh():
	mesh = debug_mesh
	visible = true
	scale = Vector3.ONE * hand_item_scale

# ==============================================================================
# 兼容性方法（保持与现有代码的兼容）
# ==============================================================================

# 兼容性方法：播放斧子砍下动画（已废弃，使用动画资源系统）
func play_axe_swing_animation(on_complete: Callable = Callable()) -> void:
	print("警告：play_axe_swing_animation 已废弃，请使用动画资源系统")
	if on_complete.is_valid():
		on_complete.call()

# 兼容性方法：播放饮料喝水动画（已废弃，使用动画资源系统）
func play_drink_animation(on_complete: Callable = Callable()) -> void:
	print("警告：play_drink_animation 已废弃，请使用动画资源系统")
	if on_complete.is_valid():
		on_complete.call()

# 兼容性方法：检查是否可以播放动画
func can_play_animation() -> bool:
	return not is_animating and visible

# 获取当前动画状态
func get_is_animating() -> bool:
	return is_animating

# ==============================================================================
# 调试方法
# ==============================================================================

# 调试信息输出
func debug_info() -> void:
	print("=== HandTake调试信息 ===")
	print("可见状态: ", visible)
	print("当前Mesh: ", mesh)
	print("玩家节点: ", player_node)
	print("是否正在动画: ", is_animating)
	print("=======================")

# 测试方法：切换显示状态
func test_toggle() -> void:
	if visible:
		_reset_visuals()
		print("测试切换：Mesh已清除")
	else:
		show_debug_mesh()

# 测试方法：播放物品动画
func test_item_animation() -> void:
	if can_play_animation():
		try_play_item_animation()
	else:
		print("无法播放物品动画: ", "正在动画中" if is_animating else "没有显示物品")
