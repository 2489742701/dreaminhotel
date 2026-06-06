# ==============================================================================
# PlayerManager.gd - 玩家管理器
# 负责管理游戏中的所有玩家实例，提供玩家查找和访问接口
# 优化：支持多人游戏，替代Global.player单例模式
# ==============================================================================

extends Node

# ==============================================================================
# 玩家数据结构
# ==============================================================================

# 玩家信息结构
class PlayerInfo:
	var player_id: int = -1
	var player_node: Node = null
	var is_local: bool = false
	var ui_manager: Node = null

# ==============================================================================
# 玩家存储
# ==============================================================================

# 所有玩家列表
var players: Array[PlayerInfo] = []

# 本地玩家ID
var local_player_id: int = -1

# 下一个可用的玩家ID
var next_player_id: int = 0

# ==============================================================================
# 玩家管理方法
# ==============================================================================

# 添加玩家
# @param player_node: 玩家节点
# @param is_local: 是否为本地玩家
# @return: 分配的玩家ID
func add_player(player_node: Node, is_local: bool = false) -> int:
	var player_info = PlayerInfo.new()
	player_info.player_id = next_player_id
	player_info.player_node = player_node
	player_info.is_local = is_local
	
	players.append(player_info)
	
	# 如果是本地玩家，记录ID
	if is_local:
		local_player_id = next_player_id
	
	var assigned_id = next_player_id
	next_player_id += 1
	
	print("[PlayerManager] 添加玩家 ID:", assigned_id, ", 本地:", is_local)
	return assigned_id

# 移除玩家
# @param player_id: 玩家ID
func remove_player(player_id: int) -> void:
	for i in range(players.size()):
		if players[i].player_id == player_id:
			print("[PlayerManager] 移除玩家 ID:", player_id)
			players.remove_at(i)
			
			# 如果移除的是本地玩家，清除本地玩家ID
			if local_player_id == player_id:
				local_player_id = -1
			
			return
	
	print("[PlayerManager] 警告: 未找到玩家 ID:", player_id)

# 获取玩家节点
# @param player_id: 玩家ID
# @return: 玩家节点，未找到返回null
func get_player(player_id: int) -> Node:
	for player_info in players:
		if player_info.player_id == player_id:
			return player_info.player_node
	
	print("[PlayerManager] 警告: 未找到玩家 ID:", player_id)
	return null

# 获取玩家信息
# @param player_id: 玩家ID
# @return: 玩家信息，未找到返回null
func get_player_info(player_id: int) -> PlayerInfo:
	for player_info in players:
		if player_info.player_id == player_id:
			return player_info
	
	return null

# 获取本地玩家
# @return: 本地玩家节点，未找到返回null
func get_local_player() -> Node:
	if local_player_id >= 0:
		return get_player(local_player_id)
	
	print("[PlayerManager] 警告: 未设置本地玩家")
	return null

# 获取本地玩家ID
# @return: 本地玩家ID，未设置返回-1
func get_local_player_id() -> int:
	return local_player_id

# 设置本地玩家
# @param player_id: 玩家ID
func set_local_player(player_id: int) -> void:
	var player_info = get_player_info(player_id)
	if player_info:
		# 清除之前的本地玩家标记
		for info in players:
			info.is_local = false
		
		# 设置新的本地玩家
		player_info.is_local = true
		local_player_id = player_id
		
		print("[PlayerManager] 设置本地玩家 ID:", player_id)
	else:
		print("[PlayerManager] 警告: 未找到玩家 ID:", player_id)

# 获取所有玩家
# @return: 所有玩家节点列表
func get_all_players() -> Array[Node]:
	var result: Array[Node] = []
	for player_info in players:
		result.append(player_info.player_node)
	return result

# 获取玩家数量
# @return: 玩家总数
func get_player_count() -> int:
	return players.size()

# ==============================================================================
# 玩家UI管理方法
# ==============================================================================

# 设置玩家UI管理器
# @param player_id: 玩家ID
# @param ui_manager: UI管理器
func set_player_ui_manager(player_id: int, ui_manager: Node) -> void:
	var player_info = get_player_info(player_id)
	if player_info:
		player_info.ui_manager = ui_manager
		print("[PlayerManager] 设置玩家 ID:", player_id, " 的UI管理器")
	else:
		print("[PlayerManager] 警告: 未找到玩家 ID:", player_id)

# 获取玩家UI管理器
# @param player_id: 玩家ID
# @return: UI管理器，未找到返回null
func get_player_ui_manager(player_id: int) -> Node:
	var player_info = get_player_info(player_id)
	if player_info:
		return player_info.ui_manager
	
	return null

# 获取本地玩家UI管理器
# @return: 本地玩家UI管理器，未找到返回null
func get_local_player_ui_manager() -> Node:
	if local_player_id >= 0:
		return get_player_ui_manager(local_player_id)
	
	return null

# ==============================================================================
# 便捷访问方法
# ==============================================================================

# 获取本地玩家的背包
# @return: 本地玩家背包节点，未找到返回null
func get_local_player_inventory() -> Node:
	var local_player = get_local_player()
	if local_player and local_player.has_node("inventory"):
		return local_player.get_node("inventory")
	
	return null

# 获取本地玩家的装备物品
# @return: 本地玩家当前装备的物品，未找到返回null
func get_local_player_equipped_item() -> Item:
	var local_player = get_local_player()
	if local_player and local_player.has_method("get_equipped_item"):
		return local_player.get_equipped_item()
	
	return null

# ==============================================================================
# 玩家查找方法
# ==============================================================================

# 通过节点查找玩家ID
# @param player_node: 玩家节点
# @return: 玩家ID，未找到返回-1
func find_player_id(player_node: Node) -> int:
	for player_info in players:
		if player_info.player_node == player_node:
			return player_info.player_id
	
	return -1

# 检查是否为本地玩家
# @param player_node: 玩家节点
# @return: 是否为本地玩家
func is_local_player(player_node: Node) -> bool:
	var player_id = find_player_id(player_node)
	if player_id >= 0:
		var player_info = get_player_info(player_id)
		if player_info:
			return player_info.is_local
	
	return false

# ==============================================================================
# 清理方法
# ==============================================================================

# 清除所有玩家
func clear_all_players() -> void:
	players.clear()
	local_player_id = -1
	next_player_id = 0
	print("[PlayerManager] 清除所有玩家")

# 清除非本地玩家
func clear_remote_players() -> void:
	var i = 0
	while i < players.size():
		if not players[i].is_local:
			players.remove_at(i)
		else:
			i += 1
	
	print("[PlayerManager] 清除远程玩家，剩余玩家数:", players.size())

# ==============================================================================
# 调试方法
# ==============================================================================

# 打印玩家信息
func debug_print_players() -> void:
	print("[PlayerManager] === 玩家列表 ===")
	print("[PlayerManager] 总玩家数:", players.size())
	print("[PlayerManager] 本地玩家ID:", local_player_id)
	
	for player_info in players:
		var local_mark = " [本地]" if player_info.is_local else ""
		print("[PlayerManager]   玩家 ID:", player_info.player_id, local_mark, 
			  ", 节点:", player_info.player_node, 
			  ", UI:", player_info.ui_manager != null)
	
	print("[PlayerManager] ===============")
