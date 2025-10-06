
# 背包界面主脚本
# 继承自CanvasLayer，确保UI始终显示在最上层
extends CanvasLayer

# 获取UI组件引用
# GridContainer用于放置物品按钮
@onready var grid := $ScrollContainer/GridContainer as GridContainer
# ItemPreviewGUI用于显示选中物品的预览信息
@onready var preview := $PanelContainer/ItemPreviewGUI as ItemPreviewGUI
# 引用已存在的Button作为物品按钮模板
@onready var item_button_template := $ItemButton as Button

@onready var scene_equip_btn := $equipt as Button

# 背包数据引用
var inv: inventory
# 当前选中的物品索引，-1表示未选中任何物品
var _selected_item_index: int = -1

# 设置背包数据并刷新界面
# inventory_node: 背包节点的引用
func set_inventory(inventory_node: inventory):
	inv = inventory_node
	refresh()

# 节点就绪时调用
func _ready():                         
	# 尝试自动找到背包节点
	# 首先获取玩家节点（通过"player"组）
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("inventory"):
		# 如果找到玩家并且玩家有背包组件，则设置背包引用
		set_inventory(player.get_node("inventory"))
	else:
		# 未找到背包时输出警告
		print("警告: 背包界面未找到背包节点，请使用set_inventory手动设置")
	

# 刷新背包界面显示
func refresh():
	# 清空现有的物品按钮
	for c in grid.get_children():
		c.queue_free()
	# 添加安全检查
	if inv == null:
		print("警告: 背包界面的inv变量为null，无法刷新")
		return
	
	# 添加安全检查确保模板按钮存在
	if item_button_template == null:
		print("警告: 物品按钮模板未找到")
		return
	
	# 为每个物品创建可点击的按钮
	for i in range(inv.items.size()):
		var it = inv.items[i]
		if not it:
			continue
		
		# 克隆模板按钮作为物品按钮
		var item_button = item_button_template.duplicate()
		item_button.text = it.name
		
		
		# 设置装备状态的特殊标记
		if it.can_equip:
			if i == inv.equipped_id:
				# 如果物品已装备，添加[装备中]标记
				item_button.text = "[装备中] " + item_button.text
			else:
				# 如果物品可装备但未装备，添加[可装备]标记
				item_button.text = "[可装备] " + item_button.text
		
		# 为选中状态设置特殊样式
		if i == _selected_item_index:
			# 创建选中状态的样式
			var focus_style = StyleBoxFlat.new()
			focus_style.bg_color = Color(0.3, 0.3, 0.5, 0.8)  # 加强的半透明蓝色背景
			focus_style.border_color = Color(1.0, 0.8, 0.0, 1.0)  # 金色高亮边框
			# 设置边框宽度（各边）
			focus_style.border_width_left = 2
			focus_style.border_width_top = 2
			focus_style.border_width_right = 2
			focus_style.border_width_bottom = 2
			# 设置圆角半径
			focus_style.corner_radius_top_left = 4
			focus_style.corner_radius_top_right = 4
			focus_style.corner_radius_bottom_left = 4
			focus_style.corner_radius_bottom_right = 4
			# 应用选中状态样式
			item_button.add_theme_stylebox_override("focus", focus_style)
			# 设置选中状态的文字颜色
			item_button.add_theme_color_override("font_color", Color.YELLOW)
		
		# 连接点击信号
		# 当按钮被点击时，调用_select_item函数选择对应索引的物品
		item_button.pressed.connect(func():
			_select_item(i)
		)
		
		# 将按钮添加到网格容器中
		grid.add_child(item_button)
	
	# 默认选中第一个物品（如果有）
	if inv.items.size() > 0 and _selected_item_index == -1:
		_select_item(0)
		
	# 假设场景里装备按钮路径
	var can_do = inv != null and _selected_item_index != -1
	if can_do:
		var it = inv.items[_selected_item_index]
		can_do = it != null and it.can_equip

	scene_equip_btn.disabled = not can_do
	scene_equip_btn.text = "无法装备" if not can_do else \
			("卸下" if _selected_item_index == inv.equipped_id else "装备")

# 切换物品装备状态（装备/卸下）
# idx: 物品索引
func toggle_equip(idx: int):
	# 添加安全检查
	if inv == null:
		print("警告: 背包界面的inv变量为null，无法装备物品")
		return
	
	if idx < 0 or idx >= inv.items.size():
		print("警告: 无效的物品索引 ", idx)
		return
	
	var it = inv.items[idx]
	if not it:
		print("警告: 物品不存在")
		return
	
	if not it.can_equip:
		print(it.name, " 不可装备")
		return
	
	# 装备逻辑
	if idx == inv.equipped_id:
		# 如果已装备，则卸下
		inv.unequip()
		print("已卸下 ", it.name)
	else:
		# 如果未装备，则装备
		inv.equip(idx)
		print("已装备 ", it.name)
	
	# 刷新界面以显示装备状态变化
	refresh()
	

	
# 选择物品函数
# idx: 要选择的物品索引
func _select_item(idx: int):
	# 安全检查
	if inv == null or idx < 0 or idx >= inv.items.size():
		return
	
	var it = inv.items[idx]
	if not it:
		return
	
	# 更新选中索引
	_selected_item_index = idx
	
	# 更新预览窗口，传递物品信息、索引和装备状态
	var is_equipped = (inv.equipped_id == idx)
	preview.set_item(it, idx, is_equipped)
	
	# 输出选中信息到控制台
	print("已选择物品: ", it.name)
	
	# 刷新显示以更新选中状态的视觉效果
	refresh()


# 处理装备按钮按下事件
# idx: 物品索引
func _on_equipt_pressed() -> void:
	if _selected_item_index == -1:
		print("还没选中任何物品")
		return
	toggle_equip(_selected_item_index)


	
