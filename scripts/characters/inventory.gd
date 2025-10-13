# ==============================================================================
# inventory.gd - 背包系统核心类
# 负责管理游戏中的物品、钥匙和装备系统，提供物品的添加、移除、装备和查询功能
# 适用于初学者：理解背包系统是游戏开发中的重要部分，它管理玩家获取和使用的所有物品
# ==============================================================================

# 扩展自Node类，表示这是一个基本的场景节点
extends Node
# 定义类名为inventory，使其他脚本可以直接引用此类
class_name inventory

# ========== 钥匙管理系统 ==========

# 存储玩家拥有的钥匙ID列表
# 这个数组用于快速检查玩家是否拥有特定门所需的钥匙
var keys: Array[int] = []

# 添加钥匙到背包
# @param id: 钥匙的唯一标识ID
# 初学者提示：这个方法确保玩家不会重复获得相同的钥匙
func add_key(id: int): 
	# 检查钥匙是否已存在，避免重复添加
	# 这样可以防止钥匙列表中出现重复的ID
	if id not in keys:
		# 将新钥匙添加到钥匙列表
		keys.append(id)

# 检查玩家是否拥有指定ID的钥匙
# @param id: 要检查的钥匙ID
# @return: 如果拥有该钥匙返回true，否则返回false
# 初学者提示：这个方法在游戏中的门、箱子等需要钥匙的地方会被频繁调用
func has_key(id: int): 
	# 简单直接地检查钥匙ID是否在玩家的钥匙列表中
	return id in keys

# ========== 物品管理系统 ==========

# 存储玩家背包中的所有物品项，每个项包含物品和物品状态
# items是一个数组，其中每个元素是一个字典，包含item(物品本身)和state(物品状态)
# 这种结构允许我们同时存储物品数据和物品的使用状态、堆叠数量等信息
var items: Array[Dictionary] = []

# 当前装备的物品索引，-1表示没有装备任何物品
# 使用索引而不是直接引用物品，这样在物品被移除后不会出现悬空引用
var equipped_id: int = -1

# ========== 物品操作方法 ==========

# 向背包添加物品
# @param it: 要添加的物品对象，必须是Item类型
# @param state: 物品状态对象，可选参数
# 初学者提示：添加物品是游戏中最基础的交互之一
func add_item(it: Item, state: RefCounted = null):
	# 安全检查：确保物品不为空
	# 永远不要信任传入的参数，始终进行安全检查
	if it == null:
		print("警告: 尝试添加空物品到背包")
		return
	
	# 创建物品项字典
	# 使用字典存储物品和它的状态信息
	var item_entry = {}
	item_entry.item = it
	
	# 如果没有提供状态，创建默认状态
	if state == null:
		# 尝试创建ItemState对象
		# 这里使用了Engine.has_singleton来检查是否有ItemState单例
		if Engine.has_singleton("ItemState"):
			item_entry.state = Engine.get_singleton("ItemState").new()
		else:
			# 创建简单的状态字典作为备选
			# 使用字典作为后备方案确保代码在任何情况下都能工作
			item_entry.state = {"stack_count": 1}  # stack_count表示物品堆叠数量
	else:
		item_entry.state = state
	
	items.append(item_entry)
	# 输出调试信息
	print("【背包】得到 ", it.name_tr_key)
	
	# 自动处理钥匙类型物品
	if it.kind == Item.Kind.KEY and it.key_id != -1:
		add_key(it.key_id)

# 从背包移除物品
# @param idx: 要移除的物品索引
# 初学者提示：移除物品时需要处理各种边缘情况，比如移除当前装备的物品
func remove_item(idx: int):
	# 安全检查：确保索引有效
	# 索引必须在0到items.size()-1之间才有效
	if idx < 0 or idx >= items.size():
		print("警告: 尝试移除无效的物品索引 ", idx)
		return
	# 如果要移除的是当前装备的物品，先卸下该物品
	# 这是一个重要的处理，确保玩家不会继续持有已经移除的装备
	if idx == equipped_id: 
		unequip()
	# 从物品列表中移除指定索引的物品
	items.remove_at(idx)
	# 如果装备的物品索引大于移除的索引，需要调整
	# 这是因为数组移除元素后，后面的元素会前移，所以索引需要更新
	if equipped_id > idx:
		equipped_id -= 1

# ========== 装备系统 ==========

