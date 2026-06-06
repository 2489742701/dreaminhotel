# ==============================================================================
# item_preview_gui.gd - 物品预览界面控制脚本
# 负责显示选中物品的3D模型预览、名称和描述，并支持模型旋转功能
# ==============================================================================

# 扩展自Control类，表示这是一个UI控制节点
extends Control
# 定义类名为ItemPreviewGUI，方便在其他脚本中引用
class_name ItemPreviewGUI

# ========== UI组件引用 ==========
# @onready装饰器确保节点在_ready()方法调用前完成初始化

# 3D视口，用于渲染3D模型
@onready var sub_viewport := $SubViewportContainer/SubViewport as SubViewport

# 3D相机，用于观察预览模型
@onready var camera := $SubViewportContainer/SubViewport/Camera3D as Camera3D

# 预览根节点，所有3D模型都将添加到这个节点下
@onready var preview_root := $SubViewportContainer/SubViewport/PreviewRoot as Node3D

# 物品名称标签
@onready var item_name_label := $VBoxContainer/ItemNameLabel as Label

# 物品描述标签
@onready var item_description_label := $VBoxContainer/ItemDescriptionLabel as Label

# 剩余量显示标签
@onready var remaining_label := $DurabilityContainer/RemainingLabel as Label

# 耐久条容器
@onready var durability_bar := $DurabilityContainer/DurabilityBar as ProgressBar

# 视口容器，用于检测鼠标交互区域
@onready var sub_viewport_container := $SubViewportContainer as SubViewportContainer



# ========== 拖拽功能变量 ==========

# 拖拽相关变量
var is_dragging := false
var drag_item_container: Control = null

# ========== 拖拽门槛变量 ==========

# 拖拽门槛（像素）：只有移动超过这个距离才算拖拽
const DRAG_THRESHOLD: float = 10.0

# 记录鼠标按下的初始位置（用来计算移动距离）
var pending_drag_start_pos: Vector2 = Vector2.ZERO

# 是否处于"等待拖拽判定"状态
var is_pending_drag: bool = false

# ========== 拖拽专用变量 ==========
# 当前正在被拖拽的"替身"图标节点
var drag_icon_proxy: TextureRect = null
# 拖拽起始的物品索引
var drag_source_index: int = -1
# 拖拽起始的原始按钮（用于拖拽失败时飞回去）
var drag_source_button: Control = null
# 拖拽时的偏移量（让鼠标保持在点击时的相对位置）
var drag_offset: Vector2 = Vector2()

# 物品列表容器
@onready var item_grid := $ItemListContainer/ItemScroll/ItemGrid as GridContainer



# ========== 核心变量 ==========

# 当前显示的物品
var current_item: Item = null

# 当前物品在背包中的索引
var current_item_index: int = -1

# 拖拽开始位置，用于模型旋转
var drag_start: Vector2 = Vector2()

# 模型绕X轴旋转角度
var rot_x: float = 0.0

# 模型绕Y轴旋转角度
var rot_y: float = 0.0

# ========== 背包变量 ==========

# 当前背包引用
var current_inventory: inventory = null

# 物品列表
var item_buttons: Array[TextureButton] = []

# 当前选中的物品索引
var selected_item_index: int = -1

# ========== 生命周期函数 ==========

# 节点准备就绪时调用
func _ready():
	# 连接窗口大小变化信号
	var window = get_window()
	if window:
		window.size_changed.connect(_on_window_size_changed)
		# 初始检测窗口模式
		_update_scaling_factor()
	
	# 初始化物品列表
	_refresh_item_list()
# ========== 公共函数 ==========

