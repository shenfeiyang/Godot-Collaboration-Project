extends Resource
class_name SkillArtConfig

## 技能美术表现包 —— 对应 skill.xlsx / skillArt sheet
## 定义技能的图标、特效、音效资源键值，一个美术包可被多个技能复用。

@export var art_pack_id: StringName = &""
## 图标资源键值，程序根据此键加载对应图集区域或独立贴图。
@export var icon_key: String = ""
## 特效资源键值，程序根据此键播放对应粒子或着色器效果。
@export var effect_key: String = ""
## 音效资源键值，程序根据此键播放对应音频。
@export var sound_key: String = ""
