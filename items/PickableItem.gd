# 物品状态类，用于管理物品的动态属性
class_name ItemState
extends RefCounted
var stack_count: int = 1

# PickableItem.gd  (挂在 3D 场景的可拾取节点)
class_name PickableItem
extends Node3D

@export var item: Item  # 拖入物品资源

func _on_body_entered(body):
	if body.is_in_group("player"):
		var state := ItemState.new()
		state.stack_count = 1
		body.inventory.add(item, state)   # inventory 自己实现
		queue_free()
