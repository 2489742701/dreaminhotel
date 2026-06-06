# ==============================================================================
# hotbar_ui.gd
# 快捷栏UI控制器
# 负责显示和管理快捷栏（背包前三个物品）
# ==============================================================================

extends Control

# ========== 节点引用 ==========
@onready var hotbar_container: HBoxContainer = $HotbarContainer
@onready var slot_1: TextureButton = $HotbarContainer/Slot1
@onready var slot_2: TextureButton = $HotbarContainer/Slot2
@onready var slot_3: TextureButton = $HotbarContainer/Slot3

# ========== 变量定义 ==========
var current_inventory: Node = null
var selected_slot: int = -1

# ========== 拥有者玩家系统 ==========

# 拥有此UI的玩家节点
var owner_player: Node = null

# 设置拥有者玩家
# @param player: 玩家节点
func set_owner_player(player: Node) -> void:
	owner_player = player

# 获取拥有者玩家
# @return: 玩家节点
func get_owner_player() -> Node:
	return owner_player

# ========== 初始化方法 ==========
func _ready():
	# 设置鼠标过滤模式为忽略，防止UI节点拦截鼠标事件
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 连接快捷栏槽位的信号
	if slot_1:
		slot_1.pressed.connect(_on_slot_pressed.bind(0))
	if slot_2:
		slot_2.pressed.connect(_on_slot_pressed.bind(1))
	if slot_3:
		slot_3.pressed.connect(_on_slot_pressed.bind(2))
	
	# 初始化快捷栏显示
	_refresh_hotbar()

# 断开背包事件连接
func _exit_tree():
	_disconnect_inventory_signals()

# ========== 公共方法 ==========

# 设置背包引用
# @param inv: 背包节点实例
# @description: 设置快捷栏的背包引用，并连接背包变化信号
# 重要：此方法必须在玩家初始化时调用，否则快捷栏无法响应背包变化
# 常见问题：如果快捷栏没有自动更新，检查是否在玩家_ready()中调用了此方法
func set_inventory(inv: Node) -> void:
	# 先断开之前的背包事件连接
	_disconnect_inventory_signals()
	
	current_inventory = inv
	_refresh_hotbar()
	
	# 连接新的背包事件
	_connect_inventory_signals()

# 刷新快捷栏显示
func _refresh_hotbar() -> void:
	if not current_inventory:
		# 清空所有槽位
		_clear_slot(0)
		_clear_slot(1)
		_clear_slot(2)
		return
	
	# 显示前三个物品
	for i in range(3):
		if i < current_inventory.items.size():
			var item_entry = current_inventory.items[i]
			var item = item_entry.item if item_entry and item_entry.has("item") else null
			if item:
				_set_slot_item(i, item)
		else:
			_clear_slot(i)
	
	# 更新选中状态
	_update_selection()

# 设置槽位物品
func _set_slot_item(slot_index: int, item: Item) -> void:
	var slot_button: TextureButton = null
	match slot_index:
		0: slot_button = slot_1
		1: slot_button = slot_2
		2: slot_button = slot_3
	
	if slot_button and item:
		if item.图标:
			# 使用自定义图标，添加黑色边框
			var bordered_icon = _add_border_to_icon(item.图标)
			slot_button.texture_normal = bordered_icon
		else:
			# 创建默认图标（已有边框）
			var default_icon = _create_default_icon(item)
			slot_button.texture_normal = default_icon
		
		# 设置工具提示
		slot_button.tooltip_text = item.名称翻译键
		
		# 显示槽位
		slot_button.visible = true

# 清空槽位
func _clear_slot(slot_index: int) -> void:
	var slot_button: TextureButton = null
	match slot_index:
		0: slot_button = slot_1
		1: slot_button = slot_2
		2: slot_button = slot_3
	
	if slot_button:
		slot_button.texture_normal = null
		slot_button.tooltip_text = ""
		slot_button.visible = false

