@tool extends Control

@export var select_generated_mesh:bool = true
@export var unselect_other_nodes:bool = true
@export var show_preview:bool = true
@export var origin_name:String = ""

# 接收外部传入的 UndoRedo 管理器
var undo_redo: EditorUndoRedoManager

var generated_mesh:ArrayMesh
var gm

func _enter_tree() -> void:
	# 确保在工具模式下每帧运行
	process_mode = Node.PROCESS_MODE_ALWAYS
	return

# 用于接收 union_dock.gd 传来的 UndoRedo
func set_undo_redo(manager: EditorUndoRedoManager):
	undo_redo = manager

func _process(_delta):
	# 仅在可见时更新，节省性能
	if not is_visible_in_tree():
		return
		
	var t:String = ""
	## 构建选中节点列表字符串
	var sna:Array = EditorInterface.get_selection().get_selected_nodes()
	for n in sna:
		if n is MeshInstance3D:
			t += n.name + "\n"
	t = t.strip_edges()
	$Panel/ScrollContainer/SelectedNodeList.text = t
	return

func _on_join_button_pressed() -> void:
	## 获取选中的节点
	var sna:Array = EditorInterface.get_selection().get_selected_nodes()
	
	## 筛选出 MeshInstance3D
	var ma:Array[MeshInstance3D] = []
	for n in sna:
		if n is MeshInstance3D:
			ma.append(n)
	
	## 检查是否选中了有效网格
	if ma.is_empty():
		printerr("MeshReunionPlugin: 未选中任何 MeshInstance3D！")
		return
	
	## 记录第一个网格的名字作为基础名
	origin_name = ma[0].name
	
	## 合并所有网格的表面
	var am:ArrayMesh = ArrayMesh.new()
	var mc:int = 0
	
	for i in ma.size():
		var node = ma[i]
		var m:Mesh = node.mesh
		
		# [修复 1] 增加空值检查！防止选中的 MeshInstance3D 没有 Mesh 资源时崩溃
		if not m:
			printerr("警告: 节点 '", node.name, "' 没有分配 Mesh 资源，已跳过。")
			continue
			
		for sc in m.get_surface_count():
			var sa = m.surface_get_arrays(sc)
			## 移动顶点位置以匹配相对位置
			# 注意：这里使用 PackedVector3Array，直接修改元素是有效的
			var verts = sa[Mesh.ARRAY_VERTEX]
			var offset = node.global_position - ma[0].global_position # [优化] 使用 global_position 更安全
			
			for vi in verts.size():
				verts[vi] += offset
			
			# 将修改后的顶点写回数组（虽然 GDScript 引用传递通常不需要，但在某些版本更稳妥）
			sa[Mesh.ARRAY_VERTEX] = verts
			
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sa)
			am.surface_set_material(mc, m.surface_get_material(sc))
			mc += 1
            
	# [修复 2] 检查生成的 Mesh 是否有效（可能所有选中的网格都是空的）
	if am.get_surface_count() == 0:
		printerr("错误: 无法生成网格，源数据为空。")
		return

	## 记录到全局变量
	generated_mesh = am
	
	## 根据设置决定是否显示预览
	if !show_preview:
		_on_preview_confirm()
		return
	
	## 设置预览窗口
	var a:AcceptDialog = AcceptDialog.new()
	add_child(a)
	
	## 生成预览图
	var pa:Array[Texture2D] = EditorInterface.make_mesh_previews([am], 1000)
	
	## 绘制预览 UI
	var c:Control = Control.new()
	var t:TextureRect = TextureRect.new()
	# Godot 4 布局写法更新
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	if pa.size() > 0:
		t.texture = pa[0]
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var cr:ColorRect = ColorRect.new()
	cr.color = Color(0.0, 0.0, 0.0, 1.0)
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.add_child(t)
	c.add_child(cr)
	
	# 设置最小尺寸防止窗口过小
	c.custom_minimum_size = Vector2(400, 300)
	
	a.add_child(c)
	a.title = "Mesh Preview"
	a.popup_centered(Vector2(500, 400))
	
	var cb:Button = a.add_cancel_button("Cancel")
	var ob:Button = a.get_ok_button()
	ob.text = "Continue"
	a.confirmed.connect(_on_preview_confirm)
	return

func _on_preview_confirm() -> void:
	## 创建新的 MeshInstance3D
	gm = MeshInstance3D.new()
	gm.mesh = generated_mesh
	
	## 命名处理
	gm.name = origin_name
	if !$NameLine.text.is_empty():
		gm.name = $NameLine.text
	
	## 处理重名逻辑
	var siblings:PackedStringArray = []
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		printerr("No edited scene root found.")
		return

	for n in root.get_children():
		siblings.append(n.name)
		
	if siblings.has(gm.name):
		var i:int = 0
		var gmn:String = gm.name
		var gmni:String = ""
		
		# 找到末尾的数字
		while i < gmn.length() && gmn[-i - 1].is_valid_int():
			i += 1
		if i > 0:
			gmni = gmn.substr(gmn.length() - i, -1)
		
		# [修复 3] 彻底修复字符串处理逻辑 (Godot 4 String 没有 erase 方法)
		if !gmni.is_empty():
			var j = 0
			while j < gmni.length() and gmni[j] == "0":
				j += 1
			# 移除前导零
			if j < gmni.length():
				gmni = gmni.substr(j)
			else:
				gmni = "" # 全是0
				
			## 从名字中移除数字部分
			gmn = gmn.left(gmn.length() - i)
		else:
			gmni = "2"
		
		## 递增数字直到不重名
		var val = int(gmni)
		if val == 0: val = 2 # 防止转换失败
		
		while siblings.has(gmn + str(val)):
			val += 1
		gm.name = gmn + str(val)
	
	## 添加到场景并注册撤销操作
	if undo_redo:
		undo_redo.create_action("Merge Mesh")
		undo_redo.add_do_method(root, "add_child", gm)
		undo_redo.add_do_property(gm, "owner", root)
		undo_redo.add_undo_method(root, "remove_child", gm)
		undo_redo.commit_action()
	else:
		printerr("UndoRedo manager not available")
		return
	
	## 处理选中状态
	var es:EditorSelection = EditorInterface.get_selection()
	var sna:Array = es.get_selected_nodes()
	if unselect_other_nodes:
		for n in sna:
			es.remove_node(n)
	
	if select_generated_mesh:
		es.add_node(gm)
	return

func _exit_tree() -> void:
	return

func _on_select_mesh_box_toggled(toggled_on):
	select_generated_mesh = toggled_on

func _on_unselect_nodes_box_toggled(toggled_on):
	unselect_other_nodes = toggled_on

func _on_show_preview_box_toggled(toggled_on):
	show_preview = toggled_on