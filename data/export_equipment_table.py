from __future__ import annotations

from pathlib import Path
from zipfile import ZipFile
import json
import re
import subprocess
import xml.etree.ElementTree as ET

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_XLSX = PROJECT_ROOT / "execl" / "装备表.xlsx"
OUTPUT_DIR = PROJECT_ROOT / "assets" / "equipment" / "generated"
EQUIPMENT_DEFINITION_SCRIPT = "res://assets/equipment/equipment_definition.gd"
STAT_MODIFIER_CONFIG_SCRIPT = "res://scripts/stats/stat_modifier_config.gd"
SKILL_BASE_PATH = "res://abilities/skills/data"
DEFAULT_ICON_ATLAS_PATH = "res://assets/texture/all_icon.png"
DEFAULT_ICON_TILE_WIDTH = 16
DEFAULT_ICON_TILE_HEIGHT = 16
DEFAULT_ICON_TILE_COLUMNS = 16

NS = {
    "main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "rel": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "pkg_rel": "http://schemas.openxmlformats.org/package/2006/relationships",
}

STAT_FIELD_MAP = {
    "Atk": "attack",
    "Hp": "max_hp",
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


def load_sheet_rows_via_excel(sheet_name: str) -> list[list[str]]:
    script = f"""
import json
import win32com.client
from pathlib import Path

workbook_path = Path(r'''{SOURCE_XLSX}''')
excel = win32com.client.DispatchEx("Excel.Application")
excel.Visible = False
excel.DisplayAlerts = False
workbook = excel.Workbooks.Open(str(workbook_path))
try:
    sheet = workbook.Worksheets("{sheet_name}")
    used_range = sheet.UsedRange
    row_count = used_range.Rows.Count
    column_count = used_range.Columns.Count
    rows = []
    for row_index in range(1, row_count + 1):
        row_values = []
        for column_index in range(1, column_count + 1):
            value = sheet.Cells(row_index, column_index).Value
            if value is None:
                row_values.append("")
            else:
                row_values.append(str(value).strip())
        rows.append(row_values)
    print(json.dumps(rows, ensure_ascii=False))
finally:
    workbook.Close(False)
    excel.Quit()
""".strip()
    result = subprocess.run(
        ["python", "-c", script],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    return json.loads(result.stdout)


def load_sheet_rows(xlsx_path: Path, sheet_name: str) -> list[list[str]]:
    del xlsx_path
    try:
        return load_sheet_rows_via_excel(sheet_name)
    except Exception:
        with ZipFile(SOURCE_XLSX) as zip_file:
            shared_strings = load_shared_strings(zip_file)
            workbook_root = ET.fromstring(zip_file.read("xl/workbook.xml"))
            workbook_rels = ET.fromstring(zip_file.read("xl/_rels/workbook.xml.rels"))
            relation_id = None
            for sheet in workbook_root.findall("main:sheets/main:sheet", NS):
                if sheet.get("name") == sheet_name:
                    relation_id = sheet.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
                    break
            if relation_id is None:
                raise RuntimeError(f"装备表中未找到工作表: {sheet_name}")
            target_path = None
            for relation in workbook_rels.findall("pkg_rel:Relationship", NS):
                if relation.get("Id") == relation_id:
                    target_path = relation.get("Target")
                    break
            if not target_path:
                raise RuntimeError(f"找不到工作表 {sheet_name} 的关系路径")
            sheet_path = "xl/" + target_path.lstrip("/") if not target_path.startswith("xl/") else target_path
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


def parse_int(raw_value: str) -> int:
    if not raw_value:
        return 0
    return int(float(raw_value))


def parse_icon_tile_region(raw_value: str) -> tuple[int, int, int, int] | None:
    if not raw_value:
        return None
    normalized = raw_value.replace("，", ",").replace("|", ",").replace("_", ",").strip()
    if not normalized:
        return None
    parts = [part.strip() for part in normalized.split(",") if part.strip()]
    numeric_parts = [part for part in parts if re.fullmatch(r"-?\d+(?:\.\d+)?", part)]
    if len(parts) == 1 and len(numeric_parts) == 1:
        tile_index = parse_int(numeric_parts[0])
        column_index = tile_index % DEFAULT_ICON_TILE_COLUMNS
        row_index = tile_index // DEFAULT_ICON_TILE_COLUMNS
    elif len(numeric_parts) >= 2:
        column_index = parse_int(numeric_parts[0])
        row_index = parse_int(numeric_parts[1])
    else:
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
        if len(row) >= 12 and row[0] == "id" and row[1] == "name" and row[4] == "slot":
            header_index = index
            break
    if header_index is None:
        raise RuntimeError("装备表中未找到 id/name/slot 这一行表头")

    entries: list[dict[str, str]] = []
    for row in rows[header_index + 2 :]:
        if len(row) < 12:
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
                    "slot": row[4].strip(),
                    "quality": row[5].strip(),
                    "Atk": row[6].strip(),
                    "Hp": row[7].strip(),
                    "attrPool": row[8].strip(),
                    "skillPool": row[9].strip(),
                    "skillSp": row[10].strip(),
                    "setId": row[11].strip(),
                    "iconAtlas": row[12].strip() if len(row) > 12 else "",
                    "iconX": row[13].strip() if len(row) > 13 else "",
                    "iconY": row[14].strip() if len(row) > 14 else "",
                    "iconW": row[15].strip() if len(row) > 15 else "",
                    "iconH": row[16].strip() if len(row) > 16 else "",
                }
            )
        )
    return entries


