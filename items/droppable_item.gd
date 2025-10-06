
extends Node3D
class_name DroppableItem

@export var item_res: Item
@export var rotate_speed: float = 45.0
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.15

@export var mesh_resource: Mesh = null:
	set(value):
		mesh_resource = value
		_set_mesh_resource(value)

# ===== 公开粒子节点（唯一化用）================================
# ===== 绝对路径硬编码（与场景结构绑定） ========================
@onready var always := $always as GPUParticles3D
@onready var dead := $dead as GPUParticles3D   # 若你叫 GPUParticles3D2 就改这里

# ===== 公开资源参数（可选）===================================
@export var always_material: Material:
	set(val):
		always_material = val
		if always:
			always.process_material = val
			always.restart()

@export var dead_material: Material:
	set(val):
		dead_material = val
		if dead:
			dead.process_material = val

@onready var mesh: MeshInstance3D = $MeshInstance3D
var base_y: float
var picked := false

func _set_mesh_resource(new_mesh_resource: Mesh):
	if not is_inside_tree():
		return
	if mesh and mesh.is_class("MeshInstance3D"):
		mesh.mesh = new_mesh_resource

func _ready():
	base_y = 0.0
	# 连接拾取区
	var area := $Area3D as Area3D
	area.body_entered.connect(_on_body_enter)

	# 初始化常驻粒子
	if always:
		always.emitting = true
	if dead:
		dead.emitting = false
		
func _on_body_enter(body):
	if picked or not body.is_in_group("player"):
		return
	picked = true
	# 下面写你的拾取逻辑（背包、粒子、隐藏等）
	if always:
		always.emitting = false
	if dead:
		dead.restart()
		dead.emitting = true
	
	# 背包交互
	if item_res:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var inv = player.get_node("inventory")
			inv.add_item(item_res)
			if item_res.kind == Item.Kind.KEY and item_res.key_id != -1:
				inv.add_key(item_res.key_id)
		# 不再自动打开背包
			#if player.has_method("toggle_inventory"):
			#	player.toggle_inventory(true)
	
	mesh.hide()
	await get_tree().create_timer(dead.lifetime if dead else 0.8).timeout
	queue_free()

func _process(delta):
	if picked:
		return
	mesh.rotate_y(deg_to_rad(rotate_speed * delta))
	var offset = sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_height
	mesh.position.y = base_y + offset
