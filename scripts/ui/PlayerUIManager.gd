# ==============================================================================
# PlayerUIManager.gd - 玩家UI管理器
# 负责管理单个玩家的所有UI组件，提供统一的UI更新接口
# 优化：将UI逻辑从player.gd中分离，支持多人游戏
# ==============================================================================

extends Node

# ==============================================================================
# UI组件引用
# ==============================================================================

# 体力UI控制器
var stamina_ui: Control = null

# 快捷栏UI控制器
var hotbar_ui: Control = null

# 背包UI控制器
var inventory_gui: CanvasLayer = null

# 手持物品显示节点
var hand_take: MeshInstance3D = null

# ==============================================================================
# 初始化方法
# ==============================================================================

# 绑定UI组件
# @param stamina: 体力UI节点
# @param hotbar: 快捷栏UI节点
# @param inv: 背包UI节点
# @param hand: 手持物品节点
# @param player: 拥有此UI的玩家节点
func bind_ui(stamina: Control, hotbar: Control, inv: CanvasLayer, hand: MeshInstance3D, player: Node = null) -> void:
	stamina_ui = stamina
	hotbar_ui = hotbar
	inventory_gui = inv
	hand_take = hand
	
	# 设置UI组件的拥有者玩家
	if player:
		if stamina_ui and stamina_ui.has_method("set_owner_player"):
			stamina_ui.set_owner_player(player)
		if hotbar_ui and hotbar_ui.has_method("set_owner_player"):
			hotbar_ui.set_owner_player(player)
		if hand_take and hand_take.has_method("set_owner_player"):
			hand_take.set_owner_player(player)

# ==============================================================================
# 体力UI方法
# ==============================================================================

# 更新体力显示
# @param current: 当前体力值
# @param max_val: 最大体力值
func update_stamina(current: float, max_val: float) -> void:
	if stamina_ui and is_instance_valid(stamina_ui):
		if stamina_ui.has_method("update_stamina"):
			stamina_ui.update_stamina(current, max_val)
		elif stamina_ui.has_method("更新体力显示"):
			stamina_ui.更新体力显示(current, max_val)

# 更新物品名称显示
# @param item_name: 物品名称
func update_item_name(item_name: String) -> void:
	if stamina_ui and is_instance_valid(stamina_ui):
		if stamina_ui.has_method("update_item_name"):
			stamina_ui.update_item_name(item_name)
		elif stamina_ui.has_method("更新物品名称显示"):
			stamina_ui.更新物品名称显示(item_name)

# 显示门状态文本
# @param door_name: 门名称
# @param door_state: 门状态
func show_door_state(door_name: String, door_state: String) -> void:
	if stamina_ui and is_instance_valid(stamina_ui):
		if stamina_ui.has_method("show_door_state"):
			stamina_ui.show_door_state(door_name, door_state)
		elif stamina_ui.has_method("显示门状态"):
			stamina_ui.显示门状态(door_name, door_state)

# 显示剩余水量
# @param current: 当前水量
# @param max_val: 最大水量
func show_water_remaining(current: float, max_val: float) -> void:
	if stamina_ui and is_instance_valid(stamina_ui):
		if stamina_ui.has_method("show_water_remaining"):
			stamina_ui.show_water_remaining(current, max_val)
		elif stamina_ui.has_method("显示剩余水量"):
			stamina_ui.显示剩余水量(current, max_val)

# 清除状态文本
func clear_status_text() -> void:
	if stamina_ui and is_instance_valid(stamina_ui):
		if stamina_ui.has_method("clear_status_text"):
			stamina_ui.clear_status_text()
		elif stamina_ui.has_method("清除状态文本"):
			stamina_ui.清除状态文本()

# 更新状态文本
# @param text: 状态文本
func update_status_text(text: String) -> void:
	if stamina_ui and is_instance_valid(stamina_ui):
		if stamina_ui.has_method("update_status_text"):
			stamina_ui.update_status_text(text)
		elif stamina_ui.has_method("更新状态文本显示"):
			stamina_ui.更新状态文本显示(text)

# 清除字幕文本
func clear_subtitle_text() -> void:
	if stamina_ui and is_instance_valid(stamina_ui):
		if stamina_ui.has_method("clear_subtitle_text"):
			stamina_ui.clear_subtitle_text()
		elif stamina_ui.has_method("清除字幕文本"):
			stamina_ui.清除字幕文本()

# 更新字幕文本
# @param text: 字幕文本
func update_subtitle_text(text: String) -> void:
	if stamina_ui and is_instance_valid(stamina_ui):
		if stamina_ui.has_method("update_subtitle_text"):
			stamina_ui.update_subtitle_text(text)
		elif stamina_ui.has_method("更新字幕文本显示"):
			stamina_ui.更新字幕文本显示(text)

# ==============================================================================
# 快捷栏UI方法
# ==============================================================================

# 设置快捷栏背包引用
# @param inv: 背包节点
func set_hotbar_inventory(inv: Node) -> void:
	if hotbar_ui and is_instance_valid(hotbar_ui):
		if hotbar_ui.has_method("set_inventory"):
			hotbar_ui.set_inventory(inv)