# 装备指定索引的物品
# @param idx: 要装备的物品索引
# 初学者提示：装备系统需要处理多种边界情况，比如物品是否可装备
func equip(idx: int):
	# 安全检查：确保索引有效
	if idx < 0 or idx >= items.size():
		print("警告: 尝试装备无效的物品索引 ", idx)
		return
	
	# 获取要装备的物品
	# 修正：从items数组获取物品项，再获取其中的item属性
	var entry = items[idx]
	var it = entry.item
	
	# 安全检查：确保物品存在
	if not it:
		print("警告: 尝试装备不存在的物品")
		return
	
	# 检查物品是否可以装备（仅武器类型可装备）
	# 在这个游戏中，只有WEAPON类型的物品可以被装备
	if it.kind != Item.Kind.WEAPON:
		print(it.name_tr_key, " 不可装备")
		return
	
	# 先卸下当前装备的物品
	# 确保玩家同一时间只能装备一件物品
	unequip()	
	# 设置新装备的物品索引
	equipped_id = idx
	
	# 输出调试信息
	print("已装备 ", it.name_tr_key)

# 卸下当前装备的物品
# 初学者提示：这个方法重置装备状态，不依赖于任何参数
func unequip():
	# 如果当前有装备的物品且索引有效
	# 先检查装备索引是否有效，再检查对应的物品是否存在
	if equipped_id >= 0 and equipped_id < items.size() and items[equipped_id]:
		# 输出调试信息
		print("卸下 ", items[equipped_id].item.name_tr_key)
	# 重置装备索引，表示没有装备任何物品
	# 使用-1作为特殊值表示"未装备任何物品"
	equipped_id = -1

# ========== 查询方法 ==========

# 获取当前装备的物品
# @return: 当前装备的物品对象，如果没有装备物品则返回null
# 初学者提示：这种查询方法在游戏中很常用，比如攻击时需要知道玩家装备了什么武器
func get_equipped_item() -> Item:
	# 检查装备索引是否有效
	if equipped_id >= 0 and equipped_id < items.size():
		# 返回装备的物品
		return items[equipped_id].item
	# 如果没有装备物品，返回null
	return null

# 获取背包中的物品总数
# @return: 背包中的物品数量
# 初学者提示：简单但实用的方法，用于UI显示和限制检查
func get_item_count() -> int:
	return items.size()

# 使用物品
# @param idx: 要使用的物品索引
# @description: 消耗品系统的核心方法，处理物品使用、效果应用和物品数量管理
# @description: 支持不同类型的状态对象（RefCounted或Dictionary），并根据物品数量决定是否移除物品
func use_item(idx: int) -> void:
	# 安全检查：确保索引有效
	if idx < 0 or idx >= items.size():
		print("警告: 尝试使用无效的物品索引 ", idx)
		return
	
	var entry = items[idx]
	var item: Item = entry.item
	var state = entry.state
	
	# 检查物品类型是否为消耗品
	if item.kind != Item.Kind.CONSUMABLE:
		print("无法使用非消耗品物品: ", item.name_tr_key)
		return
	
	# 获取消耗品效果
	var effect: ConsumableEffect = item.consumable_effect
	if effect:
		# 应用效果到玩家
		# Global.player是一个全局访问点，指向玩家节点
		if Global.player:
			# 调用效果的apply方法，将玩家节点作为目标
			effect.apply(Global.player)
			print("使用了 ", item.name_tr_key)
			
			# 减少物品数量 - 处理不同类型的状态对象
			# 支持两种状态对象类型：RefCounted和Dictionary
			if state is RefCounted and state.has_method("stack_count"):
				# 如果状态是RefCounted对象且有stack_count方法
				state.stack_count -= 1
				# 如果数量减至0或更少，移除物品
				if state.stack_count <= 0:
					items.remove_at(idx)
			elif state is Dictionary and "stack_count" in state:
				# 如果状态是字典且包含stack_count键
				state.stack_count -= 1
				# 如果数量减至0或更少，移除物品
				if state.stack_count <= 0:
					items.remove_at(idx)
			else:
				# 如果没有找到数量属性，直接移除物品
				# 这是一个回退机制，确保物品总是会被正确消耗
				items.remove_at(idx)
		else:
			# 如果找不到玩家节点，输出警告
			print("警告: 无法找到玩家节点，无法应用消耗品效果")
	else:
		# 如果消耗品没有设置效果，输出警告
		print("警告: 消耗品没有设置效果: ", item.name_tr_key)
