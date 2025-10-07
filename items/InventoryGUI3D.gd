
# ==============================================================================
# 背包界面主脚本
# 这个脚本负责管理游戏中的背包界面，包括显示物品列表、处理物品选择和装备功能
# ==============================================================================

# 继承自CanvasLayer，确保UI始终显示在最上层
# CanvasLayer是Godot中用于UI的特殊节点，可以独立于游戏世界的相机移动而保持在固定位置
extends CanvasLayer

# ==============================================================================
# UI组件引用
# @onready装饰器表示这些变量会在节点进入场景树后才会被赋值
# ==============================================================================

# GridContainer用于放置物品按钮，这是一个特殊的容器，会自动将子节点排列成网格
@onready var grid := $ScrollContainer/GridContainer as GridContainer

# ItemPreviewGUI用于显示选中物品的预览信息，这是一个自定义的UI组件
@onready var preview := $PanelContainer/ItemPreviewGUI as ItemPreviewGUI

# 引用场景中已存在的Button作为物品按钮模板
# 我们会克隆这个模板来创建每个物品的按钮，而不是从头创建
@onready var item_button_template := $ItemButton as Button

# 装备按钮的引用，用于在界面上控制装备/卸下操作
@onready var scene_equip_btn := $equipt as Button

# ==============================================================================
# 核心变量定义
# ==============================================================================

# 背包数据引用，指向游戏中的背包系统
# inventory是一个自定义类，管理玩家的物品集合
var inv: inventory

# 当前选中的物品索引，-1表示未选中任何物品
# 私有变量约定：以下划线开头的变量通常表示私有变量，仅供内部使用
var _selected_item_index: int = -1

# ==============================================================================
# 公共函数 - 供其他节点调用
# ==============================================================================

# 设置背包数据并刷新界面
# 参数：inventory_node - 背包节点的引用，必须是inventory类型的实例
# 作用：将传入的背包节点赋值给inv变量，并调用refresh()函数更新界面显示
func set_inventory(inventory_node: inventory):
	inv = inventory_node
	refresh()

# ==============================================================================
# 生命周期函数 - Godot引擎自动调用
# ==============================================================================

# 节点就绪时调用
# 当这个节点及其所有子节点都进入场景树后，Godot会自动调用此函数
func _ready():                          
	# 尝试自动找到背包节点
	# get_tree()获取当前场景树，get_first_node_in_group("player")查找标记为"player"组的第一个节点
	var player = get_tree().get_first_node_in_group("player")
	
	# 检查是否找到玩家节点，并且玩家节点有一个名为"inventory"的子节点
	if player and player.has_node("inventory"):
		# 如果找到玩家并且玩家有背包组件，则设置背包引用
		# player.get_node("inventory")获取背包节点的引用
		set_inventory(player.get_node("inventory"))
	else:
		# 未找到背包时输出警告
		# print()函数用于在控制台输出调试信息
		print("警告: 背包界面未找到背包节点，请使用set_inventory手动设置")
	
# ==============================================================================
# 核心功能函数 - 处理背包显示和交互
# ==============================================================================