# 创建默认图标
func _create_default_icon(item: Item) -> Texture2D:
	# 检查物品是否有自定义图标颜色属性
	var icon_color: Color
	if item.get("图标颜色") != null and item.图标颜色 != Color.TRANSPARENT:
		# 使用物品的图标颜色属性
		icon_color = item.图标颜色
	else:
		# 根据物品类型设置默认颜色
		var default_colors = {
			Item.Kind.KEY: Color.GOLD,      # 钥匙类物品使用金色
			Item.Kind.WEAPON: Color.SILVER, # 武器类物品使用银色
			Item.Kind.CONSUMABLE: Color.GREEN, # 消耗品类物品使用绿色
			Item.Kind.TOOL: Color.CYAN,     # 工具类物品使用青色
			Item.Kind.FLASHLIGHT: Color.YELLOW, # 手电筒类物品使用黄色
		}
		icon_color = default_colors.get(item.物品类型, Color.GRAY)  # 其他类型使用灰色
	
	# 创建一个简单的默认图标
	var image = Image.create(50, 50, false, Image.FORMAT_RGBA8)
	
	# 填充整个图像为指定颜色
	image.fill(icon_color)
	
	# 添加一个简单的边框
	var border_color = icon_color.darkened(0.3)
	for x in range(50):
		for y in range(50):
			if x < 2 or x >= 48 or y < 2 or y >= 48:
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
func _add_text_to_icon(image: Image, text: String, text_color: Color) -> void:
	# 简单的文字绘制（使用大写首字母）
	var _char_code = text.to_upper().unicode_at(0)
	var center_x = 25
	var center_y = 25
	
	# 绘制一个简单的字符轮廓
	for x in range(center_x - 5, center_x + 6):
		for y in range(center_y - 5, center_y + 6):
			if x >= 0 and x < 50 and y >= 0 and y < 50:
				# 简单的字符形状（字母A）
				if (x == center_x - 2 and y >= center_y - 3 and y <= center_y + 3) or \
				   (x == center_x + 2 and y >= center_y - 3 and y <= center_y + 3) or \
				   (y == center_y - 3 and x >= center_x - 2 and x <= center_x + 2) or \
				   (y == center_y and x >= center_x - 2 and x <= center_x + 2):
					image.set_pixel(x, y, text_color.darkened(0.7))

# 更新选中状态
func _update_selection() -> void:
	# 重置所有槽位的选中状态
	for i in range(3):
		var slot_button: TextureButton = null
		match i:
			0: slot_button = slot_1
			1: slot_button = slot_2
			2: slot_button = slot_3
		
		if slot_button:
			# 简单的选中状态显示（可以修改样式）
			if i == selected_slot:
				slot_button.modulate = Color(1.0, 1.0, 1.0, 1.0)  # 选中状态
			else:
				slot_button.modulate = Color(0.7, 0.7, 0.7, 0.8)  # 未选中状态

# ========== 事件处理 ==========

# 槽位点击事件
func _on_slot_pressed(slot_index: int) -> void:
	# 检查槽位是否有物品
	if slot_index < current_inventory.items.size():
		var item_entry = current_inventory.items[slot_index]
		var item = item_entry.item if item_entry and item_entry.has("item") else null
		
		if item:
			# 装备该物品
			equip_item_from_hotbar(slot_index, item)

# 从快捷栏装备物品
func equip_item_from_hotbar(slot_index: int, item: Item) -> void:
	# 设置选中槽位
	selected_slot = slot_index
	_update_selection()
	
	# 发送装备事件
	if Global.player and Global.player.has_method("equip_item"):
		Global.player.equip_item(item)
	
	# 通知体力值UI有物品栏活动
	_notify_hotbar_activity()
	
	print("快捷栏装备: ", item.名称翻译键, " (槽位: ", slot_index, ")")

# 通知体力值UI有物品栏活动
func _notify_hotbar_activity() -> void:
	# 获取父节点（StaminaUI）并通知有物品栏活动
	var parent = get_parent()
	if parent and parent.has_method("更新物品名称显示"):
		# 调用更新物品名称显示来重置计时器
		parent.更新物品名称显示(parent.当前物品名称)

# 获取当前选中的槽位索引
func get_selected_slot() -> int:
	return selected_slot