# 设置要显示的物品
# @param it: 要显示的物品对象
# @param item_index: 物品在背包中的索引
func set_item(it: Item, item_index: int = -1):
	# 清除之前显示的模型
	# 遍历preview_root的所有子节点并释放它们
	if preview_root:
		for c in preview_root.get_children():
			c.queue_free()
	
	# 更新当前物品和索引
	current_item = it
	current_item_index = item_index
	
	# 安全检查：确保标签节点存在
	if not is_instance_valid(item_name_label) or not is_instance_valid(item_description_label):
		return
	
	# 如果没有物品，清空显示内容
	if it == null:
		item_name_label.text = ""
		item_description_label.text = ""
		if remaining_label:
			remaining_label.text = ""
		if durability_bar:
			durability_bar.visible = false
		return

	# 更新物品名称和描述文本，使用翻译系统
	# 获取翻译后的物品名称
	var translated_name = "未知物品"
	if it.名称翻译键:
		if Engine.has_singleton("Tr"):
			translated_name = Engine.get_singleton("Tr").items(it.名称翻译键)
		else:
			translated_name = it.名称翻译键
	item_name_label.text = translated_name
	# 应用物品名称颜色
	item_name_label.add_theme_color_override("font_color", it.名称颜色)
	# 获取翻译后的物品描述
	var translated_desc = "暂无介绍"
	if it.描述翻译键:
		if Engine.has_singleton("Tr"):
			translated_desc = Engine.get_singleton("Tr").items(it.描述翻译键)
		else:
			translated_desc = it.描述翻译键
	item_description_label.text = translated_desc
	
	# 更新剩余量和耐久条显示
	update_remaining_display(it)
	
	# 安全检查：确保物品有3D模型
	if not it.模型:
		print("警告: 物品 ", it.名称翻译键, " 没有关联的3D模型")
		return
	
	# 创建3D模型实例
	var mesh_instance = MeshInstance3D.new()
	# 设置模型资源
	mesh_instance.mesh = it.模型
	
	# 将模型添加到预览场景
	preview_root.add_child(mesh_instance)
	# 重置旋转角度
	rot_x = 0.0
	rot_y = 0.0
	# 应用初始旋转
	_apply_rotation()

# ========== 按钮事件处理 ==========

# 引导按钮按下事件处理函数
func _on_guide_button_pressed():
	# 发出信号，通知父节点处理引导操作
	# 信号携带当前物品索引信息
	emit_signal("guide_button_pressed", current_item_index)

# ========== 辅助方法 ==========

# 检查鼠标是否在预览区域内
# @param pos: 要检查的位置
# @return: 如果在区域内返回true，否则返回false
func is_mouse_in_preview_area(pos: Vector2) -> bool:
	# 安全检查：确保视口容器有效
	if not is_instance_valid(sub_viewport_container):
		return false
	# 获取视口容器的矩形区域
	var rect = sub_viewport_container.get_rect()
	# 检查点是否在矩形内
	return rect.has_point(pos)

# ========== 输入处理 ==========

# 处理输入事件（如鼠标拖拽和物品拖拽）
func _input(event):
	# 【核心修复】如果 UI 已经隐藏，绝对不要处理任何输入，直接返回
	if not is_visible_in_tree():
		return
	
	# --- 情况 1：已经开始拖拽了（有替身图标） ---
	if drag_icon_proxy:
		# 处理移动
		if event is InputEventMouseMotion:
			drag_icon_proxy.global_position = event.global_position - drag_offset
			# 标记事件已处理
			get_viewport().set_input_as_handled()
			return
		
		# 处理松开
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				_end_drag()
				# 这是一个拖拽行为的结束，我们要把事件吃掉，防止触发其他点击
				get_viewport().set_input_as_handled()
				return
				
	# --- 情况 2：还没有拖拽，但在观察中 ---
	elif is_pending_drag:
		# 处理移动：检查是否超过了门槛
		if event is InputEventMouseMotion:
			var move_distance = event.global_position.distance_to(pending_drag_start_pos)
			if move_distance > DRAG_THRESHOLD:
				# 【触发】移动距离够了，正式开始拖拽！
				_perform_start_drag()
				# 既然变成拖拽了，就取消等待状态
				is_pending_drag = false
				# 标记事件已处理
				get_viewport().set_input_as_handled()
				return
		
		# 处理松开：移动距离很短就松开了 -> 这是一个点击！
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				# 取消等待
				is_pending_drag = false
				# 【关键】这里什么都不用做，不要 set_input_as_handled()
				# 让这个松开的信号自然传给 Button，Button 就会触发它自带的 "pressed" 信号（选中物品）
				return
	
	# 优先处理物品拖拽（旧版本兼容）
	if is_dragging and event is InputEventMouseMotion:
		# 更新拖拽容器的位置
		if drag_item_container:
			drag_item_container.position = get_global_mouse_position() - drag_offset - item_grid.global_position
		
		# 标记事件已处理
		get_viewport().set_input_as_handled()
		return
	
	# 安全检查：确保有物品且视口容器有效
	if not current_item or not is_instance_valid(sub_viewport_container):
		# 如果没有当前物品，让事件继续传播到其他节点（如玩家控制器）
		return
	
	# 只在鼠标位于预览区域内时处理拖拽旋转
	if is_mouse_in_preview_area(get_local_mouse_position()):
		# 处理鼠标按下/松开事件
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 记录拖拽开始位置
				drag_start = event.position
			else:
				# 拖拽结束，重置开始位置
				drag_start = Vector2()
			# 标记事件已处理
			get_viewport().set_input_as_handled()
		
		# 处理鼠标移动事件（拖拽旋转）
		if event is InputEventMouseMotion and drag_start != Vector2():
			# 旋转灵敏度系数
			var rotation_sensitivity = 0.04
			# 计算水平旋转（绕Y轴）
			rot_y += event.relative.x * rotation_sensitivity
			# 计算垂直旋转（绕X轴），使用负数反转方向
			rot_x -= event.relative.y * rotation_sensitivity
			# 应用旋转
			_apply_rotation()
			# 标记事件已处理
			get_viewport().set_input_as_handled()
	else:
		# 如果鼠标不在预览区域内，让事件继续传播（不要阻止事件）
		# 这里不调用set_input_as_handled()，让事件继续传播到其他节点
		pass

