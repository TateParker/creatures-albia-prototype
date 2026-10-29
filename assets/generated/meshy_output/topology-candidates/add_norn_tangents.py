import bpy
import json
import os
import sys

args = sys.argv[sys.argv.index("--") + 1:]
source, output = args
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(source))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
if not meshes:
    raise RuntimeError("No mesh objects imported from the source GLB")
for obj in meshes:
    if not obj.data.uv_layers:
        raise RuntimeError(f"Mesh {obj.name} has no UV map for tangent generation")
result = bpy.ops.export_scene.gltf(
    filepath=os.path.abspath(output),
    export_format="GLB",
    export_apply=True,
    export_normals=True,
    export_texcoords=True,
    export_tangents=True,
    export_materials="EXPORT",
)
if "FINISHED" not in set(result) or not os.path.isfile(output) or os.path.getsize(output) == 0:
    raise RuntimeError(f"glTF export failed: {sorted(result)}")
print("TANGENT_EXPORT=" + json.dumps({"source": os.path.abspath(source), "output": os.path.abspath(output), "meshObjects": len(meshes), "bytes": os.path.getsize(output), "blenderVersion": bpy.app.version_string}))