# 刷新背包界面显示
# 作用：清空当前所有物品按钮，然后根据背包中的物品重新创建新的按钮
func refresh():
	# 清空现有的物品按钮
	# grid.get_children()获取GridContainer中所有的子节点（即所有物品按钮）
	# queue_free()将节点标记为待删除，Godot会在下一帧自动删除它
	for c in grid.get_children():
		c.queue_free()
	
	# 添加安全检查 - 确保背包引用不为空
	# 安全检查非常重要，可以防止程序在数据未准备好时崩溃
	if inv == null:
		print("警告: 背包界面的inv变量为null，无法刷新")
		return
	
	# 添加安全检查确保模板按钮存在
	if item_button_template == null:
		print("警告: 物品按钮模板未找到")
		return
	
	# 为每个物品创建可点击的按钮
	# inv.items.size()获取背包中物品的数量
	# range()函数创建一个从0开始的数字序列
	for i in range(inv.items.size()):
		# 获取当前索引对应的物品
		var item = inv.items[i]
		
		# 如果物品不存在（为null），跳过这个索引
		if not item:
			continue
		
		# 克隆模板按钮作为物品按钮
		# duplicate()函数创建节点的副本
		var item_button = item_button_template.duplicate()
		
		# 设置按钮的文本为物品名称
		item_button.text = item.name_tr_key
		
		# 根据物品类型设置不同的标记
		match item.kind:
			Item.Kind.CONSUMABLE:
				# 对于消耗品，显示效果信息
				item_button.text = "[消耗品] " + item_button.text
			_: # 其他类型物品（装备类）
				if item.kind == Item.Kind.WEAPON:  # 检查物品是否可装备
					if i == inv.equipped_id:  # 检查物品是否已装备
						# 如果物品已装备，添加[装备中]标记到按钮文本
						item_button.text = "[装备中] " + item_button.text
					else:
						# 如果物品可装备但未装备，添加[可装备]标记到按钮文本
						item_button.text = "[可装备] " + item_button.text
		
		# 为选中状态设置特殊样式
		if i == _selected_item_index:  # 检查当前物品是否被选中
			# 创建选中状态的样式
			# StyleBoxFlat是一种可以设置背景色、边框、圆角等属性的样式框
			var focus_style = StyleBoxFlat.new()
			
			# 设置背景色：红、绿、蓝、透明度 (RGB + Alpha)
			# 这里使用深蓝色半透明背景
			focus_style.bg_color = Color(0.3, 0.3, 0.5, 0.8)
			
			# 设置边框颜色为金色
			focus_style.border_color = Color(1.0, 0.8, 0.0, 1.0)
			
			# 应用选中状态样式
			# add_theme_stylebox_override()覆盖按钮特定状态的样式
			item_button.add_theme_stylebox_override("focus", focus_style)
			
			# 设置选中状态的文字颜色为黄色
			item_button.add_theme_color_override("font_color", Color.YELLOW)
		
		# 连接点击信号
		# 信号是Godot中用于节点间通信的机制
		# pressed信号在按钮被按下时发出
		# connect()函数将信号连接到一个回调函数
		item_button.pressed.connect(func():
			# 当按钮被点击时，调用_select_item函数选择对应索引的物品
			# 这里使用闭包函数捕获当前的i值
			_select_item(i)
		)
		
		# 将按钮添加到网格容器中
		# add_child()将新创建的物品按钮添加到GridContainer中
		grid.add_child(item_button)
	
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
		if it:
			# 检查是否为消耗品或可装备物品
			is_consumable = it.kind == Item.Kind.CONSUMABLE
			can_do = is_consumable or it.kind == Item.Kind.WEAPON
		else:
			can_do = false

	# 根据条件设置按钮的可用状态
	scene_equip_btn.disabled = not can_do
	
	# 根据物品类型设置按钮文本
	if not can_do:
		scene_equip_btn.text = "无法使用"
	elif is_consumable:
		scene_equip_btn.text = "使用"
	else:
		# 对于装备类物品，根据装备状态显示不同文本
		scene_equip_btn.text = "卸下" if _selected_item_index == inv.equipped_id else "装备"

# 切换物品装备状态（装备/卸下）
# 参数：idx - 物品索引，表示要操作的物品在背包中的位置
# 作用：处理物品的装备、卸下或使用逻辑
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
	
	# 检查物品是否存在
	if not it:
		print("警告: 物品不存在")
		return
	
	# 处理消耗品类型物品
	if it.kind == Item.Kind.CONSUMABLE:
		# 使用消耗品
		_use_consumable(it, idx)
		return
	
	# 检查装备类物品是否可装备
	if it.kind != Item.Kind.WEAPON:
		print(it.name_tr_key, " 不可装备")
		return
	
	# 装备逻辑（适用于非消耗品）
	if idx == inv.equipped_id:  # 检查物品是否已装备
		# 如果已装备，则卸下
		inv.unequip()  # 调用背包对象的unequip()方法卸下物品
		print("已卸下 ", it.name_tr_key)
	else:
		# 如果未装备，则装备
		inv.equip(idx)  # 调用背包对象的equip()方法装备物品
		print("已装备 ", it.name_tr_key)
	
	# 刷新界面以显示装备状态变化
	refresh()

