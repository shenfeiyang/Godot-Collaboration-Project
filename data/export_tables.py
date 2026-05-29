from __future__ import annotations

from pathlib import Path
from zipfile import ZipFile
import argparse
import subprocess
import sys
import xml.etree.ElementTree as ET

PROJECT_ROOT = Path(__file__).resolve().parents[1]
EXCEL_DIR = PROJECT_ROOT / "execl"

NS = {
    "main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "rel": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "pkg_rel": "http://schemas.openxmlformats.org/package/2006/relationships",
}

STAT_FIELD_MAP = {
    "HPMax": "max_hp",
    "Atk": "attack",
    "DefMax": "defense",
    "Crit": "crit_rate",
    "CritD": "crit_damage",
    "PhysDS": "physical_damage_bonus",
    "WinDS": "wind_damage_bonus",
    "FireDS": "fire_damage_bonus",
    "IceDS": "ice_damage_bonus",
    "EleDS": "lightning_damage_bonus",
}

DEFAULT_PLAYER_VALUES = {
    "max_energy": 100.0,
    "energy_regen": 10.0,
    "move_speed": 120.0,
    "crit_rate": 0.05,
    "crit_damage": 0.5,
    "physical_damage_bonus": 0.0,
    "wind_damage_bonus": 0.0,
    "fire_damage_bonus": 0.15,
    "ice_damage_bonus": 0.0,
    "lightning_damage_bonus": 0.0,
    "light_damage_bonus": 0.0,
    "dark_damage_bonus": 0.0,
}

QUALITY_MAP = {
    "1": 1,
    "2": 2,
    "3": 3,
    "4": 4,
    "5": 5,
    "6": 6,
    "7": 7,
    "白": 1,
    "绿": 2,
    "蓝": 3,
    "紫": 4,
    "橙": 5,
    "红": 6,
    "金": 7,
    "white": 1,
    "green": 2,
    "blue": 3,
    "purple": 4,
    "orange": 5,
    "red": 6,
    "gold": 7,
}

EQUIPMENT_STAT_FIELD_MAP = {
    "Atk": "attack",
    "Hp": "max_hp",
}

ITEM_STAT_FIELD_MAP = {
    "HP": "max_hp",
    "HPMax": "max_hp",
    "Atk": "attack",
    "Def": "defense",
    "DefMax": "defense",
}

ITEM_TYPE_CATEGORY_MAP = {
    "1": (2, 16),
    "2": (2, 16),
    "3": (0, 16),
    "4": (0, 11),
    "5": (2, 16),
}

MONSTER_SCENE_MAP = {
    "xg": "res://characters/enemies/enemy_yellow.tscn",
    "jy": "res://characters/enemies/enemy_red.tscn",
    "bs": "res://characters/enemies/enemy_red.tscn",
}

DEFAULT_MONSTER_SPAWN_POSITIONS = [
    (8, 296),
    (8, 312),
    (8, 328),
    (8, 344),
    (792, 440),
    (792, 456),
    (792, 472),
    (792, 488),
]

TABLE_REGISTRY = {
    "stats": {
        "workbook": "attr.xlsx",
        "exporter": "stats",
        "runtime_ready": True,
        "description": "导出玩家基础属性资源",
    },
    "equipment": {
        "workbook": "equip.xlsx",
        "sheet": "equip",
        "exporter": "equipment",
        "runtime_ready": True,
        "description": "导出装备资源",
    },
    "item": {
        "workbook": "item.xlsx",
        "exporter": "item",
        "runtime_ready": True,
        "description": "导出背包物品资源",
    },
    "monster": {
        "workbook": "monster.xlsx",
        "exporter": "monster",
        "runtime_ready": True,
        "description": "导出怪物属性与默认刷怪配置资源",
    },
}

UNIT_STATS_CONFIG_SCRIPT = "res://scripts/stats/unit_stats_config.gd"
EQUIPMENT_DEFINITION_SCRIPT = "res://assets/equipment/equipment_definition.gd"
STAT_MODIFIER_CONFIG_SCRIPT = "res://scripts/stats/stat_modifier_config.gd"
INVENTORY_ITEM_DEFINITION_SCRIPT = "res://ui/inventory_item_definition.gd"
STAGE_SPAWN_CONFIG_SCRIPT = "res://scenes/config/stage_spawn_config.gd"
ENEMY_SPAWN_CONFIG_SCRIPT = "res://characters/enemies/enemy_spawn_config.gd"
SKILL_BASE_PATH = "res://abilities/skills/generated"
DEFAULT_ICON_ATLAS_PATH = "res://assets/texture/all_icon.png"
DEFAULT_ICON_TILE_WIDTH = 16
DEFAULT_ICON_TILE_HEIGHT = 16
DEFAULT_ICON_TILE_COLUMNS = 16
GENERATED_STATS_PATH = PROJECT_ROOT / "assets" / "stats" / "generated" / "player_stats_from_excel.tres"
GENERATED_EQUIPMENT_DIR = PROJECT_ROOT / "assets" / "equipment" / "generated"
GENERATED_ITEM_DIR = PROJECT_ROOT / "assets" / "items" / "generated"
GENERATED_MONSTER_STATS_DIR = PROJECT_ROOT / "assets" / "monsters" / "generated" / "stats"
GENERATED_MONSTER_STAGE_PATH = PROJECT_ROOT / "scenes" / "config" / "stages" / "generated" / "monster_stage_spawn_config.tres"


