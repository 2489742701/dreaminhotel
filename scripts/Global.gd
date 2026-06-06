# ==============================================================================
# Global.gd - 全局变量和功能管理类
# 作为Godot自动加载的单例，提供游戏中需要全局访问的变量和方法
# 优化：移除player单例，使用PlayerManager支持多人游戏
# ==============================================================================

# 扩展自Node类，表示这是一个基本的场景节点
extends Node

# 全局调试开关
var debug_mode: bool = true

# 玩家管理器（替代原来的player单例）
var player_manager: Node = null

# 全局UI引用，用于访问UI组件（已废弃，使用PlayerUIManager）
var ui: Control = null

# _ready方法在节点进入场景树时自动调用
func _ready() -> void:
	# 使用autoload单例作为玩家管理器
	player_manager = PlayerManagerSingleton
	
	# 尝试自动查找玩家节点（向后兼容）
	var found_player = get_tree().get_first_node_in_group("player")
	if found_player:
		print("[Global] 自动找到玩家节点，已添加到PlayerManager")
		player_manager.add_player(found_player, true)
	else:
		print("[Global] 警告: 未找到player组的节点")

# ==============================================================================
# 便捷访问方法
# ==============================================================================

# 获取本地玩家
# @return: 本地玩家节点，未找到返回null
# @deprecated: 建议使用player_manager.get_local_player()
func get_local_player() -> Node:
	return player_manager.get_local_player()

# 获取玩家
# @param player_id: 玩家ID
# @return: 玩家节点，未找到返回null
# @deprecated: 建议使用player_manager.get_player(player_id)
func get_player(player_id: int) -> Node:
	return player_manager.get_player(player_id)

# 获取本地玩家UI管理器
# @return: 本地玩家UI管理器，未找到返回null
func get_local_player_ui_manager() -> Node:
	return player_manager.get_local_player_ui_manager()

# 获取本地玩家背包
# @return: 本地玩家背包节点，未找到返回null
func get_local_player_inventory() -> Node:
	return player_manager.get_local_player_inventory()

# 获取本地玩家装备物品
# @return: 本地玩家当前装备的物品，未找到返回null
func get_local_player_equipped_item() -> Item:
	return player_manager.get_local_player_equipped_item()

# ==============================================================================
# 向后兼容方法
# ==============================================================================

# 向后兼容：获取玩家（单例模式）
# @deprecated: 多人游戏请使用player_manager.get_local_player()
var player: Node:
	get:
		return player_manager.get_local_player()
	set(value):
		pass

# ==============================================================================
# 调试方法
# ==============================================================================

# 统一的调试信息输出函数
func debug_print(message: String, category: String = "") -> void:
	if debug_mode:
		if category.is_empty():
			print("[DEBUG] ", message)
		else:
			print("[DEBUG][", category, "] ", message)

# 打印玩家管理器信息
func debug_print_players() -> void:
	player_manager.debug_print_players()