# 使用消耗品函数
# 参数：
#   - item: 要使用的消耗品物品
#   - idx: 物品在背包中的索引
func _use_consumable(item: Item, idx: int):
	# 查找玩家节点
	var player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("警告: 未找到玩家节点，无法使用消耗品")
		return
	
	# 使用消耗品效果系统
	if item.consumable_effect:
		# 应用消耗品效果
		item.consumable_effect.apply(player)
		print("使用了 ", item.name_tr_key, "，应用了消耗品效果")
	else:
		print("警告: 消耗品 ", item.name_tr_key, " 没有设置效果")
		return
	
	# 以下代码暂时保留，作为备用方案
	# 尝试恢复玩家体力
	if false and player.has_method("restore_stamina_percent"):
		pass  # 空代码块，保持语法正确
		# 调用玩家节点的方法恢复体力
		# 注意：此方法已被consumable_effect系统替代
		# player.restore_stamina_percent(item.stamina_recovery_percent)
		# print("使用了 ", item.name_tr_key, "，恢复了 ", item.stamina_recovery_percent, "% 体力")
		# elif false and player.has_property("current_stamina") and player.has_property("max_stamina"):
		#	# 计算恢复量
		#	var recovery_amount = player.max_stamina * (item.stamina_recovery_percent / 100.0)
		#	# 更新体力值，确保不超过最大值
		#	player.current_stamina = min(player.current_stamina + recovery_amount, player.max_stamina)
		#	# 更新UI
		#	if player.has_property("stamina_ui") and player.stamina_ui and player.stamina_ui.has_method("update_stamina"):
#			player.stamina_ui.update_stamina(player.current_stamina, player.max_stamina)
#	print("使用了 ", item.name_tr_key, "，恢复了 ", item.stamina_recovery_percent, "% 体力")
#	else:
#		print("警告: 玩家节点没有必要的体力相关属性，无法使用消耗品")
#		return
	
	# 从背包中移除已使用的消耗品
	inv.remove_item(idx)
	
	# 更新选中索引 - 如果移除的是当前选中的物品
	if _selected_item_index == idx:
		# 如果背包还有物品，选中最后一个
		if inv.items.size() > 0:
			_selected_item_index = inv.items.size() - 1
		else:
			# 如果没有物品了，设置为-1
			_selected_item_index = -1
	# 如果移除的是前面的物品，需要调整选中索引
	elif _selected_item_index > idx and inv.items.size() > 0:
		_selected_item_index -= 1
	
	# 刷新背包界面
	refresh()

# 选择物品函数
# 参数：idx - 要选择的物品索引
# 作用：选中指定索引的物品，并更新界面显示
func _select_item(idx: int):
	# 安全检查 - 确保所有必要条件都满足
	if inv == null or idx < 0 or idx >= inv.items.size():
		return
	
	# 获取要选择的物品
	var it = inv.items[idx]
	
	# 检查物品是否存在
	if not it:
		return
	
	# 更新选中索引，记录当前选中的物品
	_selected_item_index = idx
	
	# 更新预览窗口，传递物品信息、索引和装备状态
	# 计算物品是否已装备
	var is_equipped = (inv.equipped_id == idx)
	# 调用预览组件的set_item方法显示物品详情
	preview.set_item(it, idx, is_equipped)
	
	# 输出选中信息到控制台，用于调试
	print("已选择物品: ", it.name_tr_key)
	
	# 刷新显示以更新选中状态的视觉效果
	# 这样可以更新选中物品的样式和装备按钮的状态
	refresh()

# ==============================================================================
# 信号处理函数 - 响应UI交互事件
# ==============================================================================

# 处理装备按钮按下事件
# 当场景中的装备按钮被点击时，Godot会自动调用这个函数
func _on_equipt_pressed() -> void:
	# 检查是否有选中的物品
	if _selected_item_index == -1:
		print("还没选中任何物品")
		return
	
	# 如果有选中的物品，调用toggle_equip函数处理装备/卸下操作
	toggle_equip(_selected_item_index)


	