def column_letters_to_index(letters: str) -> int:
    index = 0
    for char in letters:
        index = index * 26 + (ord(char.upper()) - ord("A") + 1)
    return index - 1


def get_cell_text(cell: ET.Element, shared_strings: list[str]) -> str:
    cell_type = cell.get("t")
    value_node = cell.find("main:v", NS)
    if value_node is None or value_node.text is None:
        return ""
    raw_value = value_node.text.strip()
    if cell_type == "s":
        return shared_strings[int(raw_value)]
    return raw_value


def load_shared_strings(zip_file: ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in zip_file.namelist():
        return []
    root = ET.fromstring(zip_file.read("xl/sharedStrings.xml"))
    strings: list[str] = []
    for string_item in root.findall("main:si", NS):
        text_parts = [node.text or "" for node in string_item.findall(".//main:t", NS)]
        strings.append("".join(text_parts))
    return strings


def _resolve_sheet_path(zip_file: ZipFile, sheet_name: str | None) -> str:
    workbook_root = ET.fromstring(zip_file.read("xl/workbook.xml"))
    workbook_rels = ET.fromstring(zip_file.read("xl/_rels/workbook.xml.rels"))
    relation_id = None
    if sheet_name is None:
        first_sheet = workbook_root.find("main:sheets/main:sheet", NS)
        if first_sheet is None:
            raise RuntimeError("工作簿中不包含任何工作表")
        relation_id = first_sheet.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
    else:
        for sheet in workbook_root.findall("main:sheets/main:sheet", NS):
            if sheet.get("name") == sheet_name:
                relation_id = sheet.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
                break
        if relation_id is None:
            raise RuntimeError(f"工作簿中未找到工作表: {sheet_name}")
    target_path = None
    for relation in workbook_rels.findall("pkg_rel:Relationship", NS):
        if relation.get("Id") == relation_id:
            target_path = relation.get("Target")
            break
    if not target_path:
        if sheet_name is None:
            raise RuntimeError("找不到首个工作表的关系路径")
        raise RuntimeError(f"找不到工作表 {sheet_name} 的关系路径")
    return "xl/" + target_path.lstrip("/") if not target_path.startswith("xl/") else target_path


def load_sheet_rows_from_zip(xlsx_path: Path, sheet_name: str | None) -> list[list[str]]:
    with ZipFile(xlsx_path) as zip_file:
        shared_strings = load_shared_strings(zip_file)
        sheet_path = _resolve_sheet_path(zip_file, sheet_name)
        sheet_root = ET.fromstring(zip_file.read(sheet_path))
        rows: list[list[str]] = []
        for row in sheet_root.findall("main:sheetData/main:row", NS):
            row_values: list[str] = []
            for cell in row.findall("main:c", NS):
                cell_ref = cell.get("r", "")
                column_letters = "".join(char for char in cell_ref if char.isalpha())
                column_index = column_letters_to_index(column_letters)
                while len(row_values) <= column_index:
                    row_values.append("")
                row_values[column_index] = get_cell_text(cell, shared_strings)
            rows.append(row_values)
        return rows


def load_sheet_rows_via_excel(xlsx_path: Path, sheet_name: str) -> list[list[str]]:
    script = f"""
import json
import win32com.client
from pathlib import Path

workbook_path = Path(r'''{xlsx_path}''')
excel = win32com.client.DispatchEx('Excel.Application')
excel.Visible = False
excel.DisplayAlerts = False
workbook = excel.Workbooks.Open(str(workbook_path))
try:
    sheet = workbook.Worksheets('{sheet_name}')
    used_range = sheet.UsedRange
    row_count = used_range.Rows.Count
    column_count = used_range.Columns.Count
    rows = []
    for row_index in range(1, row_count + 1):
        row_values = []
        for column_index in range(1, column_count + 1):
            value = sheet.Cells(row_index, column_index).Value
            row_values.append('' if value is None else str(value).strip())
        rows.append(row_values)
    print(json.dumps(rows, ensure_ascii=False))
finally:
    workbook.Close(False)
    excel.Quit()
""".strip()
    result = subprocess.run(
        [sys.executable, "-c", script],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    import json

    return json.loads(result.stdout)


def load_sheet_rows(xlsx_path: Path, sheet_name: str | None = None, prefer_excel: bool = False) -> list[list[str]]:
    if prefer_excel and sheet_name is not None:
        try:
            return load_sheet_rows_via_excel(xlsx_path, sheet_name)
        except Exception:
            pass
    return load_sheet_rows_from_zip(xlsx_path, sheet_name)


def parse_stat_table(rows: list[list[str]]) -> dict[str, dict[str, str]]:
    header_index = None
    for index, row in enumerate(rows):
        if len(row) >= 7 and row[0] == "id" and row[1] == "name" and row[3] == "type" and row[4] == "base":
            header_index = index
            break
    if header_index is None:
        raise RuntimeError("属性表中未找到 id/name/type/base 这一行表头")

    parsed_stats: dict[str, dict[str, str]] = {}
    for row in rows[header_index + 2 :]:
        if len(row) < 5:
            continue
        stat_id = row[0].strip()
        stat_name = row[1].strip()
        base_value = row[4].strip()
        if not stat_id or not stat_name:
            continue
        parsed_stats[stat_name] = {
            "id": stat_id,
            "name": stat_name,
            "desc": row[2].strip() if len(row) > 2 else "",
            "type": row[3].strip() if len(row) > 3 else "",
            "base": base_value,
            "min": row[5].strip() if len(row) > 5 else "",
            "max": row[6].strip() if len(row) > 6 else "",
            "remark": row[7].strip() if len(row) > 7 else "",
        }
    return parsed_stats


def build_player_stats_values(parsed_stats: dict[str, dict[str, str]]) -> dict[str, float]:
    values: dict[str, float] = dict(DEFAULT_PLAYER_VALUES)
    missing_fields: list[str] = []
    for table_name, output_field in STAT_FIELD_MAP.items():
        stat_entry = parsed_stats.get(table_name)
        if stat_entry is None:
            missing_fields.append(table_name)
            continue
        raw_base_value = stat_entry["base"]
        if not raw_base_value:
            continue
        value = float(raw_base_value)
        if stat_entry.get("type") == "2":
            value /= 10000.0
        if output_field == "crit_damage":
            value -= 1.0
        values[output_field] = value
    if missing_fields:
        raise RuntimeError("属性表缺少必要字段: %s" % ", ".join(missing_fields))
    return values


def format_float(value: float) -> str:
    return f"{value:.1f}"


def build_unit_stats_tres(values: dict[str, float]) -> str:
    lines = [
        '[gd_resource type="Resource" script_class="UnitStatsConfig" format=3]',
        "",
        f'[ext_resource type="Script" path="{UNIT_STATS_CONFIG_SCRIPT}" id="1_unit_stats_config"]',
        "",
        "[resource]",
        'script = ExtResource("1_unit_stats_config")',
    ]
    ordered_fields = [
        "max_hp",
        "attack",
        "defense",
        "crit_rate",
        "crit_damage",
        "max_energy",
        "energy_regen",
        "move_speed",
        "attack_speed",
        "physical_damage_bonus",
        "wind_damage_bonus",
        "fire_damage_bonus",
        "ice_damage_bonus",
        "lightning_damage_bonus",
        "light_damage_bonus",
        "dark_damage_bonus",
    ]
    for field_name in ordered_fields:
        if field_name not in values:
            continue
        lines.append(f"{field_name} = {format_float(values[field_name])}")
    lines.append("")
    return "\n".join(lines)


def parse_int(raw_value: str) -> int:
    if not raw_value:
        return 0
    return int(float(raw_value))


def parse_range_middle(raw_value: str) -> float:
    if not raw_value:
        return 0.0
    parts = [part.strip() for part in raw_value.split("|") if part.strip()]
    if not parts:
        return 0.0
    if len(parts) == 1:
        return float(parts[0])
    return (float(parts[0]) + float(parts[1])) / 2.0


def parse_quality(raw_value: str) -> int:
    normalized = raw_value.strip().lower()
    if not normalized:
        return 1
    return QUALITY_MAP.get(normalized, 1)


def parse_icon_tile_region(raw_value: str) -> tuple[int, int, int, int] | None:
    if not raw_value:
        return None
    normalized = raw_value.replace("，", ",").replace("|", ",").replace("_", ",").strip()
    if not normalized:
        return None
    parts = [part.strip() for part in normalized.split(",") if part.strip()]
    numeric_parts = [part for part in parts if part.replace(".", "", 1).lstrip("-").isdigit()]
    if len(parts) == 1 and len(numeric_parts) == 1:
        tile_index = parse_int(numeric_parts[0])
        column_index = tile_index % DEFAULT_ICON_TILE_COLUMNS
        row_index = tile_index // DEFAULT_ICON_TILE_COLUMNS
    elif len(numeric_parts) >= 2:
        column_index = parse_int(numeric_parts[0])
        row_index = parse_int(numeric_parts[1])
    else:
        import re

        matched_numbers = re.findall(r"\d+", raw_value)
        if not matched_numbers:
            return None
        tile_number = int(matched_numbers[-1])
        tile_index = max(tile_number - 1, 0)
        column_index = tile_index % DEFAULT_ICON_TILE_COLUMNS
        row_index = tile_index // DEFAULT_ICON_TILE_COLUMNS
    return (
        column_index * DEFAULT_ICON_TILE_WIDTH,
        row_index * DEFAULT_ICON_TILE_HEIGHT,
        DEFAULT_ICON_TILE_WIDTH,
        DEFAULT_ICON_TILE_HEIGHT,
    )


def normalize_icon_fields(entry: dict[str, str]) -> dict[str, str]:
    normalized_entry = dict(entry)
    if normalized_entry.get("iconAtlas"):
        return normalized_entry
    icon_region = parse_icon_tile_region(normalized_entry.get("icon", ""))
    if icon_region is None:
        return normalized_entry
    icon_x, icon_y, icon_w, icon_h = icon_region
    normalized_entry["iconAtlas"] = DEFAULT_ICON_ATLAS_PATH
    normalized_entry["iconX"] = str(icon_x)
    normalized_entry["iconY"] = str(icon_y)
    normalized_entry["iconW"] = str(icon_w)
    normalized_entry["iconH"] = str(icon_h)
    return normalized_entry


def parse_equipment_table(rows: list[list[str]]) -> list[dict[str, str]]:
    header_index = None
    for index, row in enumerate(rows):
        if len(row) >= 13 and row[0] == "id" and row[1] == "name" and row[5] == "slot":
            header_index = index
            break
    if header_index is None:
        raise RuntimeError("装备表中未找到 id/name/slot 这一行表头")

    entries: list[dict[str, str]] = []
    for row in rows[header_index + 2 :]:
        if len(row) < 13:
            continue
        equipment_id = row[0].strip()
        display_name = row[1].strip()
        if not equipment_id or not display_name:
            continue
        entries.append(
            normalize_icon_fields(
                {
                    "id": equipment_id,
                    "name": display_name,
                    "icon": row[2].strip(),
                    "class": row[3].strip(),
                    "slot": row[5].strip(),
                    "quality": row[6].strip(),
                    "Atk": row[7].strip(),
                    "Hp": row[8].strip(),
                    "skillAtk": row[9].strip(),
                    "attrPool": row[10].strip(),
                    "skillPool": row[11].strip(),
                    "skillSp": row[12].strip(),
                    "setId": row[13].strip() if len(row) > 13 else "",
                    "iconAtlas": row[14].strip() if len(row) > 14 else "",
                    "iconX": row[15].strip() if len(row) > 15 else "",
                    "iconY": row[16].strip() if len(row) > 16 else "",
                    "iconW": row[17].strip() if len(row) > 17 else "",
                    "iconH": row[18].strip() if len(row) > 18 else "",
                }
            )
        )
    return entries


def parse_item_table(rows: list[list[str]]) -> list[dict[str, str]]:
    header_index = None
    for index, row in enumerate(rows):
        if len(row) >= 16 and row[0] == "id" and row[1] == "name" and row[4] == "type":
            header_index = index
            break
    if header_index is None:
        raise RuntimeError("item 表中未找到 id/name/type 这一行表头")

    entries: list[dict[str, str]] = []
    for row in rows[header_index + 2 :]:
        if len(row) < 12:
            continue
        item_id = row[0].strip()
        display_name = row[1].strip()
        if not item_id or not display_name:
            continue
        entries.append(
            normalize_icon_fields(
                {
                    "id": item_id,
                    "name": display_name,
                    "des": row[2].strip(),
                    "icon": row[3].strip(),
                    "type": row[4].strip(),
                    "quality": row[5].strip(),
                    "sell": row[6].strip(),
                    "use": row[7].strip(),
                    "useP1": row[8].strip(),
                    "consume": row[9].strip(),
                    "stack": row[10].strip(),
                    "unique": row[11].strip(),
                    "p1": row[12].strip() if len(row) > 12 else "",
                    "p2": row[13].strip() if len(row) > 13 else "",
                    "pdbz1": row[14].strip() if len(row) > 14 else "",
                    "pdbz2": row[15].strip() if len(row) > 15 else "",
                    "iconAtlas": row[16].strip() if len(row) > 16 else "",
                    "iconX": row[17].strip() if len(row) > 17 else "",
                    "iconY": row[18].strip() if len(row) > 18 else "",
                    "iconW": row[19].strip() if len(row) > 19 else "",
                    "iconH": row[20].strip() if len(row) > 20 else "",
                }
            )
        )
    return entries


def parse_monster_table(rows: list[list[str]]) -> list[dict[str, str]]:
    header_index = None
    for index, row in enumerate(rows):
        if len(row) >= 13 and row[0] == "id" and row[1] == "name" and row[3] == "HP" and row[4] == "Atk":
            header_index = index
            break
    if header_index is None:
        raise RuntimeError("monster 表中未找到 id/name/HP/Atk 这一行表头")

    entries: list[dict[str, str]] = []
    for row in rows[header_index + 2 :]:
        if len(row) < 13:
            continue
        monster_id = row[0].strip()
        display_name = row[1].strip()
        if not monster_id or not display_name:
            continue
        entries.append(
            {
                "id": monster_id,
                "name": display_name,
                "battleModel": row[2].strip(),
                "HP": row[3].strip(),
                "Atk": row[4].strip(),
                "type1": row[5].strip(),
                "type2": row[6].strip(),
                "type3": row[7].strip(),
                "tag": row[8].strip(),
                "moveSpeed": row[9].strip(),
                "maxMoveSpeed": row[10].strip(),
                "ratio": row[11].strip(),
                "skill": row[12].strip(),
            }
        )
    return entries


def sanitize_file_name(name: str) -> str:
    import re

    slug = re.sub(r"[^0-9A-Za-z_\-]+", "_", name).strip("_").lower()
    return slug or "resource"


def escape_text(raw_value: str) -> str:
    return raw_value.replace("\\", "\\\\").replace('"', '\\"')


def build_stat_modifier_blocks(entry: dict[str, str], field_map: dict[str, str]) -> tuple[list[str], list[str]]:
    sub_resources: list[str] = []
    references: list[str] = []
    resource_index = 1
    for field_name, stat_id in field_map.items():
        stat_value = parse_range_middle(entry.get(field_name, ""))
        if stat_value <= 0.0:
            continue
        sub_resource_id = f'SubResource("StatModifier_{resource_index}")'
        sub_resources.extend(
            [
                f'[sub_resource type="Resource" id="StatModifier_{resource_index}"]',
                'script = ExtResource("2_stat_modifier_config")',
                f'stat_id = &"{stat_id}"',
                "operation = 0",
                f"value = {stat_value:.1f}",
                "",
            ]
        )
        references.append(sub_resource_id)
        resource_index += 1
    return sub_resources, references


def build_granted_skills(entry: dict[str, str]) -> tuple[list[str], list[str]]:
    ext_resources: list[str] = []
    references: list[str] = []
    resource_index = 3
    skill_sp = entry.get("skillSp", "")
    if not skill_sp or skill_sp == "sk_ID":
        return ext_resources, references
    skill_path = f"{SKILL_BASE_PATH}/{skill_sp}.tres"
    ext_resources.append(
        f'[ext_resource type="Resource" path="{skill_path}" id="{resource_index}_skill_definition"]'
    )
    references.append(f'ExtResource("{resource_index}_skill_definition")')
    return ext_resources, references


def build_icon_resources(entry: dict[str, str], next_resource_index: int) -> tuple[list[str], list[str], str]:
    icon_atlas = entry.get("iconAtlas", "")
    if not icon_atlas:
        return [], [], "null"
    icon_x = parse_int(entry.get("iconX", "0"))
    icon_y = parse_int(entry.get("iconY", "0"))
    icon_w = parse_int(entry.get("iconW", "0"))
    icon_h = parse_int(entry.get("iconH", "0"))
    ext_resource_id = f"{next_resource_index}_icon_atlas"
    ext_resources = [f'[ext_resource type="Texture2D" path="{icon_atlas}" id="{ext_resource_id}"]']
    sub_resources = [
        '[sub_resource type="AtlasTexture" id="AtlasTexture_icon"]',
        f'atlas = ExtResource("{ext_resource_id}")',
        f"region = Rect2({icon_x}, {icon_y}, {icon_w}, {icon_h})",
        "",
    ]
    return ext_resources, sub_resources, 'SubResource("AtlasTexture_icon")'


def build_equipment_tres(entry: dict[str, str]) -> str:
    skill_resources, granted_skill_refs = build_granted_skills(entry)
    icon_resources, icon_sub_resources, icon_reference = build_icon_resources(entry, 3 + len(skill_resources))
    stat_modifier_blocks, stat_modifier_refs = build_stat_modifier_blocks(entry, EQUIPMENT_STAT_FIELD_MAP)
    lines = [
        '[gd_resource type="Resource" script_class="EquipmentDefinition" format=3]',
        "",
        f'[ext_resource type="Script" path="{EQUIPMENT_DEFINITION_SCRIPT}" id="1_equipment_definition"]',
        f'[ext_resource type="Script" path="{STAT_MODIFIER_CONFIG_SCRIPT}" id="2_stat_modifier_config"]',
    ]
    if skill_resources:
        lines.extend(skill_resources)
    if icon_resources:
        lines.extend(icon_resources)
    lines.append("")
    if icon_sub_resources:
        lines.extend(icon_sub_resources)
    if stat_modifier_blocks:
        lines.extend(stat_modifier_blocks)
    safe_name = escape_text(entry["name"])
    lines.extend(
        [
            "[resource]",
            'script = ExtResource("1_equipment_definition")',
            f'equipment_id = &"{entry["id"]}"',
            f'display_name = "{safe_name}"',
            f"icon = {icon_reference}",
            f'rarity = {parse_quality(entry.get("quality", ""))}',
            f'slot_type = &"{entry["slot"].lower()}"',
            "granted_skills = Array[Resource]([%s])" % ", ".join(granted_skill_refs) if granted_skill_refs else "granted_skills = Array[Resource]([])",
            "stat_modifiers = Array[Resource]([%s])" % ", ".join(stat_modifier_refs) if stat_modifier_refs else "stat_modifiers = Array[Resource]([])",
            "",
        ]
    )
    return "\n".join(lines)


def resolve_item_category(raw_type: str) -> tuple[int, int]:
    return ITEM_TYPE_CATEGORY_MAP.get(raw_type.strip(), (2, 16))


def resolve_item_max_stack(entry: dict[str, str], category: int) -> int:
    if parse_int(entry.get("unique", "")) > 0:
        return 1
    configured_stack = parse_int(entry.get("stack", ""))
    if configured_stack > 0:
        return configured_stack
    if category == 2:
        return 9999
    return 99


def build_item_stat_modifier_blocks(entry: dict[str, str]) -> tuple[list[str], list[str]]:
    normalized_entry: dict[str, str] = {}
    for index, field_name in enumerate(("p1", "p2"), start=1):
        raw_value = entry.get(field_name, "")
        if not raw_value:
            continue
        parts = [part.strip() for part in raw_value.split("|") if part.strip()]
        if len(parts) < 2:
            continue
        if parts[0] not in ITEM_STAT_FIELD_MAP:
            continue
        normalized_entry[f"item_{index}"] = raw_value
    translated_entry = {}
    for key, raw_value in normalized_entry.items():
        parts = [part.strip() for part in raw_value.split("|") if part.strip()]
        translated_entry[key] = parts[1]
    translated_map = {}
    for index, field_name in enumerate(("p1", "p2"), start=1):
        raw_value = entry.get(field_name, "")
        parts = [part.strip() for part in raw_value.split("|") if part.strip()]
        if len(parts) < 2:
            continue
        stat_id = ITEM_STAT_FIELD_MAP.get(parts[0])
        if stat_id is None:
            continue
        translated_map[field_name] = stat_id
        translated_entry[field_name] = parts[1]
    return build_stat_modifier_blocks(translated_entry, translated_map)


def build_item_tres(entry: dict[str, str]) -> str:
    category, subcategory = resolve_item_category(entry.get("type", ""))
    max_stack = resolve_item_max_stack(entry, category)
    stat_modifier_blocks, stat_modifier_refs = build_item_stat_modifier_blocks(entry)
    icon_resources, icon_sub_resources, icon_reference = build_icon_resources(entry, 3)
    lines = [
        '[gd_resource type="Resource" script_class="InventoryItemDefinition" format=3]',
        "",
        f'[ext_resource type="Script" path="{INVENTORY_ITEM_DEFINITION_SCRIPT}" id="1_inventory_item_definition"]',
        f'[ext_resource type="Script" path="{STAT_MODIFIER_CONFIG_SCRIPT}" id="2_stat_modifier_config"]',
    ]
    if icon_resources:
        lines.extend(icon_resources)
    lines.append("")
    if icon_sub_resources:
        lines.extend(icon_sub_resources)
    if stat_modifier_blocks:
        lines.extend(stat_modifier_blocks)
    safe_name = escape_text(entry["name"])
    safe_description = escape_text(entry.get("des", ""))
    lines.extend(
        [
            "[resource]",
            'script = ExtResource("1_inventory_item_definition")',
            f'item_id = &"{entry["id"]}"',
            f'display_name = "{safe_name}"',
            f'icon = {icon_reference}',
            f"category = {category}",
            f"subcategory = {subcategory}",
            f'rarity = {parse_quality(entry.get("quality", ""))}',
            f'description = "{safe_description}"',
            f"max_stack = {max_stack}",
            "equip_slot = 0",
            "stat_modifiers = Array[Resource]([%s])" % ", ".join(stat_modifier_refs) if stat_modifier_refs else "stat_modifiers = Array[Resource]([])",
            "",
        ]
    )
    return "\n".join(lines)


def build_monster_stats_values(entry: dict[str, str]) -> dict[str, float]:
    values: dict[str, float] = {}
    if entry.get("HP"):
        values["max_hp"] = float(entry["HP"])
    if entry.get("Atk"):
        values["attack"] = float(entry["Atk"])
    move_speed_value = entry.get("maxMoveSpeed") or entry.get("moveSpeed")
    if move_speed_value:
        values["move_speed"] = float(move_speed_value)
    return values


def resolve_monster_scene_path(entry: dict[str, str]) -> str:
    scene_key = entry.get("type1", "").strip().lower()
    if scene_key in MONSTER_SCENE_MAP:
        return MONSTER_SCENE_MAP[scene_key]
    raise RuntimeError(f'monster 表中的怪物 {entry.get("id", "")} 使用了未映射的 type1: {entry.get("type1", "")}')


def build_monster_stage_spawn_tres(entries: list[dict[str, str]]) -> str:
    lines = [
        '[gd_resource type="Resource" script_class="StageSpawnConfig" format=3]',
        "",
        f'[ext_resource type="Script" path="{STAGE_SPAWN_CONFIG_SCRIPT}" id="1_stage_spawn_config"]',
        f'[ext_resource type="Script" path="{ENEMY_SPAWN_CONFIG_SCRIPT}" id="2_enemy_spawn_config"]',
    ]
    scene_ext_ids: dict[str, str] = {}
    stats_ext_ids: dict[str, str] = {}
    next_ext_index = 3
    for entry in entries:
        scene_path = resolve_monster_scene_path(entry)
        if scene_path not in scene_ext_ids:
            scene_ext_ids[scene_path] = f"{next_ext_index}_enemy_scene"
            lines.append(f'[ext_resource type="PackedScene" path="{scene_path}" id="{scene_ext_ids[scene_path]}"]')
            next_ext_index += 1
        stats_path = f'res://assets/monsters/generated/stats/{sanitize_file_name(entry["id"])}.tres'
        stats_ext_ids[stats_path] = f"{next_ext_index}_enemy_stats"
        lines.append(f'[ext_resource type="Resource" path="{stats_path}" id="{stats_ext_ids[stats_path]}"]')
        next_ext_index += 1
    lines.append("")

    sub_resource_refs: list[str] = []
    for index, entry in enumerate(entries, start=1):
        scene_path = resolve_monster_scene_path(entry)
        stats_path = f'res://assets/monsters/generated/stats/{sanitize_file_name(entry["id"])}.tres'
        sub_resource_id = f"{index}_enemy_wave"
        lines.extend(
            [
                f'[sub_resource type="Resource" id="{sub_resource_id}"]',
                'script = ExtResource("2_enemy_spawn_config")',
                f'enemy_scene = ExtResource("{scene_ext_ids[scene_path]}")',
                f'base_stats_config = ExtResource("{stats_ext_ids[stats_path]}")',
                "spawn_count = 1",
                "",
            ]
        )
        sub_resource_refs.append(f'SubResource("{sub_resource_id}")')

    position_text = ", ".join(f"Vector2({x}, {y})" for x, y in DEFAULT_MONSTER_SPAWN_POSITIONS)
    lines.extend(
        [
            "[resource]",
            'script = ExtResource("1_stage_spawn_config")',
            "enemy_configs = Array[ExtResource(\"2_enemy_spawn_config\")]([%s])" % ", ".join(sub_resource_refs),
            f"initial_spawn_positions = Array[Vector2]([{position_text}])",
            "spawn_on_ready = true",
            "continuous_spawn = false",
            "spawn_interval = 1.5",
            f"max_alive_enemies = {max(len(entries), 1)}",
            "",
        ]
    )
    return "\n".join(lines)


def export_stats(clean: bool = False) -> list[str]:
    workbook_path = EXCEL_DIR / TABLE_REGISTRY["stats"]["workbook"]
    if not workbook_path.exists():
        raise RuntimeError(f"未找到属性表: {workbook_path}")
    if clean and GENERATED_STATS_PATH.exists():
        GENERATED_STATS_PATH.unlink()
    rows = load_sheet_rows(workbook_path)
    parsed_stats = parse_stat_table(rows)
    player_values = build_player_stats_values(parsed_stats)
    GENERATED_STATS_PATH.parent.mkdir(parents=True, exist_ok=True)
    GENERATED_STATS_PATH.write_text(build_unit_stats_tres(player_values), encoding="utf-8")
    return [str(GENERATED_STATS_PATH.relative_to(PROJECT_ROOT))]


def export_equipment(clean: bool = False) -> list[str]:
    workbook_path = EXCEL_DIR / TABLE_REGISTRY["equipment"]["workbook"]
    if not workbook_path.exists():
        raise RuntimeError(f"未找到装备表: {workbook_path}")
    rows = load_sheet_rows(workbook_path, TABLE_REGISTRY["equipment"]["sheet"])
    entries = parse_equipment_table(rows)
    GENERATED_EQUIPMENT_DIR.mkdir(parents=True, exist_ok=True)
    if clean and GENERATED_EQUIPMENT_DIR.exists():
        for file_path in GENERATED_EQUIPMENT_DIR.glob("*.tres"):
            file_path.unlink()
    exported_paths: list[str] = []
    for entry in entries:
        output_path = GENERATED_EQUIPMENT_DIR / f'{sanitize_file_name(entry["id"])}.tres'
        output_path.write_text(build_equipment_tres(entry), encoding="utf-8")
        exported_paths.append(str(output_path.relative_to(PROJECT_ROOT)))
    return exported_paths


def export_item(clean: bool = False) -> list[str]:
    workbook_path = EXCEL_DIR / TABLE_REGISTRY["item"]["workbook"]
    if not workbook_path.exists():
        raise RuntimeError(f"未找到 item 表: {workbook_path}")
    rows = load_sheet_rows(workbook_path)
    entries = parse_item_table(rows)
    GENERATED_ITEM_DIR.mkdir(parents=True, exist_ok=True)
    if clean and GENERATED_ITEM_DIR.exists():
        for file_path in GENERATED_ITEM_DIR.glob("*.tres"):
            file_path.unlink()
    exported_paths: list[str] = []
    for entry in entries:
        output_path = GENERATED_ITEM_DIR / f'{sanitize_file_name(entry["id"])}.tres'
        output_path.write_text(build_item_tres(entry), encoding="utf-8")
        exported_paths.append(str(output_path.relative_to(PROJECT_ROOT)))
    return exported_paths


def export_monster(clean: bool = False) -> list[str]:
    workbook_path = EXCEL_DIR / TABLE_REGISTRY["monster"]["workbook"]
    if not workbook_path.exists():
        raise RuntimeError(f"未找到 monster 表: {workbook_path}")
    rows = load_sheet_rows(workbook_path)
    entries = parse_monster_table(rows)
    GENERATED_MONSTER_STATS_DIR.mkdir(parents=True, exist_ok=True)
    GENERATED_MONSTER_STAGE_PATH.parent.mkdir(parents=True, exist_ok=True)
    if clean and GENERATED_MONSTER_STATS_DIR.exists():
        for file_path in GENERATED_MONSTER_STATS_DIR.glob("*.tres"):
            file_path.unlink()
        if GENERATED_MONSTER_STAGE_PATH.exists():
            GENERATED_MONSTER_STAGE_PATH.unlink()
    exported_paths: list[str] = []
    for entry in entries:
        stat_values = build_monster_stats_values(entry)
        if "max_hp" not in stat_values or "attack" not in stat_values:
            raise RuntimeError(f'monster 表中的怪物 {entry["id"]} 缺少 HP 或 Atk')
        output_path = GENERATED_MONSTER_STATS_DIR / f'{sanitize_file_name(entry["id"])}.tres'
        output_path.write_text(build_unit_stats_tres(stat_values), encoding="utf-8")
        exported_paths.append(str(output_path.relative_to(PROJECT_ROOT)))
    GENERATED_MONSTER_STAGE_PATH.write_text(build_monster_stage_spawn_tres(entries), encoding="utf-8")
    exported_paths.append(str(GENERATED_MONSTER_STAGE_PATH.relative_to(PROJECT_ROOT)))
    return exported_paths


def list_tables() -> None:
    for table_name, config in TABLE_REGISTRY.items():
        runtime_label = "runtime-ready" if config["runtime_ready"] else "placeholder"
        print(f"{table_name}: {config['workbook']} [{runtime_label}] - {config['description']}")


def resolve_export_targets(target: str) -> list[str]:
    if target == "all":
        return list(TABLE_REGISTRY.keys())
    if target == "runtime":
        return [name for name, config in TABLE_REGISTRY.items() if config["runtime_ready"]]
    if target in TABLE_REGISTRY:
        return [target]
    raise RuntimeError(f"未知导出目标: {target}")


def export_target(target: str, clean: bool = False) -> None:
    exported_summary: dict[str, list[str]] = {}
    for table_name in resolve_export_targets(target):
        config = TABLE_REGISTRY[table_name]
        exporter = config["exporter"]
        if exporter == "stats":
            exported_summary[table_name] = export_stats(clean=clean)
        elif exporter == "equipment":
            exported_summary[table_name] = export_equipment(clean=clean)
        elif exporter == "item":
            exported_summary[table_name] = export_item(clean=clean)
        elif exporter == "monster":
            exported_summary[table_name] = export_monster(clean=clean)
        else:
            raise RuntimeError(f"未实现的导出器: {exporter}")
    for table_name, exported_paths in exported_summary.items():
        if exported_paths:
            print(f"{table_name}: 导出 {len(exported_paths)} 个文件")
            for path in exported_paths:
                print(f"  - {path}")
        else:
            print(f"{table_name}: 无导出文件")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="统一导表工具")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("list", help="列出已注册表")

    export_parser = subparsers.add_parser("export", help="导出指定表或表组")
    export_parser.add_argument("target", help="stats / equipment / runtime / all / item / monster")
    export_parser.add_argument("--clean", action="store_true", help="导出前清理现有 generated 产物")

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    try:
        if args.command == "list":
            list_tables()
            return
        if args.command == "export":
            export_target(args.target, clean=bool(args.clean))
            return
        raise RuntimeError(f"不支持的命令: {args.command}")
    except Exception as exc:
        raise SystemExit(str(exc))


if __name__ == "__main__":
    main()
