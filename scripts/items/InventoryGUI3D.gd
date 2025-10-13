
# ==============================================================================
# InventoryGUI3D.gd
# 背包界面主控制器
# 功能：管理游戏背包界面，处理物品列表显示、选择、装备和使用操作
# 优化：采用批量隐藏-修改-显示策略避免O(n²)级别的实时布局重排
# 作者：[开发者姓名]
# ==============================================================================
# 继承CanvasLayer确保UI始终显示在最上层，不受3D场景影响
# CanvasLayer是Godot中一种特殊的节点类型，允许UI元素覆盖在3D场景之上
extends CanvasLayer

# ==============================================================================
# UI组件引用
# @onready装饰器：这些变量会在节点进入场景树后才会被赋值，避免空引用错误
# 类型注解：使用as关键字显式声明变量类型，提高代码可读性和IDE支持
# ==============================================================================

# 物品网格容器 - 自动排列物品按钮为网格布局
@onready var grid := $ScrollContainer/GridContainer as GridContainer

# 物品预览组件 - 显示当前选中物品的详细信息
@onready var preview := $PanelContainer/ItemPreviewGUI as ItemPreviewGUI

# 物品按钮模板 - 作为克隆源，避免重复创建UI元素
@onready var item_button_template := $ItemButton as Button

# 装备操作按钮 - 用于触发物品的装备/卸下操作
@onready var scene_equip_btn := $equipt as Button

# ==============================================================================
# 核心变量定义
# 变量命名规则：以下划线(_)开头的变量视为私有变量，仅供内部使用
# ==============================================================================

# 背包数据引用 - 连接UI和后端数据的桥梁
# inventory是一个自定义类，负责管理玩家的物品集合和相关逻辑
var inv: inventory

# 当前选中的物品索引
# -1表示未选中任何物品
var _selected_item_index: int = -1

# 物品按钮缓存字典
# 索引 -> 按钮对象映射，避免重复创建和查找
var _item_buttons: Dictionary = {}

# ==============================================================================
# 公共函数 - 供其他节点调用的接口函数
# ==============================================================================

# 设置背包数据并刷新界面
# @param inventory_node: 背包节点的引用，必须是inventory类型的实例
# @description: 连接UI与背包数据系统，并触发界面初始刷新
func set_inventory(inventory_node: inventory):
	inv = inventory_node
	refresh()  # 初始刷新界面显示

# ==============================================================================
# 生命周期函数 - Godot引擎自动调用的函数
# ==============================================================================

# 节点就绪回调函数
# @description: 当节点及其所有子节点都进入场景树后，Godot会自动调用此函数
# @description: 主要职责是初始化状态和连接数据
func _ready() -> void:                          
	# 添加到inventory_gui组 - 提供全局访问点，使其他节点可轻松找到此UI
	add_to_group("inventory_gui")
	
	# 自动连接背包数据的容错逻辑
	# 尝试从Global单例获取玩家节点，并查找其inventory子节点
	if Global.player and Global.player.has_node("inventory"):
		set_inventory(Global.player.get_node("inventory"))
	else:
		# 日志警告 - 方便调试和故障排查
		print("警告: 背包界面未找到背包节点，请使用set_inventory手动设置")
	
# ==============================================================================
# 核心功能函数 - 处理背包显示和交互逻辑
# ==============================================================================