# 切换快捷栏物品
# @param is_up: 是否向上滚动
func switch_hotbar_item(is_up: bool) -> void:
	if hotbar_ui and is_instance_valid(hotbar_ui):
		if hotbar_ui.has_method("switch_hotbar_item"):
			hotbar_ui.switch_hotbar_item(is_up)

# ==============================================================================
# 背包UI方法
# ==============================================================================

# 设置背包数据
# @param inv: 背包节点
func set_inventory(inv: Node) -> void:
	if inventory_gui and is_instance_valid(inventory_gui):
		if inventory_gui.has_method("set_inventory"):
			inventory_gui.set_inventory(inv)

# 设置要显示的物品
# @param item: 物品对象
# @param item_index: 物品索引
# @param is_equipped: 是否装备
func set_item(item: Item, item_index: int = -1, is_equipped: bool = false) -> void:
	if inventory_gui and is_instance_valid(inventory_gui):
		if inventory_gui.has_method("set_item"):
			inventory_gui.set_item(item, item_index, is_equipped)

# 刷新背包显示
func refresh_inventory() -> void:
	if inventory_gui and is_instance_valid(inventory_gui):
		if inventory_gui.has_method("refresh"):
			inventory_gui.refresh()

# 切换背包显示状态
# @param visible: 是否可见
func set_inventory_visible(visible: bool) -> void:
	if inventory_gui and is_instance_valid(inventory_gui):
		inventory_gui.visible = visible

# ==============================================================================
# 手持物品方法
# ==============================================================================

# 显示物品Mesh
# @param item: 物品对象
func show_item_mesh(item: Item) -> void:
	if hand_take and is_instance_valid(hand_take):
		if hand_take.has_method("show_item_mesh"):
			hand_take.show_item_mesh(item)

# 清除物品显示
func clear_item() -> void:
	if hand_take and is_instance_valid(hand_take):
		if hand_take.has_method("clear_item"):
			hand_take.clear_item()

# 播放物品动画
# @param on_complete: 动画完成回调
func play_item_animation(on_complete: Callable = Callable()) -> void:
	if hand_take and is_instance_valid(hand_take):
		if hand_take.has_method("try_play_item_animation"):
			hand_take.try_play_item_animation(on_complete)

# ==============================================================================
# 综合UI控制方法
# ==============================================================================

# 显示所有UI
func show_all_ui() -> void:
	if stamina_ui and is_instance_valid(stamina_ui):
		stamina_ui.visible = true
	if hotbar_ui and is_instance_valid(hotbar_ui):
		hotbar_ui.visible = true

# 隐藏所有UI
func hide_all_ui() -> void:
	if stamina_ui and is_instance_valid(stamina_ui):
		stamina_ui.visible = false
	if hotbar_ui and is_instance_valid(hotbar_ui):
		hotbar_ui.visible = false
	if inventory_gui and is_instance_valid(inventory_gui):
		inventory_gui.visible = false

# 设置UI可见性
# @param visible: 是否可见
func set_ui_visible(visible: bool) -> void:
	if visible:
		show_all_ui()
	else:
		hide_all_ui()

# ==============================================================================
# 背包事件处理
# ==============================================================================

# 连接背包事件信号
# @param inv: 背包节点
func connect_inventory_signals(inv: Node) -> void:
	if inv and inv.has_signal("item_added"):
		inv.item_added.connect(_on_inventory_item_added)
	if inv and inv.has_signal("item_removed"):
		inv.item_removed.connect(_on_inventory_item_removed)
	if inv and inv.has_signal("item_used"):
		inv.item_used.connect(_on_inventory_item_used)
	if inv and inv.has_signal("equipment_changed"):
		inv.equipment_changed.connect(_on_inventory_equipment_changed)

# 断开背包事件信号
# @param inv: 背包节点
func disconnect_inventory_signals(inv: Node) -> void:
	if inv and inv.has_signal("item_added"):
		if inv.item_added.is_connected(_on_inventory_item_added):
			inv.item_added.disconnect(_on_inventory_item_added)
	if inv and inv.has_signal("item_removed"):
		if inv.item_removed.is_connected(_on_inventory_item_removed):
			inv.item_removed.disconnect(_on_inventory_item_removed)
	if inv and inv.has_signal("item_used"):
		if inv.item_used.is_connected(_on_inventory_item_used):
			inv.item_used.disconnect(_on_inventory_item_used)
	if inv and inv.has_signal("equipment_changed"):
		if inv.equipment_changed.is_connected(_on_inventory_equipment_changed):
			inv.equipment_changed.disconnect(_on_inventory_equipment_changed)

# ==============================================================================
# 背包事件回调
# ==============================================================================

# 物品添加事件
func _on_inventory_item_added(_item_index: int, _item: Item) -> void:
	refresh_inventory()

# 物品移除事件
func _on_inventory_item_removed(_item_index: int, _item: Item) -> void:
	refresh_inventory()

# 物品使用事件
func _on_inventory_item_used(_item_index: int, _item: Item) -> void:
	refresh_inventory()

# 装备状态改变事件
func _on_inventory_equipment_changed(equipped_item: Item, _equipped_index: int) -> void:
	if equipped_item:
		show_item_mesh(equipped_item)
		update_item_name(equipped_item.名称翻译键)
	else:
		clear_item()
		update_item_name("空手")