def sanitize_file_name(name: str) -> str:
    slug = re.sub(r"[^0-9A-Za-z_\-]+", "_", name).strip("_").lower()
    return slug or "equipment"


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


def build_stat_modifier_blocks(entry: dict[str, str]) -> tuple[list[str], list[str]]:
    sub_resources: list[str] = []
    references: list[str] = []
    resource_index = 1
    for field_name, stat_id in STAT_FIELD_MAP.items():
        stat_value = parse_range_middle(entry.get(field_name, ""))
        if stat_value <= 0.0:
            continue
        sub_resource_id = f'SubResource("StatModifier_{resource_index}")'
        sub_resources.extend(
            [
                f'[sub_resource type="Resource" id="StatModifier_{resource_index}"]',
                f'script = ExtResource("2_stat_modifier_config")',
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
    if not skill_sp:
        return ext_resources, references
    skill_path = f'{SKILL_BASE_PATH}/{skill_sp}.tres'
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
        f'region = Rect2({icon_x}, {icon_y}, {icon_w}, {icon_h})',
        "",
    ]
    return ext_resources, sub_resources, 'SubResource("AtlasTexture_icon")'


def build_equipment_tres(entry: dict[str, str]) -> str:
    skill_resources, granted_skill_refs = build_granted_skills(entry)
    icon_resources, icon_sub_resources, icon_reference = build_icon_resources(entry, 3 + len(skill_resources))
    stat_modifier_blocks, stat_modifier_refs = build_stat_modifier_blocks(entry)
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
    lines.extend(
        [
            "[resource]",
            'script = ExtResource("1_equipment_definition")',
            f'equipment_id = &"{entry["id"]}"',
            f'display_name = "{entry["name"].replace("\\", "\\\\").replace("\"", "\\\"")}"',
            f'icon = {icon_reference}',
            f'rarity = {parse_quality(entry.get("quality", ""))}',
            f'slot_type = &"{entry["slot"].lower()}"',
            "granted_skills = Array[Resource]([%s])" % ", ".join(granted_skill_refs) if granted_skill_refs else "granted_skills = Array[Resource]([])",
            "stat_modifiers = Array[Resource]([%s])" % ", ".join(stat_modifier_refs) if stat_modifier_refs else "stat_modifiers = Array[Resource]([])",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    if not SOURCE_XLSX.exists():
        raise SystemExit(f"未找到装备表: {SOURCE_XLSX}")
    rows = load_sheet_rows(SOURCE_XLSX, "装备主表")
    entries = parse_equipment_table(rows)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    exported_count = 0
    for entry in entries:
        output_path = OUTPUT_DIR / f'{sanitize_file_name(entry["id"])}.tres'
        output_path.write_text(build_equipment_tres(entry), encoding="utf-8")
        exported_count += 1
    print(f"导出完成: assets/equipment/generated ({exported_count} 条)")


if __name__ == "__main__":
    main()