# 刷新背包界面显示
# @description: 性能优化版本 - 使用批量隐藏-修改-显示策略避免O(n²)布局重排
# @description: 复用已存在的按钮组件，减少内存分配和节点创建开销
func refresh():
	# 添加安全检查 - 确保背包引用不为空
	if inv == null:
		print("警告: 背包界面的inv变量为null，无法刷新")
		return
	
	# 添加安全检查确保模板按钮存在
	if item_button_template == null:
		print("警告: 物品按钮模板未找到")
		return
	
	# 第一步：批量隐藏所有现有按钮，避免每添加一个就触发重排
	for button in _item_buttons.values():
		if is_instance_valid(button):
			button.set_deferred("visible", false)
	
	# 第二步：批量创建/更新按钮
	for i in range(inv.items.size()):
		# 获取当前索引对应的物品
		var item = inv.items[i]
		
		# 如果物品不存在（为null），跳过这个索引
		if not item:
			continue
		
		# 获取或创建按钮
		var item_button = _item_buttons.get(i)
		if not is_instance_valid(item_button):
			# 克隆模板按钮作为物品按钮
			item_button = item_button_template.duplicate()
			# 连接点击信号
			item_button.pressed.connect(func(index = i):
				# 使用默认参数捕获索引，避免闭包问题
				_select_item(index)
			)
			# 存储按钮引用
			_item_buttons[i] = item_button
			# 将按钮添加到网格容器（只在首次创建时添加）
			grid.add_child(item_button)
		
		# 设置按钮属性
		var name_key = item.item.name_tr_key
		item_button.text = tr(name_key) if name_key else "???"
		
		# 根据物品类型设置不同的标记
		match item.item.kind:
			Item.Kind.CONSUMABLE:
				item_button.text = tr("PREFIX_CONSUMABLE") + " " + item_button.text
			
			Item.Kind.WEAPON:
				if i == inv.equipped_id:
					item_button.text = tr("PREFIX_EQUIPPED") + " " + item_button.text
				else:
					item_button.text = tr("PREFIX_EQUIPPABLE") + " " + item_button.text
			_:
				# 其他装备想加前缀再补match分支即可
				pass
		
		# 为选中状态设置特殊样式
		if i == _selected_item_index:
			var focus_style = StyleBoxFlat.new()
			focus_style.bg_color = Color(0.3, 0.3, 0.5, 0.8)
			focus_style.border_color = Color(1.0, 0.8, 0.0, 1.0)
			item_button.add_theme_stylebox_override("focus", focus_style)
			item_button.add_theme_color_override("font_color", Color.YELLOW)
		else:
			# 重置未选中状态的样式
			item_button.remove_theme_stylebox_override("focus")
			item_button.remove_theme_color_override("font_color")
	
	# 清理多余的按钮
	var keys_to_remove = []
	for idx in _item_buttons.keys():
		if idx >= inv.items.size():
			keys_to_remove.append(idx)
			var button = _item_buttons[idx]
			if is_instance_valid(button):
				button.queue_free()
	for idx in keys_to_remove:
		_item_buttons.erase(idx)
	
	# 第三步：批量显示按钮，一次触发布局
	for button in _item_buttons.values():
		if is_instance_valid(button):
			button.set_deferred("visible", true)
	
	# 默认选中第一个物品（如果有）
	if inv.items.size() > 0 and _selected_item_index == -1:
		_select_item(0)
		
	# 更新操作按钮的状态
	var can_do = inv != null and _selected_item_index != -1 and _selected_item_index < inv.items.size()
	var is_consumable = false
	var it = null
	
	# 如果条件满足，检查物品类型和状态
	if can_do:
		it = inv.items[_selected_item_index]
		if it and it.has("item"):
			# 检查是否为消耗品或可装备物品
			is_consumable = it.item.kind == Item.Kind.CONSUMABLE
			can_do = is_consumable or it.item.kind == Item.Kind.WEAPON
		else:
			can_do = false

	# 根据条件设置按钮的可用状态
	scene_equip_btn.disabled = not can_do
	
	# 根据物品类型设置按钮文本
	if not can_do:
		scene_equip_btn.text = tr("BUTTON_CANNOT_USE")
	elif is_consumable:
		scene_equip_btn.text = tr("BUTTON_USE")
	else:
		# 对于装备类物品，根据装备状态显示不同文本
		scene_equip_btn.text = _equip_text(_selected_item_index)