# ========== 旋转应用 ==========

# 应用计算好的旋转到预览模型
func _apply_rotation():
	# 创建新的变换矩阵
	# 先绕X轴旋转rot_x角度，再绕Y轴旋转rot_y角度
	preview_root.transform = Transform3D().rotated(Vector3.RIGHT, rot_x).rotated(Vector3.UP, rot_y)

# ========== 剩余量显示功能 ==========

# 更新剩余量和耐久条显示
func update_remaining_display(item: Item) -> void:
	# 安全检查：确保UI组件存在
	if not remaining_label or not durability_bar:
		return
	
	# 重置显示
	remaining_label.text = ""
	durability_bar.visible = false
	
	# 检查物品类型并显示相应的属性
	if item.物品类型 == Item.Kind.CONSUMABLE:
		# 对于消耗品，显示剩余饮用次数
		if item.has_method("get") and item.get("可饮用次数") != null:
			var remaining_drinks = item.可饮用次数
			var max_drinks = item.最大饮用次数 if item.has_method("get") and item.get("最大饮用次数") != null else item.可饮用次数
			
			# 显示文本：剩余/最大（如 3/3）
			remaining_label.text = "剩余: %d/%d" % [remaining_drinks, max_drinks]
			
			# 显示耐久条（根据剩余次数比例）
			if remaining_drinks > 0 and max_drinks > 1:
				durability_bar.max_value = max_drinks
				durability_bar.value = remaining_drinks
				durability_bar.visible = true
			else:
				durability_bar.visible = false
			
			# 如果喝完，显示特殊文本
			if remaining_drinks <= 0:
				remaining_label.text = "已喝完"
			
		# 对于其他消耗品，显示堆叠数量
		elif item.has_method("get") and item.get("堆叠数量") != null:
			var stack_count = item.堆叠数量
			remaining_label.text = "数量: %d" % stack_count
			durability_bar.visible = false
	
	# 对于武器类物品，显示耐久度
	elif item.物品类型 == Item.Kind.WEAPON:
		if item.has_method("get") and item.get("耐久度") != null:
			var durability = item.耐久度
			var max_durability = item.最大耐久度 if item.has_method("get") and item.get("最大耐久度") != null else 100
			remaining_label.text = "耐久度: %d/%d" % [durability, max_durability]
			
			# 显示耐久条
			durability_bar.max_value = max_durability
			durability_bar.value = durability
			durability_bar.visible = true
	
	# 对于手电筒，显示电量
	elif item.物品类型 == Item.Kind.FLASHLIGHT:
		if item.has_method("get") and item.get("当前电量") != null:
			var battery = item.当前电量
			var max_battery = item.电池容量 if item.has_method("get") and item.get("电池容量") != null else 100.0
			remaining_label.text = "电量: %.0f/%.0f" % [battery, max_battery]
			
			# 显示电量条
			durability_bar.max_value = max_battery
			durability_bar.value = battery
			durability_bar.visible = true



