# ==============================================================================
# AnimDrink.gd
# 喝饮料动画资源类
# 功能：实现喝饮料动画，完全复刻原hand_take.gd中的play_drink_animation复杂逻辑
# 继承：HandAnimation - 手持动画基类
# ==============================================================================

@tool
extends HandAnimation
class_name AnimDrink

# ==============================================================================
# 饮料动画参数（完全复刻原代码）
# ==============================================================================

@export_group("饮料动画参数")
# 动画总时长（秒）
@export var 动画总时长: float = 1.0

# 旋转角度：向后倾斜角度
@export var 旋转角度: float = 30.0

# 移动距离：向上移动距离
@export var 移动距离: float = 0.2

# 杯子Z轴旋转角度
@export var 杯子Z轴旋转: float = 110.0

# 杯子Y轴旋转角度
@export var 杯子Y轴旋转: float = 35.0

# 停顿时间
@export var 停顿时间: float = 0.8

@export_subgroup("时间比例")
# 举杯动作时间比例
@export var 举杯动作比例: float = 0.3

# 杯子旋转时间比例
@export var 杯子旋转比例: float = 0.2

# 喝水动作时间比例
@export var 喝水动作比例: float = 0.1

# 继续喝水时间比例
@export var 继续喝水比例: float = 0.1

# 返回原位时间比例
@export var 返回原位比例: float = 0.2

@export_subgroup("移动比例")
# 向下移动比例（相对于最大移动距离）
@export var 向下移动比例: float = 0.5

# 向上移动比例（相对于最大移动距离）
@export var 向上移动比例: float = 0.7

# ==============================================================================
# 核心动画方法
# ==============================================================================

# 取消动画时恢复状态
func cancel(target: Node3D) -> void:
    var drink_mesh = target as MeshInstance3D
    
    # 简单直接：恢复盖子材质，解除任何隐藏
    if is_instance_valid(drink_mesh):
        # 直接清除表面覆盖材质，恢复原始状态
        drink_mesh.set_surface_override_material(0, null)
        
        # 清理可能存在的元数据
        if drink_mesh.has_meta("original_lid_material"):
            drink_mesh.remove_meta("original_lid_material")
        if drink_mesh.has_meta("target_mesh_resource"):
            drink_mesh.remove_meta("target_mesh_resource")
            
        print("[AnimDrink] 取消动画，重置盖子状态")

# 应用喝饮料动画
func apply(target: Node3D, tween: Tween, on_complete: Callable = Callable()) -> void:
    var original_position = target.position
    var original_rotation = target.rotation_degrees
    
    var drink_mesh = target as MeshInstance3D
    var original_lid_material = null
    
    # 【关键修改 1】保存当前具体的 Mesh 资源引用
    # 我们不仅要保存节点，还要保存"当时是哪个模型"
    var current_mesh_resource = null 
    
    if drink_mesh and drink_mesh.mesh:
        current_mesh_resource = drink_mesh.mesh # 记录下这个具体的饮料资源
        
        var surface_count = drink_mesh.mesh.get_surface_count()
        if surface_count > 0:
            original_lid_material = drink_mesh.get_surface_override_material(0)
            if original_lid_material == null:
                original_lid_material = drink_mesh.mesh.surface_get_material(0)
            
            # 保存元数据
            drink_mesh.set_meta("original_lid_material", original_lid_material)
            # 保存这是属于哪个 Mesh 的元数据
            drink_mesh.set_meta("target_mesh_resource", current_mesh_resource)
    
    # 原代码：tween.set_parallel(false)  # 串行执行，确保动画按顺序播放
    # 注意：传入的tween默认行为由调用者决定
    
    # 第一步：向后旋转并向上移动（模拟举杯动作）
    var step1_duration = 动画总时长 * 举杯动作比例
    
    # Step 1 组合动作（并行执行，复刻原逻辑）
    tween.tween_property(target, "rotation_degrees:x", -旋转角度, step1_duration)
    tween.parallel().tween_property(target, "rotation_degrees:y", 杯子Y轴旋转, step1_duration)
    tween.parallel().tween_property(target, "position:y", original_position.y + 移动距离, step1_duration)
    
    # 第二步：杯子旋转到合适角度（杯口对着摄像机）
    var step2_duration = 动画总时长 * 杯子旋转比例
    tween.tween_property(target, "rotation_degrees:z", 杯子Z轴旋转, step2_duration)
    
    # 【关键修改 2】回调中的安全检查：隐藏盖子
    tween.parallel().tween_callback(func():
        # 1. 检查节点是否还存在
        if not is_instance_valid(drink_mesh): return
        
        # 2. 【核心】检查当前 Mesh 是否还是当初那个饮料
        # 如果玩家切换了道具，drink_mesh.mesh 就会变成"枪"或者"其他物品"
        if drink_mesh.mesh != current_mesh_resource: return
        
        if original_lid_material:
            var transparent_mat = StandardMaterial3D.new()
            transparent_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
            transparent_mat.albedo_color = Color(1, 1, 1, 0)
            drink_mesh.set_surface_override_material(0, transparent_mat)
    )
    
    # 停顿：杯子保持在旋转后的位置
    tween.tween_interval(停顿时间)
    
    # 第三步：稍微向下移动（模拟喝水动作）
    var step3_duration = 动画总时长 * 喝水动作比例
    tween.tween_property(target, "position:y", original_position.y + 移动距离 * 向下移动比例, step3_duration)
    
    # 第四步：稍微向上移动（模拟继续喝水）
    var step4_duration = 动画总时长 * 继续喝水比例
    tween.tween_property(target, "position:y", original_position.y + 移动距离 * 向上移动比例, step4_duration)
    
    # 第五步：返回原位，同时杯子旋转回原始角度
    var step5_duration = 动画总时长 * 返回原位比例
    
    # 【关键修改 3】回调中的安全检查：恢复盖子
    tween.parallel().tween_callback(func():
        # 同样进行双重检查
        if not is_instance_valid(drink_mesh): return
        if drink_mesh.mesh != current_mesh_resource: return
        
        # 恢复材质
        # 这里建议直接设置为 null 来移除 override，这样更干净
        drink_mesh.set_surface_override_material(0, null) 
        
        # 清理元数据
        if drink_mesh.has_meta("original_lid_material"):
            drink_mesh.remove_meta("original_lid_material")
        if drink_mesh.has_meta("target_mesh_resource"):
            drink_mesh.remove_meta("target_mesh_resource")
    )
    
    tween.tween_property(target, "rotation_degrees:x", original_rotation.x, step5_duration)
    tween.parallel().tween_property(target, "rotation_degrees:y", original_rotation.y, step5_duration)
    tween.parallel().tween_property(target, "rotation_degrees:z", original_rotation.z, step5_duration)
    tween.parallel().tween_property(target, "position:y", original_position.y, step5_duration)
    
    # 动画完成回调
    if on_complete.is_valid():
        tween.tween_callback(on_complete)