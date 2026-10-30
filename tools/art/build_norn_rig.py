"""Build a locally rigged Norn candidate from the preserved Meshy GLB.

The script has no write mode unless ``--build`` is explicit. It stages its
outputs under the repository root, checks the exported GLB, and refuses to
replace any existing destination.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import bpy
from mathutils import Vector


SOURCE_LICENSE = "LicenseRef-Meshy-Private"
EXPECTED_CLIPS = ("idle", "walk", "curious", "praised", "scolded")
EXPECTED_VERTEX_ATTRIBUTES = {"POSITION", "NORMAL", "TANGENT", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"}

# Blender imports glTF with Z up. The Norn's face points toward negative Y.
# Bone positions are fitted to the inspected source bounds:
# X=[-0.350, 0.348], Y=[-0.389, 0.389], Z=[-0.476, 0.475].
BONES: tuple[dict[str, Any], ...] = (
    {"name": "root", "head": (0.0, 0.0, -0.46), "tail": (0.0, 0.0, -0.33), "parent": None, "radius": 0.16},
    {"name": "pelvis", "head": (0.0, 0.11, -0.25), "tail": (0.0, 0.03, -0.13), "parent": "root", "radius": 0.17},
    {"name": "spine", "head": (0.0, 0.03, -0.13), "tail": (0.0, -0.02, -0.02), "parent": "pelvis", "radius": 0.17},
    {"name": "chest", "head": (0.0, -0.02, -0.02), "tail": (0.0, -0.04, 0.09), "parent": "spine", "radius": 0.17},
    {"name": "neck", "head": (0.0, -0.04, 0.08), "tail": (0.0, -0.05, 0.18), "parent": "chest", "radius": 0.16},
    {"name": "head", "head": (0.0, -0.05, 0.16), "tail": (0.0, -0.05, 0.36), "parent": "neck", "radius": 0.27},
    {"name": "ear.L", "head": (-0.16, -0.04, 0.31), "tail": (-0.23, -0.04, 0.40), "parent": "head", "radius": 0.105},
    {"name": "ear_tip.L", "head": (-0.23, -0.04, 0.40), "tail": (-0.30, -0.04, 0.47), "parent": "ear.L", "radius": 0.105},
    {"name": "ear.R", "head": (0.16, -0.04, 0.31), "tail": (0.23, -0.04, 0.40), "parent": "head", "radius": 0.105},
    {"name": "ear_tip.R", "head": (0.23, -0.04, 0.40), "tail": (0.30, -0.04, 0.47), "parent": "ear.R", "radius": 0.105},
    {"name": "arm_upper.L", "head": (-0.085, -0.04, 0.00), "tail": (-0.105, -0.13, -0.19), "parent": "chest", "radius": 0.13},
    {"name": "arm_lower.L", "head": (-0.105, -0.13, -0.19), "tail": (-0.105, -0.12, -0.34), "parent": "arm_upper.L", "radius": 0.115},
    {"name": "paw.L", "head": (-0.105, -0.12, -0.34), "tail": (-0.15, -0.06, -0.45), "parent": "arm_lower.L", "radius": 0.12},
    {"name": "arm_upper.R", "head": (0.085, -0.04, 0.00), "tail": (0.105, -0.13, -0.19), "parent": "chest", "radius": 0.13},
    {"name": "arm_lower.R", "head": (0.105, -0.13, -0.19), "tail": (0.105, -0.12, -0.34), "parent": "arm_upper.R", "radius": 0.115},
    {"name": "paw.R", "head": (0.105, -0.12, -0.34), "tail": (0.15, -0.06, -0.45), "parent": "arm_lower.R", "radius": 0.12},
    {"name": "leg_upper.L", "head": (-0.13, 0.09, -0.16), "tail": (-0.18, 0.12, -0.30), "parent": "pelvis", "radius": 0.15},
    {"name": "leg_lower.L", "head": (-0.18, 0.12, -0.30), "tail": (-0.19, 0.05, -0.41), "parent": "leg_upper.L", "radius": 0.115},
    {"name": "foot.L", "head": (-0.19, 0.05, -0.41), "tail": (-0.19, -0.04, -0.46), "parent": "leg_lower.L", "radius": 0.12},
    {"name": "leg_upper.R", "head": (0.13, 0.09, -0.16), "tail": (0.18, 0.12, -0.30), "parent": "pelvis", "radius": 0.15},
    {"name": "leg_lower.R", "head": (0.18, 0.12, -0.30), "tail": (0.19, 0.05, -0.41), "parent": "leg_upper.R", "radius": 0.115},
    {"name": "foot.R", "head": (0.19, 0.05, -0.41), "tail": (0.19, -0.04, -0.46), "parent": "leg_lower.R", "radius": 0.12},
    {"name": "tail.01", "head": (0.0, 0.14, -0.17), "tail": (0.025, 0.22, -0.20), "parent": "pelvis", "radius": 0.13},
    {"name": "tail.02", "head": (0.025, 0.22, -0.20), "tail": (0.06, 0.30, -0.25), "parent": "tail.01", "radius": 0.125},
    {"name": "tail.03", "head": (0.06, 0.30, -0.25), "tail": (0.10, 0.38, -0.31), "parent": "tail.02", "radius": 0.12},
)


def _r(degrees: float) -> float:
    return math.radians(degrees)


def _clip(name: str, frame_end: int, loop: bool, keyframes: list[tuple[int, dict[str, tuple[float, float, float]]]]) -> dict[str, Any]:
    return {"name": name, "frame_end": frame_end, "loop": loop, "keyframes": keyframes}


CLIPS: tuple[dict[str, Any], ...] = (
    _clip("idle", 61, True, [
        (1, {}),
        (16, {"chest": (1.5, 0.0, 0.0), "head": (1.5, -2.0, 0.0), "ear.L": (0.0, 0.0, -1.5), "ear.R": (0.0, 0.0, 1.5), "tail.02": (0.0, 0.0, 2.5)}),
        (31, {"head": (0.0, 0.0, 0.0), "tail.02": (0.0, 0.0, -1.0)}),
        (46, {"chest": (-1.0, 0.0, 0.0), "head": (-1.0, 2.0, 0.0), "ear.L": (0.0, 0.0, 1.0), "ear.R": (0.0, 0.0, -1.0), "tail.02": (0.0, 0.0, -2.0)}),
        (61, {}),
    ]),
    _clip("walk", 31, True, [
        (1, {}),
        (8, {"chest": (-2.0, 0.0, 0.0), "arm_upper.L": (-8.0, 0.0, 0.0), "arm_upper.R": (8.0, 0.0, 0.0), "arm_lower.L": (4.0, 0.0, 0.0), "arm_lower.R": (-4.0, 0.0, 0.0), "leg_upper.L": (5.0, 0.0, 0.0), "leg_upper.R": (-5.0, 0.0, 0.0), "tail.01": (0.0, 0.0, 3.0)}),
        (16, {"chest": (1.0, 0.0, 0.0), "tail.01": (0.0, 0.0, -2.0)}),
        (23, {"chest": (-2.0, 0.0, 0.0), "arm_upper.L": (8.0, 0.0, 0.0), "arm_upper.R": (-8.0, 0.0, 0.0), "arm_lower.L": (-4.0, 0.0, 0.0), "arm_lower.R": (4.0, 0.0, 0.0), "leg_upper.L": (-5.0, 0.0, 0.0), "leg_upper.R": (5.0, 0.0, 0.0), "tail.01": (0.0, 0.0, -3.0)}),
        (31, {}),
    ]),
    _clip("curious", 46, True, [
        (1, {}),
        (14, {"head": (-4.0, -3.0, 5.0), "ear.L": (0.0, 0.0, -6.0), "ear.R": (0.0, 0.0, 3.0), "tail.02": (0.0, 0.0, 2.0)}),
        (28, {"head": (-4.0, -3.0, 5.0), "ear.L": (0.0, 0.0, -4.0), "ear.R": (0.0, 0.0, 2.0), "tail.02": (0.0, 0.0, -1.0)}),
        (46, {}),
    ]),
    _clip("praised", 40, False, [
        (1, {}),
        (10, {"chest": (2.0, 0.0, 0.0), "head": (-6.0, 0.0, 0.0), "ear.L": (0.0, 0.0, -8.0), "ear.R": (0.0, 0.0, 8.0), "tail.01": (0.0, 0.0, 8.0), "tail.02": (0.0, 0.0, -8.0)}),
        (24, {"chest": (1.0, 0.0, 0.0), "head": (-2.0, 2.0, 0.0), "ear.L": (0.0, 0.0, -4.0), "ear.R": (0.0, 0.0, 4.0), "tail.01": (0.0, 0.0, -8.0), "tail.02": (0.0, 0.0, 8.0)}),
        (40, {}),
    ]),
    _clip("scolded", 40, False, [
        (1, {}),
        (10, {"chest": (-2.0, 0.0, 0.0), "head": (7.0, 3.0, 0.0), "ear.L": (0.0, 0.0, 8.0), "ear.R": (0.0, 0.0, -8.0), "tail.01": (0.0, 0.0, -5.0), "tail.02": (0.0, 0.0, -5.0)}),
        (24, {"chest": (-1.0, 0.0, 0.0), "head": (4.0, 2.0, -2.0), "ear.L": (0.0, 0.0, 6.0), "ear.R": (0.0, 0.0, -6.0), "tail.01": (0.0, 0.0, 3.0), "tail.02": (0.0, 0.0, 3.0)}),
        (40, {}),
    ]),
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _inside(root: Path, path: Path, label: str) -> Path:
    resolved = path.resolve()
    try:
        resolved.relative_to(root)
    except ValueError as error:
        raise ValueError(f"{label} must stay inside the repository: {resolved}") from error
    return resolved


def _parse_args() -> argparse.Namespace:
    raw = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true", help="validate paths and collisions without writing")
    mode.add_argument("--build", action="store_true", help="build and export the Norn candidate")
    parser.add_argument("--source", required=True)
    parser.add_argument("--blend-output", required=True)
    parser.add_argument("--export-glb", required=True)
    parser.add_argument("--provenance-output", required=True)
    parser.add_argument("--validation-output", required=True, help="reserved for the later local validation report")
    return parser.parse_args(raw)


def _resolve_paths(args: argparse.Namespace) -> tuple[Path, dict[str, Path]]:
    root = Path.cwd().resolve()
    source = _inside(root, Path(args.source), "source")
    outputs = {
        "blend": _inside(root, Path(args.blend_output), "blend output"),
        "glb": _inside(root, Path(args.export_glb), "GLB output"),
        "provenance": _inside(root, Path(args.provenance_output), "provenance output"),
        "validation": _inside(root, Path(args.validation_output), "validation output"),
    }
    if not source.is_file():
        raise FileNotFoundError(f"Source GLB does not exist: {source}")
    if len(set(outputs.values())) != len(outputs):
        raise ValueError("Each output path must be unique")
    for label, path in outputs.items():
        if path == source:
            raise ValueError(f"{label} output cannot overwrite the source GLB")
    existing = [str(path) for path in outputs.values() if path.exists()]
    if existing:
        raise FileExistsError("Refusing to overwrite existing output(s): " + ", ".join(existing))
    candidate_dir = outputs["glb"].parent
    if candidate_dir.exists() and any(candidate_dir.iterdir()):
        raise FileExistsError(f"Refusing to write into a non-empty candidate directory: {candidate_dir}")
    return root, {"source": source, **outputs}


def _clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def _create_armature() -> bpy.types.Object:
    armature_data = bpy.data.armatures.new("NornSkeleton")
    armature_object = bpy.data.objects.new("NornSkeleton", armature_data)
    bpy.context.collection.objects.link(armature_object)
    bpy.ops.object.select_all(action="DESELECT")
    armature_object.select_set(True)
    bpy.context.view_layer.objects.active = armature_object
    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones: dict[str, bpy.types.EditBone] = {}
    for spec in BONES:
        bone = armature_data.edit_bones.new(str(spec["name"]))
        bone.head = Vector(spec["head"])
        bone.tail = Vector(spec["tail"])
        bone.use_deform = True
        if spec["parent"] is not None:
            bone.parent = edit_bones[str(spec["parent"])]
        edit_bones[str(spec["name"])] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    armature_object.show_in_front = True
    armature_data.display_type = "STICK"
    return armature_object


def _segment_distance(point: Vector, start: Vector, end: Vector) -> float:
    segment = end - start
    length_squared = segment.length_squared
    if length_squared <= 1e-12:
        return (point - start).length
    factor = max(0.0, min(1.0, (point - start).dot(segment) / length_squared))
    return (point - (start + factor * segment)).length


def _assign_weights(mesh_objects: list[bpy.types.Object], armature: bpy.types.Object) -> None:
    groups_by_object: dict[str, dict[str, bpy.types.VertexGroup]] = {}
    for mesh_object in mesh_objects:
        if not mesh_object.data.vertices:
            raise ValueError(f"Mesh has no vertices: {mesh_object.name}")
        for group in list(mesh_object.vertex_groups):
            mesh_object.vertex_groups.remove(group)
        groups_by_object[mesh_object.name] = {
            str(spec["name"]): mesh_object.vertex_groups.new(name=str(spec["name"]))
            for spec in BONES
        }
        world_matrix = mesh_object.matrix_world
        for vertex in mesh_object.data.vertices:
            point = world_matrix @ vertex.co
            influences: list[tuple[float, str]] = []
            for spec in BONES:
                distance = _segment_distance(point, Vector(spec["head"]), Vector(spec["tail"]))
                radius = float(spec["radius"])
                score = max(1e-12, math.exp(-0.5 * (distance / radius) ** 2))
                influences.append((score, str(spec["name"])))
            selected = sorted(influences, reverse=True)[:4]
            total = sum(score for score, _name in selected)
            if total <= 1e-20:
                selected = [(1.0, min(influences)[1])]
                total = 1.0
            for score, name in selected:
                groups_by_object[mesh_object.name][name].add([vertex.index], score / total, "REPLACE")

        original_world = mesh_object.matrix_world.copy()
        mesh_object.parent = armature
        mesh_object.matrix_world = original_world
        modifier = mesh_object.modifiers.new(name="NornArmature", type="ARMATURE")
        modifier.object = armature
        modifier.use_vertex_groups = True


def _set_action(armature: bpy.types.Object, clip: dict[str, Any]) -> bpy.types.Action:
    action = bpy.data.actions.new(str(clip["name"]))
    action.use_fake_user = True
    action.use_cyclic = bool(clip["loop"])
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = int(clip["frame_end"])
    armature.animation_data_create()
    armature.animation_data.action = action
    action_slot = action.slots.new(id_type="OBJECT", name=armature.name)
    armature.animation_data.action_slot = action_slot
    pose_bones = armature.pose.bones

    for frame, rotations in clip["keyframes"]:
        bpy.context.scene.frame_set(int(frame))
        for spec in BONES:
            bone_name = str(spec["name"])
            pose_bone = pose_bones[bone_name]
            pose_bone.rotation_mode = "XYZ"
            pose_degrees = rotations.get(bone_name, (0.0, 0.0, 0.0))
            pose_bone.rotation_euler = tuple(_r(float(value)) for value in pose_degrees)
            armature.keyframe_insert(
                data_path=f'pose.bones["{bone_name}"].rotation_euler',
                frame=int(frame),
                group=bone_name,
            )
    if armature.animation_data.action_slot != action_slot:
        raise RuntimeError(f"Blender did not bind an Action Slot for '{clip['name']}'")
    return action


def _create_animations(armature: bpy.types.Object) -> dict[str, bpy.types.Action]:
    actions: dict[str, bpy.types.Action] = {}
    for clip in CLIPS:
        actions[str(clip["name"])] = _set_action(armature, clip)
    armature.animation_data.action = actions["idle"]
    armature.animation_data.action_slot = actions["idle"].slots[0]
    bpy.context.scene.frame_set(1)
    bpy.context.scene.render.fps = 30
    bpy.context.scene.render.fps_base = 1.0
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = max(int(clip["frame_end"]) for clip in CLIPS)
    return actions


def _read_glb_document(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError("Exported GLB is shorter than the minimum header")
    magic, version, total_length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or total_length != len(data):
        raise ValueError("Exported file is not a complete glTF 2.0 binary")
    json_length, json_chunk_type = struct.unpack_from("<II", data, 12)
    if json_chunk_type != 0x4E4F534A:
        raise ValueError("Exported GLB has no leading JSON chunk")
    document = json.loads(data[20 : 20 + json_length].decode("utf-8").rstrip("\x00 "))
    return document


def _material_texture_channels(document: dict[str, Any]) -> list[list[str]]:
    texture_count = len(document.get("textures", []))
    channels_by_material: list[list[str]] = []
    for material_index, material in enumerate(document.get("materials", [])):
        pbr = material.get("pbrMetallicRoughness", {})
        bindings = (
            ("baseColorTexture", pbr.get("baseColorTexture")),
            ("metallicRoughnessTexture", pbr.get("metallicRoughnessTexture")),
            ("normalTexture", material.get("normalTexture")),
        )
        channels: list[str] = []
        for channel_name, texture_info in bindings:
            if texture_info is None:
                continue
            texture_index = texture_info.get("index")
            if not isinstance(texture_index, int) or not 0 <= texture_index < texture_count:
                raise ValueError(f"Material {material_index} has an invalid {channel_name} binding")
            channels.append(channel_name)
        channels_by_material.append(sorted(channels))
    return channels_by_material


def _validate_export(path: Path, source_path: Path) -> dict[str, Any]:
    document = _read_glb_document(path)
    source_document = _read_glb_document(source_path)
    skins = document.get("skins", [])
    animations = document.get("animations", [])
    animation_names = [str(animation.get("name", "")) for animation in animations]
    if len(skins) != 1:
        raise ValueError(f"Exported GLB must contain exactly one skin; found {len(skins)}")
    joint_count = len(skins[0].get("joints", []))
    if joint_count != len(BONES):
        raise ValueError(f"Exported skin must contain exactly {len(BONES)} joints; found {joint_count}")
    if len(animations) != len(EXPECTED_CLIPS) or len(set(animation_names)) != len(animation_names) or set(animation_names) != set(EXPECTED_CLIPS):
        raise ValueError(f"Exported GLB animation names must be exactly {EXPECTED_CLIPS}; found {animation_names}")

    primitives = [primitive for mesh in document.get("meshes", []) for primitive in mesh.get("primitives", [])]
    if not primitives:
        raise ValueError("Exported GLB contains no mesh primitives")
    for primitive_index, primitive in enumerate(primitives):
        attributes = set(primitive.get("attributes", {}))
        missing_attributes = sorted(EXPECTED_VERTEX_ATTRIBUTES - attributes)
        if missing_attributes:
            raise ValueError(f"Exported primitive {primitive_index} is missing vertex attributes: {missing_attributes}")
    source_attributes = {
        attribute
        for mesh in source_document.get("meshes", [])
        for primitive in mesh.get("primitives", [])
        for attribute in primitive.get("attributes", {})
    }
    output_attributes = {
        attribute
        for mesh in document.get("meshes", [])
        for primitive in mesh.get("primitives", [])
        for attribute in primitive.get("attributes", {})
    }
    missing_source_attributes = sorted(source_attributes - output_attributes)
    if missing_source_attributes:
        raise ValueError(f"Exported GLB did not preserve source vertex attributes: {missing_source_attributes}")

    materials = document.get("materials", [])
    pbr_materials = [material.get("pbrMetallicRoughness", {}) for material in materials]
    if not any(material.get("baseColorTexture") for material in pbr_materials):
        raise ValueError("Exported GLB lost its PBR base-color texture")
    if not any(material.get("metallicRoughnessTexture") for material in pbr_materials):
        raise ValueError("Exported GLB lost its metallic/roughness texture")
    if not any(material.get("normalTexture") for material in materials):
        raise ValueError("Exported GLB lost its normal texture")

    skin_nodes = [node.get("name", "") for node in document.get("nodes", []) if node.get("skin") == 0]
    if len(skin_nodes) != 1:
        raise ValueError(f"Exactly one exported node must reference the skin; found {len(skin_nodes)}")

    for resource_key in ("materials", "textures", "images"):
        source_count = len(source_document.get(resource_key, []))
        output_count = len(document.get(resource_key, []))
        if output_count != source_count:
            raise ValueError(f"Exported GLB must preserve the {resource_key} count ({source_count}); found {output_count}")
    source_material_channels = _material_texture_channels(source_document)
    output_material_channels = _material_texture_channels(document)
    if output_material_channels != source_material_channels:
        raise ValueError("Exported GLB must preserve the PBR texture channels on each material")
    return {
        "skinCount": len(skins),
        "jointCount": joint_count,
        "skinnedNodes": skin_nodes,
        "animationNames": sorted(animation_names),
        "vertexAttributes": sorted(EXPECTED_VERTEX_ATTRIBUTES),
        "preservedSourceVertexAttributes": sorted(source_attributes),
        "materialTextureChannels": output_material_channels,
        "materialCount": len(materials),
        "textureCount": len(document.get("textures", [])),
        "imageCount": len(document.get("images", [])),
    }


def _write_provenance(path: Path, source: Path, source_hash: str, export_report: dict[str, Any]) -> None:
    record = {
        "schema": "albia.norn_rig_provenance.v1",
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "assetId": "albia_norn_species",
        "origin": "derived",
        "license": SOURCE_LICENSE,
        "source": {
            "path": source.as_posix(),
            "sha256": source_hash,
            "provider": "Meshy",
            "providerTaskId": "01a1897e-3f2a-77e0-a6a1-5ff5fa44f12a",
        },
        "tool": {"name": "Blender", "version": bpy.app.version_string},
        "transformations": [
            "Imported the preserved static Norn GLB.",
            "Added a custom 25-bone deform rig with proximity-based weights for the disconnected mesh islands.",
            "Added five Blender actions for idle, walk, curiosity, praise, and scold response.",
            "Exported a separate glTF 2.0 binary candidate with the PBR materials and textures.",
        ],
        "rig": {"armature": "NornSkeleton", "deformBoneCount": len(BONES), "weighting": "four nearest bone-segment influences per vertex"},
        "animations": [{"name": str(clip["name"]), "loop": bool(clip["loop"]), "frameEnd": int(clip["frame_end"])} for clip in CLIPS],
        "exportValidation": export_report,
        "validationReport": "validation.json is produced by the local game-dev asset validator after export.",
    }
    path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")


def _build(root: Path, paths: dict[str, Path]) -> dict[str, Any]:
    source_hash = _sha256(paths["source"])
    with tempfile.TemporaryDirectory(prefix=".albia-norn-rig-stage-", dir=str(root)) as stage_name:
        stage = Path(stage_name)
        stage_blend = stage / "albia-norn-rig.blend"
        stage_glb = stage / "model.glb"
        stage_provenance = stage / "provenance.json"

        _clear_scene()
        result = bpy.ops.import_scene.gltf(filepath=str(paths["source"]))
        if "FINISHED" not in result:
            raise RuntimeError(f"Blender could not import the source GLB: {paths['source']}")
        mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
        if not mesh_objects or not any(obj.data.materials for obj in mesh_objects):
            raise ValueError("Source GLB must contain visible mesh geometry and materials")

        armature = _create_armature()
        _assign_weights(mesh_objects, armature)
        actions = _create_animations(armature)
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(stage_blend))

        export_result = bpy.ops.export_scene.gltf(
            filepath=str(stage_glb),
            export_format="GLB",
            export_animations=True,
            export_animation_mode="ACTIONS",
            export_skins=True,
            export_tangents=True,
            export_yup=True,
            export_nla_strips=False,
            check_existing=False,
        )
        if "FINISHED" not in export_result or not stage_glb.is_file():
            raise RuntimeError("Blender did not finish the GLB export")
        export_report = _validate_export(stage_glb, paths["source"])
        _write_provenance(stage_provenance, paths["source"], source_hash, export_report)

        final_files = (
            (stage_blend, paths["blend"]),
            (stage_glb, paths["glb"]),
            (stage_provenance, paths["provenance"]),
        )
        for _staged, destination in final_files:
            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.exists():
                raise FileExistsError(f"Refusing to overwrite output created during this run: {destination}")

        published: list[Path] = []
        try:
            for staged, destination in final_files:
                staged.replace(destination)
                published.append(destination)
        except Exception:
            for destination in reversed(published):
                destination.unlink(missing_ok=True)
            raise

    return {
        "sourceSha256": source_hash,
        "outputs": {key: value.as_posix() for key, value in paths.items() if key != "source"},
        "exportValidation": export_report,
        "actionNames": sorted(actions),
    }


def main() -> int:
    args = _parse_args()
    root, paths = _resolve_paths(args)
    source_hash = _sha256(paths["source"])
    if args.dry_run:
        print(json.dumps({"status": "dry-run-ok", "source": paths["source"].as_posix(), "sourceSha256": source_hash, "outputs": {key: path.as_posix() for key, path in paths.items() if key != "source"}, "overwrites": []}, indent=2))
        return 0

    result = _build(root, paths)
    print(json.dumps({"status": "built", **result}, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"NORN_RIG_BUILD_FAILED: {error}", file=sys.stderr)
        raise
