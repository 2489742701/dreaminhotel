extends Control
class_name ItemPreviewGUI

@onready var sub_viewport := $SubViewportContainer/SubViewport as SubViewport
@onready var camera := $SubViewportContainer/SubViewport/Camera3D as Camera3D
@onready var preview_root := $SubViewportContainer/SubViewport/PreviewRoot as Node3D
@onready var item_name_label := $VBoxContainer/ItemNameLabel as Label
@onready var item_description_label := $VBoxContainer/ItemDescriptionLabel as Label
@onready var sub_viewport_container := $SubViewportContainer as SubViewportContainer

var current_item: Item = null
var current_item_index: int = -1
var drag_start: Vector2 = Vector2()
var rot_x: float = 0.0
var rot_y: float = 0.0

func _ready():
	pass 

func set_item(it: Item, item_index: int = -1, _is_equipped: bool = false):
	# 清除旧模型
	for c in preview_root.get_children():
		c.queue_free()
	
	current_item = it
	current_item_index = item_index
	
	# 添加空值检查，确保标签节点存在
	if not is_instance_valid(item_name_label) or not is_instance_valid(item_description_label):
		return
	
	# 如果没有物品，清空文本并返回
	if it == null:
		item_name_label.text = ""
		item_description_label.text = ""
		return
	
	# 更新物品名称和描述
	item_name_label.text = it.name if it.name else "未知物品"
	# 使用物品的desc属性作为描述文本
	item_description_label.text = it.desc if it.desc else "暂无介绍"
	
	# 添加安全检查
	if not it.mesh:
		print("警告: 物品 ", it.name, " 没有关联的3D模型")
		return
	
	# 创建并设置模型
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = it.mesh
	
	preview_root.add_child(mesh_instance)
	rot_x = 0.0
	rot_y = 0.0
	_apply_rotation()

# 移除按钮相关函数
	
func _on_guide_button_pressed():
	# 发出信号通知父节点处理引导操作
	emit_signal("guide_button_pressed", current_item_index)

# 检查鼠标是否在SubViewportContainer区域内
func is_mouse_in_preview_area(pos: Vector2) -> bool:
	if not is_instance_valid(sub_viewport_container):
		return false
	var rect = sub_viewport_container.get_rect()
	return rect.has_point(pos)

func _input(event):
	if not current_item or not is_instance_valid(sub_viewport_container): return
	
	# 只在鼠标位于预览区域内时处理拖拽旋转
	if is_mouse_in_preview_area(get_local_mouse_position()):
		# 拖拽旋转
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_start = event.position
			else:
				drag_start = Vector2()
		if event is InputEventMouseMotion and drag_start != Vector2():
			# 旋转灵敏度系数，降低后旋转速度变慢
			var rotation_sensitivity = 0.04
			rot_y += event.relative.x * rotation_sensitivity
			# 上下旋转方向反转，使用负数
			rot_x -= event.relative.y * rotation_sensitivity
			_apply_rotation()

func _apply_rotation():
	preview_root.transform = Transform3D().rotated(Vector3.RIGHT, rot_x).rotated(Vector3.UP, rot_y)
