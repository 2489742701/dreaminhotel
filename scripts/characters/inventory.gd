# ==============================================================================
# inventory.gd - 背包系统核心类
# 负责管理游戏中的物品、钥匙和装备系统，提供物品的添加、移除、装备和查询功能
# 适用于初学者：理解背包系统是游戏开发中的重要部分，它管理玩家获取和使用的所有物品
# ==============================================================================

# 扩展自Node类，表示这是一个基本的场景节点
extends Node
# 定义类名为inventory，使其他脚本可以直接引用此类
class_name inventory

# ========== 事件信号系统 ==========

# 物品被添加的信号
signal item_added(item_index: int, item: Item)
# 物品被移除的信号
signal item_removed(item_index: int, item: Item)
# 物品被使用的信号
signal item_used(item_index: int, item: Item)
# 装备状态改变的信号
signal equipment_changed(equipped_item: Item, equipped_index: int)

# ========== 拥有者玩家系统 ==========

# 拥有此背包的玩家节点
var owner_player: Node = null

# 设置拥有者玩家
# @param player: 玩家节点
func set_owner_player(player: Node) -> void:
	owner_player = player

# 获取拥有者玩家
# @return: 玩家节点
func get_owner_player() -> Node:
	return owner_player

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
# 优化：统一使用Dictionary类型，简化序列化和维护
func add_item(it: Item, state: Dictionary = {}):
	# 安全检查：确保物品不为空
	if it == null:
		print("警告: 尝试添加空物品到背包")
		return
	
	# 创建物品项字典
	var item_entry = {}
	item_entry.item = it
	
	# 标准化状态对象：统一使用Dictionary
	if state.is_empty():
		# 创建标准化的状态字典
		item_entry.state = {
			"stack_count": 1,  # 物品堆叠数量
			"created_time": Time.get_unix_time_from_system()  # 添加时间戳便于管理
		}
	else:
		# 确保提供的状态字典包含必要字段
		if not "stack_count" in state:
			state.stack_count = 1
		if not "created_time" in state:
			state.created_time = Time.get_unix_time_from_system()
		item_entry.state = state
	
	items.append(item_entry)
	print("【背包】得到 ", it.名称翻译键)
	
	# 发出物品添加信号
	item_added.emit(items.size() - 1, it)
	
	# 自动处理钥匙类型物品
	if it.物品类型 == Item.Kind.KEY and it.钥匙ID != -1:
		add_key(it.钥匙ID)

# 从背包移除物品
# @param idx: 要移除的物品索引
# 初学者提示：移除物品时需要处理各种边缘情况，比如移除当前装备的物品
func remove_item(idx: int):
	# 安全检查：确保索引有效
	# 索引必须在0到items.size()-1之间才有效
	if idx < 0 or idx >= items.size():
		print("警告: 尝试移除无效的物品索引 ", idx)
		return
	
	# 获取要移除的物品信息用于事件通知
	var removed_item = items[idx].item if items[idx] and items[idx].has("item") else null
	
	# 如果要移除的是当前装备的物品，先卸下该物品
	# 这是一个重要的处理，确保玩家不会继续持有已经移除的装备
	if idx == equipped_id: 
		unequip()
	
	# 从物品列表中移除指定索引的物品
	items.remove_at(idx)
	
	# 发送物品移除事件
	item_removed.emit(idx, removed_item)
	
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
	
	# 现在所有物品都可以装备，移除类型限制
	# 允许所有类型的物品被装备
	
	# 先卸下当前装备的物品
	# 确保玩家同一时间只能装备一件物品
	unequip()	
	# 设置新装备的物品索引
	equipped_id = idx
	
	# 输出调试信息
	print("已装备 ", it.名称翻译键)
	
	# 发送装备状态改变事件
	equipment_changed.emit(it, idx)

# 卸下当前装备的物品
# 初学者提示：这个方法重置装备状态，不依赖于任何参数
func unequip():
	# 获取当前装备的物品信息用于事件通知
	var unequipped_item = null
	if equipped_id >= 0 and equipped_id < items.size() and items[equipped_id]:
		unequipped_item = items[equipped_id].item
		# 输出调试信息
		print("卸下 ", unequipped_item.名称翻译键)
	# 重置装备索引，表示没有装备任何物品
	# 使用-1作为特殊值表示"未装备任何物品"
	equipped_id = -1
	
	# 发送装备状态改变事件（卸下）
	equipment_changed.emit(null, -1)

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
	if item.物品类型 != Item.Kind.CONSUMABLE:
		print("无法使用非消耗品物品: ", item.名称翻译键)
		return
	
	# 获取消耗品效果
	var effect: ConsumableEffect = item.消耗品效果
	if effect:
		# 应用效果到拥有者玩家
		# 优先使用owner_player，如果没有则使用Global.player（向后兼容）
		var target_player = owner_player if owner_player else Global.player
		if target_player:
			# 调用效果的apply方法，将玩家节点作为目标
			effect.apply(target_player)
			print("使用了 ", item.名称翻译键)
			
			# 发送物品使用事件
			item_used.emit(idx, item)
			
			# 处理分次饮用逻辑
			if "可饮用次数" in item and item.可饮用次数 > 0:
				# 如果物品支持分次饮用，减少饮用次数
				item.可饮用次数 -= 1
				print("使用了 ", item.名称翻译键, " 剩余饮用次数: ", item.可饮用次数)
				
				# 如果饮用次数为0或更少，移除物品
				if item.可饮用次数 <= 0:
					items.remove_at(idx)
					print("物品已喝完，从背包中移除")
					# 发送物品移除事件
					item_removed.emit(idx, item)
			else:
				# 传统消耗品逻辑：减少物品数量
				# 支持两种状态对象类型：RefCounted和Dictionary
				if state is RefCounted and state.has_method("stack_count"):
					# 如果状态是RefCounted对象且有stack_count方法
					state.stack_count -= 1
					# 如果数量减至0或更少，移除物品
					if state.stack_count <= 0:
						items.remove_at(idx)
						# 发送物品移除事件
						item_removed.emit(idx, item)
				elif state is Dictionary and "stack_count" in state:
					# 如果状态是字典且包含stack_count键
					state.stack_count -= 1
					# 如果数量减至0或更少，移除物品
					if state.stack_count <= 0:
						items.remove_at(idx)
						# 发送物品移除事件
						item_removed.emit(idx, item)
				else:
					# 如果没有找到数量属性，直接移除物品
					# 这是一个回退机制，确保物品总是会被正确消耗
					items.remove_at(idx)
					# 发送物品移除事件
					item_removed.emit(idx, item)
		else:
			# 如果找不到玩家节点，输出警告
			print("警告: 无法找到玩家节点，无法应用消耗品效果")
	else:
		# 如果消耗品没有设置效果，输出警告
		print("警告: 消耗品没有设置效果: ", item.名称翻译键)