# 设置背包引用
# 设置背包引用
# @param inv: 背包节点实例
# @description: 设置背包UI的背包引用，并连接背包变化信号
# 重要：此方法必须在玩家初始化时调用，否则背包UI无法响应背包变化
# 功能：
# 1. 断开之前的信号连接（避免重复连接）
# 2. 设置新的背包引用
# 3. 连接item_added和item_removed信号
# 4. 立即刷新物品列表显示
# 常见问题：如果背包UI不自动更新，检查是否在玩家_ready()中调用了此方法
func set_inventory(inv: inventory):
	# 先断开之前的信号连接（如果存在）
	if current_inventory and is_instance_valid(current_inventory):
		if current_inventory.has_signal("item_added") and current_inventory.item_added.is_connected(_on_inventory_changed):
			current_inventory.item_added.disconnect(_on_inventory_changed)
		if current_inventory.has_signal("item_removed") and current_inventory.item_removed.is_connected(_on_inventory_changed):
			current_inventory.item_removed.disconnect(_on_inventory_changed)
		# 断开 item_used 信号
		if current_inventory.has_signal("item_used") and current_inventory.item_used.is_connected(_on_inventory_changed):
			current_inventory.item_used.disconnect(_on_inventory_changed)
	
	current_inventory = inv
	print("ItemPreviewGUI: 接收到背包数据，物品数量: ", inv.items.size() if inv else 0)
	
	# 连接背包信号，确保每次背包变化时自动刷新
	if current_inventory and is_instance_valid(current_inventory):
		if current_inventory.has_signal("item_added") and not current_inventory.item_added.is_connected(_on_inventory_changed):
			current_inventory.item_added.connect(_on_inventory_changed)
		if current_inventory.has_signal("item_removed") and not current_inventory.item_removed.is_connected(_on_inventory_changed):
			current_inventory.item_removed.connect(_on_inventory_changed)
		# 连接 item_used 信号，用于更新消耗品进度条
		if current_inventory.has_signal("item_used") and not current_inventory.item_used.is_connected(_on_inventory_changed):
			current_inventory.item_used.connect(_on_inventory_changed)
	
	_refresh_item_list()

# 刷新物品列表显示
func _refresh_item_list():
	# ================= 修复开始 =================
	# 步骤 1：保存当前选中的物品索引
	var last_selected_index = selected_item_index
	
	# 步骤 2：直接清理 UI 父节点下的所有东西 (容器、按钮、标签全删掉)
	if item_grid:
		for child in item_grid.get_children():
			child.queue_free()
	
	# 步骤 3：清空你的数组引用，防止悬空引用
	item_buttons.clear()
	# ================= 修复结束 =================
	
	# 如果没有背包，返回
	if not current_inventory:
		print("ItemPreviewGUI: 背包数据为空，无法刷新物品列表")
		return
	
	# 检查背包物品数量
	print("ItemPreviewGUI: 开始刷新物品列表，背包物品数量: ", current_inventory.items.size())
	
	# 创建物品按钮
	for i in range(current_inventory.items.size()):
		var item_dict = current_inventory.items[i]
		var item = item_dict["item"] if item_dict.has("item") else null
		if item:
			# 创建容器来组合图标和文字
			var container = VBoxContainer.new()
			container.custom_minimum_size = Vector2(80, 80)
			
			# 启用容器的鼠标事件处理
			container.mouse_filter = Control.MOUSE_FILTER_PASS
			
			# 创建图标按钮
			var button = TextureButton.new()
			button.custom_minimum_size = Vector2(50, 50)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			
			# 【新增】禁用格子按钮的键盘焦点
			button.focus_mode = Control.FOCUS_NONE
			
			# 设置按钮图标
			if item.图标:
				# 使用自定义图标，添加黑色边框
				var bordered_icon = _add_border_to_icon(item.图标)
				button.texture_normal = bordered_icon
			else:
				print("ItemPreviewGUI: 物品 ", item.名称翻译键, " 没有图标，使用默认图标")
				# 为没有图标的物品创建默认图标（已有边框）
				var default_icon = _create_default_icon(item)
				button.texture_normal = default_icon
			
			# 创建文字标签
			var label = Label.new()
			label.custom_minimum_size = Vector2(70, 20)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			
			# 获取物品名称
			var item_name = "未知物品"
			if item.名称翻译键:
				if Engine.has_singleton("Tr"):
					item_name = Engine.get_singleton("Tr").items(item.名称翻译键)
				else:
					item_name = item.名称翻译键
			
			# 限制文字长度，防止过长
			if item_name.length() > 6:
				item_name = item_name.substr(0, 6) + "..."
			
			label.text = item_name
			label.add_theme_font_size_override("font_size", 10)
			
			# 连接按钮信号
			button.pressed.connect(_on_item_button_pressed.bind(i))
			
			# 【重点修改】连接信号，传递索引和按钮自身
			# 我们直接在 button 上监听，而不是外面的 container，这样坐标计算更准
			button.gui_input.connect(_on_slot_gui_input.bind(i, button))
			
			# 【修复bug】不再为容器添加拖拽支持，避免点击文字时触发拖拽
			# container.gui_input.connect(_on_item_container_gui_input.bind(i, container))
			
			# 将图标和文字添加到容器
			container.add_child(button)
			container.add_child(label)
			
			# 添加到网格容器
			item_grid.add_child(container)
			item_buttons.append(button)
			print("ItemPreviewGUI: 添加物品按钮: ", item.名称翻译键)
		else:
			print("ItemPreviewGUI: 物品索引 ", i, " 的物品数据为空")
	
	print("ItemPreviewGUI: 物品列表刷新完成，共添加 ", item_buttons.size(), " 个物品按钮")
	
	# 步骤 4：恢复上次选中的物品索引
	if last_selected_index >= 0 and last_selected_index < item_buttons.size():
		selected_item_index = last_selected_index
		_on_item_button_pressed(selected_item_index)
		print("ItemPreviewGUI: 恢复上次选中的物品索引: ", last_selected_index)

