# Godot游戏开发实战经验总结

基于DreamInHotel项目的开发实践

## 项目概述

DreamInHotel是一个使用Godot 4.5开发的3D酒店冒险游戏，包含角色控制、物品系统、背包管理、体力系统等核心功能。通过分析该项目，总结出以下开发经验。

## 一、项目架构与组织经验

### 1.1 目录结构设计

**最佳实践：**
```
scenes/          # 场景文件
├── characters/  # 角色相关场景
├── items/       # 物品相关场景
├── ui/          # UI界面场景
└── world/       # 世界场景

scripts/         # 脚本文件
├── characters/  # 角色控制脚本
├── items/       # 物品系统脚本
├── ui/          # UI控制脚本
└── world/       # 世界交互脚本

resources/       # 资源文件
└── items/       # 物品资源定义
```

**经验总结：**
- 按功能模块划分目录，便于维护和扩展
- 场景文件与脚本文件保持对应关系
- 资源文件集中管理，便于统一修改

### 1.2 文件命名规范

- **场景文件**：使用PascalCase（如`DroppableItem.tscn`）
- **脚本文件**：使用snake_case（如`droppable_item.gd`）
- **资源文件**：使用描述性名称（如`key1.tres`）

## 二、核心系统设计经验

### 2.1 单例模式应用

**Global.gd - 全局状态管理：**
```gdscript
extends Node
var player: Node

func _ready() -> void:
    var found_player = get_tree().get_first_node_in_group("player")
    if found_player:
        player = found_player
```

**经验：**
- 使用Godot的自动加载功能实现单例
- 通过分组系统快速定位游戏对象
- 提供全局访问点，避免组件间强耦合

### 2.2 组件化设计

**player.gd - 角色控制器：**
```gdscript
@export var move_speed: float = 5.0
@export var jump_force: float = 10.0
@export var stamina_max: float = 100.0

var current_stamina: float
var inventory: Inventory
```

**经验：**
- 使用`@export`暴露可调参数，便于调试
- 将复杂功能分解为独立组件
- 通过组合而非继承实现功能复用

### 2.3 数据驱动设计

**Item.gd - 物品数据结构：**
```gdscript
enum TYPE {KEY, WEAPON, QUEST, CONSUMABLE}

var item_name: String
var item_type: TYPE
var description: String
var icon: Texture2D
var max_stack: int = 1
```

**经验：**
- 使用枚举定义类型，提高代码健壮性
- 资源文件(.tres)存储物品属性，实现数据与逻辑分离
- 支持多语言翻译，便于国际化

## 三、Godot引擎特性应用经验

### 3.1 信号系统应用

**信号通信模式：**
```gdscript
# 体力值变化信号
signal stamina_changed(new_value: float)

# 物品拾取信号
signal item_picked_up(item: Item)

# 在需要时发射信号
func _update_stamina(value: float):
    current_stamina = value
    stamina_changed.emit(value)
```

**经验：**
- 使用信号实现组件间松耦合通信
- 避免直接引用，提高代码可维护性
- 结合Area3D信号实现3D交互

### 3.2 场景实例化

**预制体应用：**
```gdscript
# 动态创建可拾取物品
var item_scene = preload("res://scenes/items/DroppableItem.tscn")
var new_item = item_scene.instantiate()
add_child(new_item)
```

**经验：**
- 使用预制体实现对象复用
- 通过场景树管理对象生命周期
- 支持运行时动态创建和销毁

### 3.3 UI系统设计

**CanvasLayer应用：**
```gdscript
extends CanvasLayer
# UI始终显示在最上层，不受3D场景影响
```

**经验：**
- CanvasLayer实现UI与3D场景分离
- Control节点树构建响应式界面
- 使用Tween实现平滑动画效果

## 四、性能优化经验

### 4.1 批处理优化

**InventoryGUI3D.gd中的优化：**
```gdscript
func refresh_inventory():
    # 批量隐藏-修改-显示策略
    for child in grid_container.get_children():
        child.visible = false
    
    # 执行更新操作
    _update_item_buttons()
    
    for child in grid_container.get_children():
        child.visible = true
```

**经验：**
- 减少UI更新带来的性能开销
- 使用`call_deferred()`延迟耗时操作
- 避免在关键帧中执行复杂计算

### 4.2 资源管理

