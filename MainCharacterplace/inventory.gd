extends Node
class_name inventory

# 兼容旧门
var keys: Array[int] = []
func add_key(id: int): 
	if id not in keys:
		keys.append(id)
func has_key(id: int): return id in keys

# 新：3D 道具列表
var items: Array[Item] = []      # 顺序即背包顺序
var equipped_id: int = -1        # 当前装备槽位

func add_item(it: Item):
	if it == null:
		print("警告: 尝试添加空物品到背包")
		return
	items.append(it)
	print("【背包】得到 ", it.name)

func remove_item(idx: int):
	if idx < 0 or idx >= items.size():
		print("警告: 尝试移除无效的物品索引 ", idx)
		return
	if idx == equipped_id: 
		unequip()
	items.remove_at(idx)

func equip(idx: int):
	if idx < 0 or idx >= items.size():
		print("警告: 尝试装备无效的物品索引 ", idx)
		return
	var it = items[idx]
	if not it:
		print("警告: 尝试装备不存在的物品")
		return
	if not it.can_equip:
		print(it.name, " 不可装备")
		return
	unequip()
	equipped_id = idx
	print("已装备 ", it.name)

func unequip():
	if equipped_id >= 0 and equipped_id < items.size() and items[equipped_id]:
		print("卸下 ", items[equipped_id].name)
	equipped_id = -1

func get_equipped_item() -> Item:
	if equipped_id >= 0 and equipped_id < items.size():
		return items[equipped_id]
	return null

func get_item_count() -> int:
	return items.size()
