# ==============================================================================
# Global.gd - 全局变量和功能管理类
# 作为Godot自动加载的单例，提供游戏中需要全局访问的变量和方法
# ==============================================================================

# 扩展自Node类，表示这是一个基本的场景节点
extends Node

# 全局玩家引用，在玩家场景ready时赋值
var player: Node

# _ready方法在节点进入场景树时自动调用
func _ready() -> void:
	# 尝试自动查找玩家节点
	var found_player = get_tree().get_first_node_in_group("player")
	if found_player:
		player = found_player
		print("[Global] 自动找到玩家节点")
	else:
		print("[Global] 警告: 未找到player组的节点，player变量可能未被正确赋值")