**资源预加载：**
```gdscript
# 预加载常用资源
var item_textures = {}

func _ready():
    item_textures["key"] = preload("res://assets/textures/key.png")
    item_textures["potion"] = preload("res://assets/textures/potion.png")
```

**经验：**
- 预加载避免运行时卡顿
- 使用实例池处理频繁创建/销毁的对象
- 合理管理内存使用

## 五、高级功能实现经验

### 5.1 多语言支持

**Tr.gd翻译系统：**
```gdscript
extends Node

func items(key: String) -> String:
    var translated = tr(key)
    if translated != key:
        return translated
    return key
```

**经验：**
- 使用Godot内置翻译系统
- CSV文件管理翻译内容
- 封装翻译接口，便于统一调用

### 5.2 3D交互系统

**碰撞检测与交互：**
```gdscript
# Area3D实现交互区域
func _on_area_3d_body_entered(body: Node3D):
    if body.is_in_group("player"):
        show_interaction_prompt()
```

**经验：**
- Area3D实现非物理碰撞检测
- RayCast3D实现视线检测
- 3D文字提示增强用户体验

### 5.3 动画系统

**状态机与动画控制：**
```gdscript
enum PlayerState {IDLE, WALKING, RUNNING, JUMPING}
var current_state: PlayerState

func _update_animation():
    match current_state:
        PlayerState.IDLE:
            animation_player.play("idle")
        PlayerState.WALKING:
            animation_player.play("walk")
```

**经验：**
- 使用枚举管理角色状态
- AnimationPlayer实现复杂动画序列
- 状态机模式管理动画切换逻辑

## 六、开发实践与调试经验

### 6.1 代码规范

**文件头注释规范：**
```gdscript
# ==============================================================================
# player.gd - 玩家角色控制器
# 实现3D角色移动、跳跃、体力管理等功能
# ==============================================================================
```

**经验：**
- 详细的文件头注释说明用途
- 函数参数类型标注提高可读性
- 使用空行和注释分隔代码块

### 6.2 调试技巧

**调试工具使用：**
```gdscript
# 关键节点查找
print("[Debug] 找到玩家节点:", player)

# 状态监控
print("[Debug] 当前体力值:", current_stamina)

# 使用分组快速定位
var player_node = get_tree().get_first_node_in_group("player")
```

**经验：**
- 使用`print()`进行状态监控
- 分组系统快速定位游戏对象
- 利用Godot内置调试工具

### 6.3 版本控制

**.gitignore配置：**
```
# Godot临时文件
*.import
.godot/

# 构建产物
build/
export/
```

**经验：**
- 合理配置.gitignore排除临时文件
- 注意.import文件的管理
- 保持资源引用的正确性

## 七、常见问题与解决方案

### 7.1 性能问题

**问题：** UI更新导致卡顿
**解决方案：** 使用批处理更新策略

**问题：** 频繁的对象创建/销毁
**解决方案：** 实现对象池模式

### 7.2 内存管理

**问题：** 资源泄漏
**解决方案：** 及时释放不再使用的资源

**问题：** 大场景加载缓慢
**解决方案：** 实现场景分块加载

### 7.3 跨平台兼容性

**问题：** 输入设备差异
**解决方案：** 使用Godot的通用输入系统

**问题：** 分辨率适配
**解决方案：** 使用Control节点的锚点系统

### 7.4 导航系统问题

**问题：** 怪物被卡到地里面无法移动
**原因：** 导航网格烘焙高度过高，导致导航代理无法正确识别地面
**解决方案：** 
1. 手动调整导航网格的高度位置，使其与地面贴合
2. 检查场景中模型的缩放和位置是否正确
3. 避免随意调整模型大小，可能导致导航网格偏移
**预防措施：**
- 在调整模型后，重新烘焙导航网格
- 使用Godot的导航网格调试工具可视化导航区域
- 确保导航网格的高度与地面高度一致

## 八、总结与建议

### 8.1 核心经验总结

1. **模块化设计**：按功能划分模块，提高可维护性
2. **数据驱动**：分离数据与逻辑，便于扩展
3. **信号通信**：使用信号实现松耦合组件通信
4. **性能优先**：批处理更新，合理管理资源
5. **用户体验**：平滑动画，直观交互

### 8.2 未来开发建议