# 物品按钮按下事件
func _on_item_button_pressed(item_index: int):
	if current_inventory and item_index >= 0 and item_index < current_inventory.items.size():
		var item_dict = current_inventory.items[item_index]
		var item = item_dict["item"] if item_dict.has("item") else null
		if item:
			# 更新选中状态
			_update_selected_item(item_index)
			selected_item_index = item_index
			set_item(item, item_index)


# ========== 核心拖拽逻辑 ==========

# 1. 处理格子的输入事件
func _on_slot_gui_input(event: InputEvent, index: int, button: Control):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# ==========================================
				# 【核心修改】一按下立刻选中！
				# 不用等松开，不用等拖拽，直接由代码触发选中逻辑
				# ==========================================
				_on_item_button_pressed(index)

				# 下面继续保留拖拽的准备工作
				# (这样既能瞬间选中，又能顺便开始拖拽，两不误)
				is_pending_drag = true
				pending_drag_start_pos = event.global_position
				drag_source_index = index
				drag_source_button = button
			else:
				# 鼠标松开
				is_pending_drag = false

# 物品容器GUI输入事件处理（保留旧版本兼容性）
func _on_item_container_gui_input(event: InputEvent, item_index: int, container: Control):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 开始拖拽
			is_dragging = true
			drag_source_index = item_index
			drag_item_container = container
			drag_offset = container.get_global_mouse_position() - container.global_position
			
			# 添加拖拽视觉反馈
			container.modulate = Color(1.2, 1.2, 1.2, 0.8)
			
			# 标记事件已处理
			get_viewport().set_input_as_handled()
		else:
			# 结束拖拽
			if is_dragging:
				is_dragging = false
				
				# 恢复拖拽容器的视觉状态
				if drag_item_container:
					drag_item_container.modulate = Color.WHITE
				
				# 检查是否拖拽到了其他物品容器上
				var target_index = _get_drop_target_index()
				if target_index != -1 and target_index != drag_source_index:
					# 交换物品位置
					_swap_items(drag_source_index, target_index)
				
				# 重置拖拽状态
				drag_source_index = -1
				drag_item_container = null
				drag_offset = Vector2()
				
				# 标记事件已处理
				get_viewport().set_input_as_handled()

