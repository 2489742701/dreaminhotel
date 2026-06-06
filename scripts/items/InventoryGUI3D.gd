# ==============================================================================
# InventoryGUI3D.gd
# 物品预览界面控制器
# 功能：管理物品预览界面，调用ItemPreviewGUI显示选中物品
# ==============================================================================
# 继承CanvasLayer确保UI始终显示在最上层，不受3D场景影响
extends CanvasLayer

# ==============================================================================
# UI组件引用
# ==============================================================================

# 物品预览组件 - 显示当前选中物品的详细信息
@onready var preview := $ItemPreviewGUI as ItemPreviewGUI

# ==============================================================================
# 核心变量定义
# ==============================================================================

# 背包数据引用
var inv: inventory

# ==============================================================================
# 公共函数
# ==============================================================================

# 设置背包数据
func set_inventory(inventory_node: inventory):
	inv = inventory_node
	# 将背包数据传递给预览组件
	if preview:
		preview.set_inventory(inventory_node)

# 设置要显示的物品
func set_item(item: Item, item_index: int = -1, _is_equipped: bool = false):
	if preview:
		preview.set_item(item, item_index)

# 刷新背包显示
func refresh():
	# 确保预览组件存在
	if not preview:
		print("警告: 预览组件不存在，无法刷新背包显示")
		return
	
	# 如果背包中有物品，刷新整个物品列表
	if inv and inv.items and inv.items.size() > 0:
		# 调用预览组件的刷新方法，显示所有物品
		preview._refresh_item_list()
		print("刷新背包显示，物品数量: ", inv.items.size())
	else:
		# 如果没有物品，清空显示
		preview.set_item(null)
		print("背包为空，清空物品预览")

# 添加测试物品到背包
func add_test_items():
	if not inv:
		print("InventoryGUI3D: 背包未连接，无法添加测试物品")
		return
	
	# 尝试创建一些测试物品
	print("InventoryGUI3D: 尝试添加测试物品...")
	
	# 检查是否有Item类定义
	if not ClassDB.class_exists("Item"):
		print("InventoryGUI3D: Item类未定义，无法创建测试物品")
		return
	
	# 创建一些简单的测试物品
	var test_item = Item.new()
	test_item.名称翻译键 = "测试物品"
	
	# 尝试添加物品
	inv.add_item(test_item)
	print("InventoryGUI3D: 添加测试物品完成，当前物品数量: ", inv.items.size())
	
	# 刷新显示
	refresh()

# ==============================================================================
# 生命周期函数
# ==============================================================================

# 节点就绪回调函数
func _ready() -> void:
	# 添加到inventory_gui组
	add_to_group("inventory_gui")
	
	# 尝试多种方式获取背包数据
	var inventory_node = _find_inventory()
	if inventory_node:
		set_inventory(inventory_node)
		print("InventoryGUI3D: 成功连接到背包，包含物品数量: ", inventory_node.items.size())
	else:
		print("警告: 背包界面未找到背包节点，请使用set_inventory手动设置")

# 查找背包节点的辅助函数
func _find_inventory() -> inventory:
	# 方法1: 从父节点查找
	if get_parent() and get_parent().has_node("inventory"):
		return get_parent().get_node("inventory") as inventory
	
	# 方法2: 从全局查找
	if Engine.has_singleton("Global") and Engine.get_singleton("Global").has_method("get_player_inventory"):
		return Engine.get_singleton("Global").get_player_inventory()
	
	# 方法3: 从场景树中查找
	var inventory_nodes = get_tree().get_nodes_in_group("inventory")
	if inventory_nodes.size() > 0:
		return inventory_nodes[0] as inventory
	
	# 方法4: 从玩家节点查找
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		var player = player_nodes[0]
		if player.has_node("inventory"):
			return player.get_node("inventory") as inventory
	
	return null
