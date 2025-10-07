# ==============================================================================
# inventory.gd - 背包系统核心类
# 负责管理游戏中的物品、钥匙和装备系统，提供物品的添加、移除、装备和查询功能
# ==============================================================================

# 扩展自Node类，表示这是一个基本的场景节点
extends Node
# 定义类名为inventory，方便在其他脚本中引用
class_name inventory

# ========== 钥匙管理系统 ==========

# 存储玩家拥有的钥匙ID列表
var keys: Array[int] = []

# 添加钥匙到背包
# @param id: 钥匙的唯一标识ID
func add_key(id: int): 
	# 检查钥匙是否已存在，避免重复添加
	if id not in keys:
		# 将新钥匙添加到钥匙列表
		keys.append(id)

# 检查玩家是否拥有指定ID的钥匙
# @param id: 要检查的钥匙ID
# @return: 如果拥有该钥匙返回true，否则返回false
func has_key(id: int): 
	return id in keys

# ========== 物品管理系统 ==========

# 存储玩家背包中的所有物品，顺序即为游戏中显示的顺序
var items: Array[Item] = []

# 当前装备的物品索引，-1表示没有装备任何物品
var equipped_id: int = -1

# ========== 物品操作方法 ==========

# 向背包添加物品
# @param it: 要添加的物品对象
func add_item(it: Item):
	# 安全检查：确保物品不为空
	if it == null:
		print("警告: 尝试添加空物品到背包")
		return
	# 将物品添加到物品列表
	items.append(it)
	# 输出调试信息
	print("【背包】得到 ", it.name_tr_key)

# 从背包移除物品
# @param idx: 要移除的物品索引
func remove_item(idx: int):
	# 安全检查：确保索引有效
	if idx < 0 or idx >= items.size():
		print("警告: 尝试移除无效的物品索引 ", idx)
		return
	# 如果要移除的是当前装备的物品，先卸下该物品
	if idx == equipped_id: 
		unequip()
	# 从物品列表中移除指定索引的物品
	items.remove_at(idx)

# ========== 装备系统 ==========

# 装备指定索引的物品
# @param idx: 要装备的物品索引
func equip(idx: int):
	# 安全检查：确保索引有效
	if idx < 0 or idx >= items.size():
		print("警告: 尝试装备无效的物品索引 ", idx)
		return
	
	# 获取要装备的物品
	var it = items[idx]
	
	# 安全检查：确保物品存在
	if not it:
		print("警告: 尝试装备不存在的物品")
		return
	
	# 检查物品是否可以装备（仅武器类型可装备）
	if it.kind != Item.Kind.WEAPON:
		print(it.name_tr_key, " 不可装备")
		return
	
	# 先卸下当前装备的物品
	unequip()
	
	# 设置新装备的物品索引
	equipped_id = idx
	
	# 输出调试信息
	print("已装备 ", it.name_tr_key)

# 卸下当前装备的物品
func unequip():
	# 如果当前有装备的物品且索引有效
	if equipped_id >= 0 and equipped_id < items.size() and items[equipped_id]:
		# 输出调试信息
		print("卸下 ", items[equipped_id].name_tr_key)
	# 重置装备索引，表示没有装备任何物品
	equipped_id = -1

# ========== 查询方法 ==========

# 获取当前装备的物品
# @return: 当前装备的物品对象，如果没有装备物品则返回null
func get_equipped_item() -> Item:
	# 检查装备索引是否有效
	if equipped_id >= 0 and equipped_id < items.size():
		# 返回装备的物品
		return items[equipped_id]
	# 如果没有装备物品，返回null
	return null

# 获取背包中的物品总数
# @return: 背包中的物品数量
func get_item_count() -> int:
	return items.size()