1. **深入学习GDScript高级特性**：类型系统、泛型等
2. **探索Godot 4.5新特性**：改进的渲染管线、性能优化
3. **建立完善的测试流程**：单元测试、集成测试
4. **关注移动平台优化**：性能调优、触控适配
5. **持续学习社区最佳实践**：关注Godot官方文档和社区分享

### 8.3 项目扩展方向

1. **网络功能**：添加多人联机支持
2. **存档系统**：实现游戏进度保存
3. **AI系统**：添加NPC智能行为
4. **特效系统**：增强视觉表现力
5. **内容扩展**：增加更多游戏内容和关卡

---

*本文档基于DreamInHotel项目的实际开发经验总结，适用于Godot 4.x版本的游戏开发实践。*

## 九、开发进度记录

### 9.1 已完成工作（2025-02-11）

#### 多人游戏优化
- 创建PlayerManager类（c:\Users\longyaosi\Documents\dreaminhotel\scripts\managers\PlayerManager.gd）
  - 管理玩家实例和玩家ID映射
  - 提供获取当前玩家和本地玩家的方法
  - 支持多人游戏场景下的玩家管理

- 创建PlayerUIManager类（c:\Users\longyaosi\Documents\dreaminhotel\scripts\ui\PlayerUIManager.gd）
  - 统一管理玩家UI组件（背包、快捷栏、体力条等）
  - 支持多人游戏下的UI显示控制
  - 提供UI组件的访问接口

- 重构UI组件
  - 修改player.gd，使用PlayerUIManager管理UI
  - 更新hotbar_ui.gd和item_preview_gui.gd，支持通过管理器访问
  - 解决autoload单例与类名冲突问题

#### UI改进
- 物品边框功能
  - 为背包和快捷栏中的物品添加白色边框
  - 适应游戏黑暗环境的视觉需求
  - 在hotbar_ui.gd和item_preview_gui.gd中实现_add_border_to_icon方法

#### 物品系统修复
- 修复能量饮料不被识别为消耗品的问题
  - 问题原因：drink.tres中"物品类型" = 3（工具），应该是2（消耗品）
  - 修复：将drink.tres的"物品类型"改为2
  - 备份：c:\Users\longyaosi\Documents\dreaminhotel\.trae\documents\drink.tres.backup_20250211

- 修复1.tres物品类型错误
  - 问题原因：1.tres中"物品类型" = 3（工具），但有"消耗品效果"字段
  - 修复：将1.tres的"物品类型"改为2（消耗品）
  - 备份：c:\Users\longyaosi\Documents\dreaminhotel\.trae\documents\1.tres.backup_20250211

- 修复light.tres物品类型错误
  - 问题原因：light.tres中"物品类型" = 3（工具），从文件名看应该是手电筒
  - 修复：将light.tres的"物品类型"改为4（手电筒）
  - 备份：c:\Users\longyaosi\Documents\dreaminhotel\.trae\documents\light.tres.backup_20250211

#### 物品类型枚举参考
```gdscript
enum Kind { 
	KEY,        # 0 - 钥匙类物品
	WEAPON,     # 1 - 武器类物品  
	CONSUMABLE, # 2 - 消耗品类物品
	TOOL,       # 3 - 工具类物品
	FLASHLIGHT  # 4 - 手电筒类物品
}
```

### 9.2 待完成任务

#### 多人游戏优化
- [ ] 完善PlayerManager的网络同步功能
- [ ] 实现玩家状态同步（位置、动作等）
- [ ] 添加多人游戏UI显示逻辑
- [ ] 测试多人游戏场景下的UI管理

#### 物品系统
- [ ] 检查其他物品资源文件的类型设置是否正确
- [ ] 完善消耗品使用逻辑
- [ ] 添加更多消耗品类型和效果

#### UI系统
- [ ] 优化UI性能，减少不必要的更新
- [ ] 添加更多UI交互反馈
- [ ] 完善多语言支持

#### 其他
- [ ] 性能优化和测试
- [ ] 代码重构和规范检查
- [ ] 文档完善

### 9.3 备份文件位置

所有修改前的文件备份位于：
- c:\Users\longyaosi\Documents\dreaminhotel\.trae\documents\
  - drink.tres.backup_20250211
  - 1.tres.backup_20250211
  - light.tres.backup_20250211

### 9.4 潜在问题与疑问（2025-02-11检查发现）