# 3. 开始拖拽
# 这个函数现在没有参数了，直接使用成员变量
func _perform_start_drag():
	# 再次确认数据有效
	if drag_source_button == null or drag_source_index == -1:
		return

	# 计算偏移量（使用当前记录的按下位置）
	drag_offset = pending_drag_start_pos - drag_source_button.global_position
	
	# === 创建替身 (代码和之前一样) ===
	var texture = null
	if drag_source_button is TextureButton:
		texture = drag_source_button.texture_normal
	
	if texture:
		drag_icon_proxy = TextureRect.new()
		drag_icon_proxy.texture = texture
		drag_icon_proxy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		drag_icon_proxy.size = drag_source_button.size
		# 设置在最上层 (Z-Index)，防止被其他UI遮挡
		drag_icon_proxy.z_index = 4096 # 确保最顶层
		drag_icon_proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE # 替身不阻挡鼠标射线
		
		# 将替身添加到当前场景的最顶层
		get_tree().root.add_child(drag_icon_proxy)
		
		# 设置初始位置
		drag_icon_proxy.global_position = drag_source_button.global_position
		
		# === 隐藏真身 ===
		# 只是调节透明度为0，保留占位，不破坏 Grid 布局
		drag_source_button.modulate.a = 0.0

# 4. 结束拖拽
func _end_drag():
	if not drag_icon_proxy:
		return
		
	# 获取鼠标下的目标索引
	var target_index = _get_slot_under_mouse()
	
	# 判断是否为有效交换
	if target_index != -1 and target_index != drag_source_index:
		# === 情况 A: 成功交换 ===
		_swap_items(drag_source_index, target_index)
		
		# 销毁替身
		drag_icon_proxy.queue_free()
		drag_icon_proxy = null
		# 不需要恢复真身显示，因为 _swap_items 会调用 refresh 重绘整个界面
	else:
		# === 情况 B: 无效拖拽，自动复位 ===
		# 创建一个动画，让替身飞回原来的位置
		var tween = create_tween()
		# 0.2秒内飞回原按钮位置
		tween.tween_property(drag_icon_proxy, "global_position", drag_source_button.global_position, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# 动画结束后执行清理
		tween.tween_callback(Callable(func():
			if is_instance_valid(drag_icon_proxy):
				drag_icon_proxy.queue_free()
				drag_icon_proxy = null
			if is_instance_valid(drag_source_button):
				# 恢复真身显示
				drag_source_button.modulate.a = 1.0
		))

# 5. 辅助：检测鼠标下的格子
func _get_slot_under_mouse() -> int:
	var mouse_pos = get_global_mouse_position()
	
	# 检查所有物品按钮区域
	for i in range(item_buttons.size()):
		var btn = item_buttons[i]
		
		# 使用容器的矩形作为判定范围，容器比按钮大（80x80 vs 50x50）
		var container = btn.get_parent()
		if container and container.get_global_rect().has_point(mouse_pos):
			return i
			
	return -1

# 获取拖拽目标索引（保留旧版本兼容性）
func _get_drop_target_index() -> int:
	if not drag_item_container:
		return -1
	
	# 获取鼠标位置
	var mouse_pos = get_global_mouse_position()
	
	# 检查鼠标是否在物品网格内
	if not item_grid.get_global_rect().has_point(mouse_pos):
		return -1
	
	# 遍历所有物品容器，检查鼠标是否在其上
	for i in range(item_grid.get_child_count()):
		var container = item_grid.get_child(i)
		if container and container != drag_item_container and container.get_global_rect().has_point(mouse_pos):
			return i
	
	return -1

# 交换物品位置
func _swap_items(source_index: int, target_index: int):
	if not current_inventory or source_index < 0 or target_index < 0:
		return
	
	if source_index >= current_inventory.items.size() or target_index >= current_inventory.items.size():
		return
	
	# 交换物品数据
	var temp = current_inventory.items[source_index]
	current_inventory.items[source_index] = current_inventory.items[target_index]
	current_inventory.items[target_index] = temp
	
	# 更新选中索引
	if selected_item_index == source_index:
		selected_item_index = target_index
	elif selected_item_index == target_index:
		selected_item_index = source_index
	

	
	# 刷新物品列表显示
	_refresh_item_list()
	
	print("ItemPreviewGUI: 交换物品位置 %d <-> %d" % [source_index, target_index])





# 更新选中物品的视觉反馈
func _update_selected_item(selected_index: int):
	# 重置所有按钮的样式
	for i in range(item_buttons.size()):
		var button = item_buttons[i]
		if button:
			# 移除选中样式
			button.modulate = Color.WHITE
			# 同时重置容器边框（如果有的话）
			var container = button.get_parent()
			if container and container.is_class("VBoxContainer"):
				# 使用空的样式框而不是null来重置样式
				var empty_stylebox = StyleBoxEmpty.new()
				if empty_stylebox:
					container.add_theme_stylebox_override("panel", empty_stylebox)
	
	# 高亮选中的按钮
	if selected_index >= 0 and selected_index < item_buttons.size():
		var selected_button = item_buttons[selected_index]
		if selected_button:
			# 添加选中样式（稍微变亮）
			selected_button.modulate = Color(1.2, 1.2, 1.2)
			# 为容器添加边框样式
			var container = selected_button.get_parent()
			if container and container.is_class("VBoxContainer"):
				var stylebox = StyleBoxFlat.new()
				if stylebox:
					stylebox.bg_color = Color(0.2, 0.5, 1.0, 0.3)  # 半透明蓝色背景
					stylebox.border_width_bottom = 2
					stylebox.border_width_left = 2
					stylebox.border_width_right = 2
					stylebox.border_width_top = 2
					stylebox.border_color = Color(0.1, 0.3, 0.8)
					container.add_theme_stylebox_override("panel", stylebox)

# ========== 默认图标创建 ==========

# 公共默认图标配置
var default_icon_colors: Dictionary = {
	Item.Kind.KEY: Color.GOLD,      # 钥匙类物品使用金色
	Item.Kind.WEAPON: Color.SILVER, # 武器类物品使用银色
	Item.Kind.CONSUMABLE: Color.GREEN, # 消耗品类物品使用绿色
	Item.Kind.TOOL: Color.CYAN,     # 工具类物品使用青色
	Item.Kind.FLASHLIGHT: Color.YELLOW, # 手电筒类物品使用黄色
	"default": Color.GRAY           # 其他类型使用灰色
}

# 公共默认图标尺寸
var default_icon_size: Vector2i = Vector2i(50, 50)

# 最大图标尺寸（防止过大图片破坏布局）
var max_icon_size: Vector2i = Vector2i(50, 50)

# 全屏缩放系数
var fullscreen_scale_factor: float = 2.0

# 基础图标尺寸（窗口模式）
var base_icon_size: Vector2i = Vector2i(50, 50)

# 当前缩放系数
var current_scale_factor: float = 1.0



# 为没有图标的物品创建默认图标
# @param item: 物品对象
# @return: 默认图标纹理
func _create_default_icon(item: Item) -> Texture2D:
	# 检查物品是否有自定义图标颜色属性
	var icon_color: Color
	if item.get("图标颜色") != null and item.图标颜色 != Color.TRANSPARENT:
		# 使用物品的图标颜色属性
		icon_color = item.图标颜色
	else:
		# 根据物品类型设置默认颜色
		icon_color = default_icon_colors.get(item.物品类型, default_icon_colors["default"])
	
	# 创建一个简单的默认图标
	var image = Image.create(default_icon_size.x, default_icon_size.y, false, Image.FORMAT_RGBA8)
	
	# 填充整个图像为指定颜色
	image.fill(icon_color)
	
	# 添加一个简单的边框
	var border_color = icon_color.darkened(0.3)
	for x in range(default_icon_size.x):
		for y in range(default_icon_size.y):
			if x < 2 or x >= default_icon_size.x - 2 or y < 2 or y >= default_icon_size.y - 2:
				image.set_pixel(x, y, border_color)
	
	# 如果物品有名称，在图标中心添加首字母
	if item.get("名称翻译键") != null and item.名称翻译键.length() > 0:
		_add_text_to_icon(image, item.名称翻译键[0], icon_color)
	
	# 创建纹理
	var texture = ImageTexture.create_from_image(image)
	return texture

# 给图标添加白色边框
# @param original_texture: 原始图标纹理
# @return: 带边框的图标纹理
func _add_border_to_icon(original_texture: Texture2D) -> Texture2D:
	# 获取原始图像
	var image = original_texture.get_image()
	
	# 创建新图像（比原图大4像素，用于边框）
	var bordered_image = Image.create(image.get_width() + 4, image.get_height() + 4, false, Image.FORMAT_RGBA8)
	
	# 填充背景为白色（边框颜色）
	bordered_image.fill(Color.WHITE)
	
	# 将原图绘制到中心位置（留出2像素边框）
	bordered_image.blit_rect(image, Rect2i(2, 2, image.get_width(), image.get_height()), Vector2i(2, 2))
	
	# 创建纹理
	var bordered_texture = ImageTexture.create_from_image(bordered_image)
	return bordered_texture

# 在图标上添加文字
# @param image: 图像对象
# @param text: 要添加的文字
# @param text_color: 文字颜色
func _add_text_to_icon(image: Image, text: String, text_color: Color) -> void:
	# 简单的文字绘制（使用大写首字母）
	var _char_code = text.to_upper().unicode_at(0)
	var center_x = default_icon_size.x / 2.0
	var center_y = default_icon_size.y / 2.0
	
	# 绘制一个简单的字符轮廓
	for x in range(center_x - 5, center_x + 6):
		for y in range(center_y - 5, center_y + 6):
			if x >= 0 and x < default_icon_size.x and y >= 0 and y < default_icon_size.y:
				# 简单的字符形状（字母A）
				if (x == center_x - 2 and y >= center_y - 3 and y <= center_y + 3) or \
				   (x == center_x + 2 and y >= center_y - 3 and y <= center_y + 3) or \
				   (y == center_y - 3 and x >= center_x - 2 and x <= center_x + 2) or \
				   (y == center_y and x >= center_x - 2 and x <= center_x + 2):
					image.set_pixel(x, y, text_color.darkened(0.7))

# ========== 全屏缩放功能 (新增部分) ==========

# 窗口大小变化处理函数
func _on_window_size_changed() -> void:
	_update_scaling_factor()
	# 刷新物品列表以应用新的缩放
	_refresh_item_list()

# 更新缩放系数
func _update_scaling_factor() -> void:
	var window = get_window()
	if not window:
		return
	
	# 检测是否为全屏模式
	var is_fullscreen = window.mode == Window.MODE_FULLSCREEN || window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	
	if is_fullscreen:
		# 全屏模式：使用缩放系数
		current_scale_factor = fullscreen_scale_factor
	else:
		# 窗口模式：使用基础缩放
		current_scale_factor = 1.0
	
	# 更新最大图标尺寸
	max_icon_size = base_icon_size * current_scale_factor

# ========== 生命周期与清理 (新增部分) ==========

# 监听节点通知（Godot 内置虚函数）
func _notification(what):
	# 当节点的可见性发生变化时（例如按Tab关闭了背包）
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		# 如果当前变为不可见
		if not is_visible_in_tree():
			_force_cancel_drag()

# 强制取消拖拽并清理残余图标
func _force_cancel_drag():
	# 1. 清理替身图标
	if drag_icon_proxy and is_instance_valid(drag_icon_proxy):
		drag_icon_proxy.queue_free()
	drag_icon_proxy = null
	
	# 2. 恢复原始按钮的显示（如果在拖拽中途关闭）
	if drag_source_button and is_instance_valid(drag_source_button):
		drag_source_button.modulate.a = 1.0
	drag_source_button = null
	
	# 3. 【新增】重置所有拖拽判定开关，防止左键被锁死
	is_pending_drag = false
	is_dragging = false
	drag_source_index = -1
	pending_drag_start_pos = Vector2.ZERO
	
	# 4. 清理旧变量
	drag_item_container = null

# ========== 背包信号处理 ==========

# 处理背包变化事件（物品添加或移除）
# 背包内容变化事件处理
# @param _item_index: 变化的物品索引
# @param _item: 变化的物品实例
# @description: 响应背包物品变化信号，自动刷新物品列表显示
# 触发条件：当背包中添加或移除物品时
# 重要：此方法是背包UI自动刷新的关键，确保UI与数据同步
# 注意：此方法通过信号连接自动调用，无需手动触发
func _on_inventory_changed(_item_index: int, _item: Item) -> void:
	print("ItemPreviewGUI: 背包内容发生变化，刷新物品列表")
	_refresh_item_list()
	# 如果当前有选中物品，强制更新其显示（包括进度条）
	if selected_item_index >= 0 and current_inventory and selected_item_index < current_inventory.items.size():
		var item_dict = current_inventory.items[selected_item_index]
		var item = item_dict["item"] if item_dict.has("item") else null
		if item:
			# 强制刷新当前选中物品的进度条
			update_remaining_display(item)
			print("ItemPreviewGUI: 更新当前选中物品的进度条显示")