# 快捷栏滚轮切换
func switch_hotbar_item(is_up: bool) -> void:
	if not current_inventory or current_inventory.items.size() == 0:
		return
	
	var next_slot = 0
	if selected_slot >= 0 and selected_slot < current_inventory.items.size():
		if is_up:
			# 向上滚动：切换到前一个槽位
			next_slot = (selected_slot - 1 + current_inventory.items.size()) % current_inventory.items.size()
		else:
			# 向下滚动：切换到后一个槽位
			next_slot = (selected_slot + 1) % current_inventory.items.size()
	else:
		# 当前没有选中槽位，从第一个开始
		next_slot = 0
	
	# 确保不超过前三个槽位
	if next_slot >= 3:
		next_slot = 0
	
	# 装备新物品
	if next_slot < current_inventory.items.size():
		var item_entry = current_inventory.items[next_slot]
		var item = item_entry.item if item_entry and item_entry.has("item") else null
		if item:
			equip_item_from_hotbar(next_slot, item)
	else:
		# 即使没有物品，也要通知有活动
		_notify_hotbar_activity()

# ========== 背包事件处理 ==========

# 连接背包事件信号
# @description: 连接背包的四个主要信号，确保快捷栏能响应背包变化
# 连接的信号：
# - item_added: 物品被添加时触发
# - item_removed: 物品被移除时触发  
# - item_used: 物品被使用时触发
# - equipment_changed: 装备状态变化时触发
# 注意：这些连接是自动刷新机制的核心，确保快捷栏与背包数据同步
func _connect_inventory_signals() -> void:
	if current_inventory and current_inventory.has_signal("item_added"):
		if not current_inventory.item_added.is_connected(_on_inventory_changed):
			current_inventory.item_added.connect(_on_inventory_changed)
	if current_inventory and current_inventory.has_signal("item_removed"):
		if not current_inventory.item_removed.is_connected(_on_inventory_changed):
			current_inventory.item_removed.connect(_on_inventory_changed)
	if current_inventory and current_inventory.has_signal("item_used"):
		if not current_inventory.item_used.is_connected(_on_inventory_changed):
			current_inventory.item_used.connect(_on_inventory_changed)
	if current_inventory and current_inventory.has_signal("equipment_changed"):
		if not current_inventory.equipment_changed.is_connected(_on_equipment_changed):
			current_inventory.equipment_changed.connect(_on_equipment_changed)

# 断开背包事件信号
func _disconnect_inventory_signals() -> void:
	if current_inventory and current_inventory.has_signal("item_added"):
		if current_inventory.item_added.is_connected(_on_inventory_changed):
			current_inventory.item_added.disconnect(_on_inventory_changed)
	if current_inventory and current_inventory.has_signal("item_removed"):
		if current_inventory.item_removed.is_connected(_on_inventory_changed):
			current_inventory.item_removed.disconnect(_on_inventory_changed)
	if current_inventory and current_inventory.has_signal("item_used"):
		if current_inventory.item_used.is_connected(_on_inventory_changed):
			current_inventory.item_used.disconnect(_on_inventory_changed)
	if current_inventory and current_inventory.has_signal("equipment_changed"):
		if current_inventory.equipment_changed.is_connected(_on_equipment_changed):
			current_inventory.equipment_changed.disconnect(_on_equipment_changed)

# 背包物品变化事件
# @param _item_index: 变化的物品索引
# @param _item: 变化的物品实例
# @description: 响应背包物品变化信号，自动刷新快捷栏显示
# 触发条件：当背包中添加、移除或使用物品时
# 重要：此方法是快捷栏自动刷新的关键，确保UI与数据同步
func _on_inventory_changed(_item_index: int, _item: Item) -> void:
	# 当背包物品发生变化时，立即刷新快捷栏
	_refresh_hotbar()

# 装备状态变化事件
func _on_equipment_changed(_equipped_item: Item, equipped_index: int) -> void:
	# 当装备状态变化时，更新选中状态
	if equipped_index >= 0 and equipped_index < 3:
		selected_slot = equipped_index
	else:
		selected_slot = -1
	
	_update_selection()