#### 问题1：key1.tres 缺少必要属性
**文件位置**：c:\Users\longyaosi\Documents\dreaminhotel\resources\items\key1.tres

**问题描述**：
- 缺少"物品类型"字段（默认为Kind.KEY=0）
- 缺少"钥匙ID"字段（默认为-1）
- 缺少"图标"字段
- 缺少"描述翻译键"字段

**影响范围**：
- [inventory.gd:111](file:///c:\Users\longyaosi\Documents\dreaminhotel\scripts\characters\inventory.gd#L111) 检查 `it.钥匙ID != -1`，如果钥匙ID为-1，钥匙不会被添加到钥匙列表中
- [doorcontrol.gd:415](file:///c:\Users\longyaosi\Documents\dreaminhotel\scripts\world\doorcontrol.gd#L415) 调用 `inv.has_key(所需钥匙ID)` 检查钥匙
- UI显示时可能缺少图标

**相关代码**：
```gdscript
# inventory.gd:111
if it.物品类型 == Item.Kind.KEY and it.钥匙ID != -1:
    add_key(it.钥匙ID)
```

**建议修复**：
- 为key1.tres添加"物品类型" = 0（KEY）
- 设置"钥匙ID"为一个有效的门ID（如1）
- 添加"图标"和"描述翻译键"

**备份文件**：无（此文件未修改，如需修复请先备份）

---

#### 问题2：light.tres 缺少手电筒属性
**文件位置**：c:\Users\longyaosi\Documents\dreaminhotel\resources\items\light.tres

**问题描述**：
虽然设置了"物品类型" = 4（手电筒），但缺少：
- 手电筒专用属性：电池容量、当前电量、亮度、范围、射程、电量消耗率
- 基础属性：名称翻译键、图标、模型

**影响范围**：
- [player.gd:1385](file:///c:\Users\longyaosi\Documents\dreaminhotel\scripts\characters\player.gd#L1385) 检查手电筒属性
- [player.gd:1424](file:///c:\Users\longyaosi\Documents\dreaminhotel\scripts\characters\player.gd#L1424) 检查手电筒状态
- [item_preview_gui.gd:357](file:///c:\Users\longyaosi\Documents\dreaminhotel\scripts\items\item_preview_gui.gd#L357) 显示电池容量
- 手电筒功能无法正常使用

**相关代码**：
```gdscript
# player.gd:1385
if not current_equipped_item or current_equipped_item.物品类型 != Item.Kind.FLASHLIGHT:

# item_preview_gui.gd:357
var max_battery = item.电池容量 if item.has_method("get") and item.get("电池容量") != null else 100.0
```

**建议修复**：
- 添加手电筒专用属性（参考Item.gd中的定义）
- 添加"名称翻译键"、"图标"、"模型"等基础属性

**备份文件**：c:\Users\longyaosi\Documents\dreaminhotel\.trae\documents\light.tres.backup_20250211

---

#### 问题3：1.tres 缺少基础属性
**文件位置**：c:\Users\longyaosi\Documents\dreaminhotel\resources\items\1.tres

**问题描述**：
- 缺少"名称翻译键"字段
- 缺少"图标"和"模型"字段
- 只有"物品类型" = 2（消耗品）和"消耗品效果"

**影响范围**：
- [item_preview_gui.gd:167](file:///c:\Users\longyaosi\Documents\dreaminhotel\scripts\items\item_preview_gui.gd#L167) 检查模型是否存在
- [hotbar_ui.gd:102](file:///c:\Users\longyaosi\Documents\dreaminhotel\scripts\ui\hotbar_ui.gd#L102) 检查图标是否存在
- UI显示时会出现问题或使用默认图标

**相关代码**：
```gdscript
# item_preview_gui.gd:167
if not it.模型:
    print("警告: 物品 ", it.名称翻译键, " 没有关联的3D模型")

# hotbar_ui.gd:102
if item.图标:
    var bordered_icon = _add_border_to_icon(item.图标)
```

**建议修复**：
- 添加"名称翻译键"字段
- 添加"图标"和"模型"字段
- 或者确认这是一个测试物品，可以接受使用默认图标

**备份文件**：c:\Users\longyaosi\Documents\dreaminhotel\.trae\documents\1.tres.backup_20250211

---

#### 问题4：代码中访问可能不存在的属性
**问题描述**：
多处代码直接访问物品属性，但未充分检查属性是否存在，可能导致运行时错误。

**影响范围**：

1. **player.gd:757** - 检查消耗品效果
```gdscript
if not current_equipped_item.消耗品效果:
    Global.debug_print("当前物品没有配置消耗品效果", "Player")
    return
```
**风险**：如果物品类型不是CONSUMABLE，访问"消耗品效果"属性可能返回null

2. **player.gd:808** - 检查武器攻击效果
```gdscript
if not current_equipped_item.武器攻击效果:
    Global.debug_print("当前物品没有配置武器攻击效果", "Player")
    return
```
**风险**：如果物品类型不是WEAPON，访问"武器攻击效果"属性可能返回null

3. **item_preview_gui.gd:357** - 检查电池容量
```gdscript
var max_battery = item.电池容量 if item.has_method("get") and item.get("电池容量") != null else 100.0
```
**风险**：虽然使用了安全检查，但代码不够简洁

**建议修复**：
- 在访问物品特定属性前，先检查物品类型
- 使用更安全的属性访问方式
- 或者在Item.gd中为所有属性提供默认值

---

#### 问题5：物品类型枚举值不一致
**问题描述**：
在代码中同时使用了数字和枚举名称来比较物品类型，可能导致混淆。

**示例**：
```gdscript
# 使用枚举名称（推荐）
if item.物品类型 == Item.Kind.CONSUMABLE:

# 使用数字（不推荐）
if item.物品类型 == 2:
```

**建议**：
- 统一使用枚举名称（Item.Kind.CONSUMABLE等）而不是数字
- 提高代码可读性和可维护性

---

#### 问题6：资源文件命名不规范
**问题描述**：
- 1.tres 文件名不够描述性，难以理解其用途
- light.tres 文件名与实际用途可能不符（需要确认是否真的是手电筒）

**建议**：
- 将1.tres重命名为更具描述性的名称（如test_consumable.tres或potion.tres）
- 确认light.tres的用途，如果确实是手电筒，可重命名为flashlight.tres

---

### 9.5 修复优先级建议

#### 高优先级（影响核心功能）
1. **问题1：key1.tres 缺少钥匙ID** - 影响门锁系统
2. **问题2：light.tres 缺少手电筒属性** - 影响手电筒功能

#### 中优先级（影响UI显示）
3. **问题3：1.tres 缺少基础属性** - 影响UI显示

#### 低优先级（代码质量）
4. **问题4：代码属性访问安全** - 提高代码健壮性
5. **问题5：枚举值使用一致性** - 提高代码可读性
6. **问题6：文件命名规范** - 提高可维护性

---

### 9.6 导航网格问题解决记录（2025-02-11）

#### 问题：导航网格在天花板上生成

**问题描述**：
在烘焙NavigationMesh时，导航网格有概率在天花板上生成，导致怪物无法正常寻路。

**原因分析**：
- NavigationMesh的默认参数设置不当
- 缺少区块最小尺寸限制，导致小区域也被生成导航网格
- 天花板等非地面区域也被识别为可行走区域

**解决方案**：
在NavigationMesh中设置以下参数：

```gdscript
region_min_size = 19.31  # 区块被创建需要最小尺寸
filter_walkable_low_height_spans = true  # 过滤低高度区域
```

**参数说明**：
- `region_min_size = 19.31`：设置区块被创建的最小尺寸，过滤掉小面积的区域（如天花板上的小区域）
- `filter_walkable_low_height_spans = true`：过滤掉高度不足的可行走区域

**文件位置**：
- c:\Users\longyaosi\Documents\dreaminhotel\scenes\try.tscn
- NavigationMesh_5il75子资源

**验证方法**：
1. 在Godot编辑器中选择NavigationRegion3D节点
2. 点击"Bake NavMesh"按钮重新烘焙
3. 检查导航网格是否只在地面上生成

**注意事项**：
- `region_min_size`的值需要根据实际场景调整，过大可能导致某些区域无法生成导航网格
- 如果导航网格生成不完整，可以适当减小`region_min_size`的值
- 确保场景中的几何体有正确的碰撞形状

### 9.7 怪物与门沟通机制（2025-02-12）

#### 概述

怪物与门的沟通机制实现了怪物能够智能地检测、开门和攻击门的功能。该机制使用Area3D检测系统，结合状态机管理，确保怪物只在特定状态下与门交互。

#### 核心机制

**分组系统**：
- 怪物添加到 `"monster"` 分组
- 玩家添加到 `"player"` 分组
- 门的Area3D检测这两个分组

**门的Area3D检测**：
- `inarea`：内侧Area3D
- `outarea`：外侧Area3D
- `collision_layer = 2`
- `collision_mask = 2`

#### 怪物门检测实现

**怪物变量**：
```gdscript
var nearby_doors: Array[Node] = []  # 附近的门列表
var door_attack_cooldown: float = 0.0  # 门攻击冷却
var door_attack_cooldown_duration: float = 2.0  # 门攻击冷却持续时间
var is_attacking_door: bool = false  # 是否正在攻击门
var is_returning_to_patrol: bool = false  # 是否正在回到导航点
```

**注册门**：
```gdscript
func register_door(door_node: Node) -> void:
    if not nearby_doors.has(door_node):
        nearby_doors.append(door_node)
        print("[Monster] 进入门的范围: ", door_node.name)
```

**注销门**：
```gdscript
func unregister_door(door_node: Node) -> void:
    if nearby_doors.has(door_node):
        nearby_doors.erase(door_node)
        print("[Monster] 离开门的范围: ", door_node.name)
```

#### 门攻击系统

**检查并攻击门**：
```gdscript
func check_and_attack_door():
    # 只在追击状态或回到导航点时攻击门
    if current_state != State.CHASE and not is_returning_to_patrol:
        return
    
    # 如果正在攻击门，跳过
    if is_attacking_door:
        return
    
    if door_attack_cooldown > 0:
        return
    
    # 使用Area3D检测到的门列表
    if nearby_doors.is_empty():
        return
    
    # 找到最近的门
    var nearest_door = null
    var min_distance = 999.0
    
    for door in nearby_doors:
        var distance = global_position.distance_to(door.global_position)
        if distance < min_distance:
            min_distance = distance
            nearest_door = door
    
    if not nearest_door:
        return
    
    # 检查门是否被封（有木板）
    var is_sealed = false
    if nearest_door.has_method("get"):
        is_sealed = nearest_door.get("is_sealed")
    
    # 如果门没有木板，尝试开门
    if not is_sealed:
        try_open_door(nearest_door)
        return
    
    # 门有木板，攻击门
    attack_door(nearest_door)
```

**尝试开门**：
```gdscript
func try_open_door(door_node: Node):
    if door_node and door_node.has_method("try_open_door"):
        door_node.try_open_door(self)
```

**攻击门**：
```gdscript
func attack_door(door_node: Node):
    is_attacking_door = true
    door_attack_cooldown = door_attack_cooldown_duration
    
    play_door_attack_animation()
    
    get_tree().create_timer(0.5).timeout.connect(func():
        if door_node and door_node.has_method("execute_chop_logic"):
            door_node.execute_chop_logic()
        is_attacking_door = false
        
        print("[Monster] 攻击完成，结束追击")
        change_state(State.WANDER)
    )
```

#### 门的开门逻辑

**门的开门方法**：
```gdscript
func try_open_door(caller: Node = null):
    if state == "OPENED":
        return
    
    if is_sealed:
        print("门：门被封住，无法打开")
        return
    
    if state == "NEED_KEY":
        if caller and caller.is_in_group("player"):
            if not has_key_in_inventory():
                print("门：没有钥匙，无法打开")
                return
        elif caller and caller.is_in_group("monster"):
            print("门：怪物尝试开门")
        else:
            if not has_key_in_inventory():
                print("门：没有钥匙，无法打开")
                return
    
    play_open()
```

**门的变量**：
```gdscript
var is_sealed: bool = false  # 门是否已封
var state: String = ""  # 当前门状态
var last_side: float = 1.0  # 1=里侧开  -1=外侧开
var is_animating: bool = false  # 动画期间禁止再次触发
```

#### 状态管理

**怪物状态枚举**：
```gdscript
enum State { IDLE, WANDER, CHASE }
```

**状态切换**：
```gdscript
func change_state(new_state: State):
    if current_state == new_state:
        return
    
    if current_state == State.CHASE and new_state == State.WANDER:
        was_chasing = true
        is_returning_to_patrol = true  # 标记正在回到导航点
        find_nearest_patrol_point()
    
    if current_state == State.WANDER and new_state == State.CHASE:
        was_chasing = false
        is_returning_to_patrol = false
    
    current_state = new_state
```

#### 触发条件

**怪物检查门的条件**：
1. **追击状态** (`State.CHASE`)
   - 怪物正在追击玩家
   - 附近有门
   - 门攻击冷却结束

2. **回到导航点** (`is_returning_to_patrol`)
   - 怪物刚刚从追击状态切换回来
   - 正在回到导航点
   - 附近有门
   - 门攻击冷却结束

**门检测怪物的条件**：
1. 怪物进入门的Area3D范围
2. 怪物的 `collision_layer = 2`
3. 门的 `collision_mask = 2`

#### 开门方向

**反向开门机制**：
- 门使用 `last_side` 变量决定开门方向
- `last_side = 1.0`：从里侧开门
- `last_side = -1.0`：从外侧开门

**开门动画**：
```gdscript
func play_open():
    if is_animating: return
    is_animating = true
    state = "OPENED"
    key_used = true
    
    if _tween and is_instance_valid(_tween):
        _tween.kill()
    _tween = create_tween().set_loops(0)
    
    _tween.tween_property(door_mesh, "rotation_degrees:y", default_rot.y + 开门角度 * last_side, 动画速度)
    _tween.tween_callback(func():
        is_animating = false
        door_opened.emit()
    )
```

#### 巡逻系统优化

**正常巡逻**：
- 直接朝向巡逻点移动，不计算路径
- 到达巡逻点后等待2秒，然后切换到下一个巡逻点
- 节省性能，避免不必要的路径计算

**回到导航点**（追击完成后）：
- 使用导航代理智能寻路到最近的巡逻点
- 自动避障和绕路
- 到达巡逻点后重置 `is_returning_to_patrol` 标记

**巡逻等待机制**：
```gdscript
var patrol_wait_timer: float = 0.0  # 巡逻点等待计时器
var patrol_wait_duration: float = 2.0  # 巡逻点等待持续时间
var is_waiting_at_patrol: bool = false  # 是否正在巡逻点等待
```

#### 文件位置

**怪物文件**：
- `c:\Users\longyaosi\Documents\dreaminhotel\scripts\monsters\monster_base.gd`

**门文件**：
- `c:\Users\longyaosi\Documents\dreaminhotel\scripts\world\doorcontrol.gd`

**怪物场景文件**：
- `c:\Users\longyaosi\Documents\dreaminhotel\assets\monsters\MobA.tscn`

**门场景文件**：
- `c:\Users\longyaosi\Documents\dreaminhotel\scenes\world\hotel\wall+door\doorcontrol.tscn`

#### 注意事项

1. **分组检查**：
   - 怪物必须添加到 `"monster"` 分组
   - 玩家必须添加到 `"player"` 分组
   - 门的Area3D检测这两个分组

2. **碰撞层设置**：
   - 怪物的 `collision_layer = 2`
   - 门的 `collision_mask = 2`
   - 这样门才能检测到怪物

3. **方法调用**：
   - 门必须实现 `try_open_door(caller: Node)` 方法
   - 怪物必须实现 `register_door(door_node: Node)` 方法
   - 怪物必须实现 `unregister_door(door_node: Node)` 方法

4. **状态管理**：
   - 怪物只在追击状态或回到导航点时检查门
   - 攻击完成后结束追击
   - 追击时间12秒

5. **开门方向**：
   - 门根据 `last_side` 决定开门方向
   - 怪物进入内侧区域：`last_side = 1.0`
   - 怪物进入外侧区域：`last_side = -1.0`
   - 这样怪物不会夹死

6. **性能优化**：
   - 正常巡逻不计算路径，直接朝向巡逻点移动
   - 只有追击完成后回到导航点时才使用导航代理寻路
   - 巡逻点等待机制避免频繁切换

#### 经验总结

1. **Area3D检测**：使用Area3D检测附近的门，比射线检测更可靠
2. **状态机管理**：只在特定状态下检查门，避免不必要的性能开销
3. **分组系统**：使用分组系统快速定位游戏对象
4. **反向开门**：根据进入方向决定开门方向，避免怪物被夹死
5. **性能优化**：正常巡逻不计算路径，只在必要时使用导航代理
6. **等待机制**：巡逻点等待机制让怪物行为更自然