# 切换物品装备状态（装备/卸下）
# @param idx: 物品在背包中的索引位置
# @description: 处理物品的装备、卸下或使用逻辑，根据物品类型执行不同操作
# @description: 执行操作后会自动刷新界面显示新状态
func toggle_equip(idx: int):
	# 添加安全检查 - 确保背包引用不为空
	if inv == null:
		print("警告: 背包界面的inv变量为null，无法操作物品")
		return
	
	# 检查物品索引是否有效
	if idx < 0 or idx >= inv.items.size():
		print("警告: 无效的物品索引 ", idx)
		return
	
	# 获取要操作的物品
	var it = inv.items[idx]
	
	# 检查物品是否存在且包含item字段
	if not it or not it.has("item"):
		print("警告: 物品不存在或格式不正确")
		return
	
	# 处理消耗品类型物品
	if it.item.kind == Item.Kind.CONSUMABLE:
		# 使用消耗品 - 调用背包系统的use_item方法
		inv.use_item(idx)
		return
	
	# 检查装备类物品是否可装备
	if it.item.kind != Item.Kind.WEAPON:
		print(it.item.name_tr_key, " 不可装备")
		return
	
	# 装备逻辑（适用于非消耗品）
	if idx == inv.equipped_id:  # 检查物品是否已装备
		# 如果已装备，则卸下
		inv.unequip()  # 调用背包对象的unequip()方法卸下物品
		print("已卸下 ", it.item.name_tr_key)
	else:
		# 如果未装备，则装备
		inv.equip(idx)  # 调用背包对象的equip()方法装备物品
		print("已装备 ", it.item.name_tr_key)
	
	# 刷新界面以显示装备状态变化
	refresh()

# 装备文本辅助函数
# @param idx: 物品索引
# @return: 根据物品是否已装备返回对应的翻译文本
# @description: 封装装备按钮文本的逻辑，便于维护和修改
func _equip_text(idx: int) -> String:
	return tr("BUTTON_UNEQUIP") if idx == inv.equipped_id else tr("BUTTON_EQUIP")

# 选择物品函数
# @param idx: 要选择的物品索引
# @description: 选中指定索引的物品，更新预览窗口和界面状态
# @description: 包含多层安全检查，防止无效索引或空引用
func _select_item(idx: int):
	# 安全检查 - 确保所有必要条件都满足
	if inv == null or idx < 0 or idx >= inv.items.size():
		return
	
	# 获取要选择的物品
	var it = inv.items[idx]
	
	# 检查物品是否存在
	if not it or not it.has("item"):
		return
	
	# 更新选中索引，记录当前选中的物品
	_selected_item_index = idx
	
	# 更新预览窗口，传递物品信息、索引和装备状态
	# 计算物品是否已装备
	var is_equipped = (inv.equipped_id == idx)
	# 调用预览组件的set_item方法显示物品详情
	preview.set_item(it.item, idx, is_equipped)
	
	# 输出选中信息到控制台，用于调试
	print("已选择物品: ", it.item.name_tr_key)
	
	# 刷新显示以更新选中状态的视觉效果
	# 这样可以更新选中物品的样式和装备按钮的状态
	refresh()

# ==============================================================================
# 信号处理函数 - 响应UI交互事件，这些函数通过编辑器连接到对应UI组件的信号
# ==============================================================================

# 处理装备按钮按下事件
# @description: 当界面上的装备按钮被点击时触发
# @description: 是UI交互到游戏逻辑的桥梁
func _on_equipt_pressed() -> void:
	# 检查是否有选中的物品
	if _selected_item_index == -1:
		print("还没选中任何物品")
		return
	
	# 如果有选中的物品，调用toggle_equip函数处理装备/卸下操作
	toggle_equip(_selected_item_index)

# 处理使用按钮按下事件
# @description: 当界面上的使用按钮被点击时触发
# @description: 主要用于消耗品类型的物品
func _on_use_button_pressed() -> void:
	# 安全检查 - 确保有选中的有效物品
	if _selected_item_index < 0:
		return
	# 委托给背包系统处理具体的使用逻辑
	inv.use_item(_selected_item_index)
	# 操作完成后刷新界面，显示物品数量变化或移除
	refresh()


	
