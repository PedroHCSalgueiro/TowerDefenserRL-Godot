"""
Renderiza um herói 3D em quadros de sprite, no formato do pacote "2D HD Character Knight":
8 direções, N quadros por animação, câmera alta fixa. Usa o cel shading aprovado no Guia de Estilo
(mesma receita de Assets/ferramentas/aplicar_cel_shading.py), com contorno mais grosso para o
tamanho de sprite. O .blend não é salvo.

blender -b Sir_Aldric_V2.blend --python render_sheet.py -- <pasta_saida> [--test]
"""
import json
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
TEST = "--test" in ARGS
RIG = "SirAldric_Rig"
ANIM = "ataque"
CELL = 320
DIRECTIONS = 8
FRAMES = 15
ELEVATION = 38.0
## Para onde o modelo olha antes de girar. Conferido na renderização de teste.
MODEL_FORWARD = Vector((0, -1, 0))
OUTLINE_RATIO = 0.0055  # espessura do contorno em relação à altura do modelo

LEVELS_V, LEVELS_S = 7, 4
# BRIGHT mais baixo que o do script original: a 1.16 a armadura branca estoura e perde o desenho
SAT_BOOST, BRIGHT = 1.15, 1.0
SHADOW = (0.62, 0.62, 0.74, 1)
OUTLINE_COLOR = (0.03, 0.03, 0.05, 1)


def base_image(obj):
    for slot in obj.material_slots:
        m = slot.material
        if not (m and m.use_nodes):
            continue
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED" and n.inputs["Base Color"].links:
                node = n.inputs["Base Color"].links[0].from_node
                # a textura pode estar atrás de um nó de mistura
                seen = 0
                while node.type != "TEX_IMAGE" and seen < 8:
                    links = [l for i in node.inputs for l in i.links]
                    if not links:
                        break
                    node = links[0].from_node
                    seen += 1
                if node.type == "TEX_IMAGE":
                    return node.image
    return None


def toon_material(img, name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    N, L = nt.nodes.new, nt.links.new
    tex = N("ShaderNodeTexImage")
    tex.image = img
    sep = N("ShaderNodeSeparateColor")
    sep.mode = "HSV"
    L(tex.outputs["Color"], sep.inputs["Color"])

    def chain(s, ops):
        for op, val in ops:
            n = N("ShaderNodeMath")
            n.operation = op
            L(s, n.inputs[0])
            if val is not None:
                n.inputs[1].default_value = val
            s = n.outputs[0]
        return s

    v = chain(sep.outputs[2], [("POWER", 1 / 2.2), ("MULTIPLY", LEVELS_V), ("ROUND", None),
                               ("DIVIDE", LEVELS_V), ("MULTIPLY", BRIGHT), ("POWER", 2.2), ("MINIMUM", 1.0)])
    s = chain(sep.outputs[1], [("MULTIPLY", SAT_BOOST), ("MULTIPLY", LEVELS_S), ("ROUND", None),
                               ("DIVIDE", LEVELS_S), ("MINIMUM", 1.0)])
    comb = N("ShaderNodeCombineColor")
    comb.mode = "HSV"
    L(sep.outputs[0], comb.inputs[0])
    L(s, comb.inputs[1])
    L(v, comb.inputs[2])
    dif = N("ShaderNodeBsdfDiffuse")
    s2r = N("ShaderNodeShaderToRGB")
    L(dif.outputs[0], s2r.inputs[0])
    ramp = N("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    e = ramp.color_ramp.elements
    e[0].position = 0.0
    e[0].color = SHADOW
    e[1].position = 0.25
    e[1].color = (1, 1, 1, 1)
    L(s2r.outputs["Color"], ramp.inputs["Fac"])
    mix = N("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    L(comb.outputs["Color"], mix.inputs[6])
    L(ramp.outputs["Color"], mix.inputs[7])
    em = N("ShaderNodeEmission")
    L(mix.outputs[2], em.inputs["Color"])
    out = N("ShaderNodeOutputMaterial")
    L(em.outputs[0], out.inputs["Surface"])
    return m


def outline_material():
    m = bpy.data.materials.new("Toon_Outline")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = OUTLINE_COLOR
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs["Surface"])
    m.use_backface_culling = True
    return m


def world_bounds(meshes):
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in meshes:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
        ev.to_mesh_clear()
    return lo, hi


scene = bpy.context.scene
rig = bpy.data.objects[RIG]
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
action = bpy.data.actions[ANIM]
f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])

# enquadramento: pega a pose parada e a metade do golpe, antes do contorno entrar na conta
scene.frame_set(f0)
lo, hi = world_bounds(meshes)
height = hi.z - lo.z
for f in range(f0, f1 + 1, 4):
    scene.frame_set(f)
    a, b = world_bounds(meshes)
    lo = Vector((min(lo.x, a.x), min(lo.y, a.y), min(lo.z, a.z)))
    hi = Vector((max(hi.x, b.x), max(hi.y, b.y), max(hi.z, b.z)))
feet = Vector((rig.location.x, rig.location.y, lo.z))
reach = max(abs(lo.x - feet.x), abs(hi.x - feet.x), abs(lo.y - feet.y), abs(hi.y - feet.y))
print("ALTURA", height, "alcance", reach, "topo", hi.z, "pes", feet)

for o in meshes:
    img = base_image(o)
    if img is None:
        print("SEM TEXTURA", o.name)
        continue
    o.data.materials.clear()
    o.data.materials.append(toon_material(img, "Toon_" + o.name))
    o.data.materials.append(outline_material())
    sol = o.modifiers.new("Outline", "SOLIDIFY")
    sol.thickness = height * OUTLINE_RATIO
    sol.offset = 1.0
    sol.use_flip_normals = True
    sol.use_rim = False
    sol.material_offset = 1

# câmera ortográfica alta e fixa; quem gira é o personagem
cam_data = bpy.data.cameras.new("SpriteCam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("SpriteCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
elev = math.radians(ELEVATION)
center = feet + Vector((0, 0, (hi.z - lo.z) * 0.5))
cam.location = center + Vector((0, -math.cos(elev), math.sin(elev))) * 30.0
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
vertical = (hi.z - lo.z) * math.cos(elev) + 2 * reach * math.sin(elev)
cam_data.ortho_scale = max(vertical, 2 * reach) * 1.08
cam_data.clip_end = 100.0

sun_data = bpy.data.lights.new("Sol", "SUN")
sun_data.energy = 3.0
sun_data.angle = 0.0
sun = bpy.data.objects.new("Sol", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))

r = scene.render
r.resolution_x = r.resolution_y = CELL
r.resolution_percentage = 100
r.film_transparent = True
r.image_settings.file_format = "PNG"
r.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.eevee.taa_render_samples = 16
bpy.context.view_layer.update()

# âncora: onde os pés caem na imagem (para o sprite pisar na base)
co = world_to_camera_view(scene, cam, feet)
anchor = [co.x * CELL, (1.0 - co.y) * CELL]

os.makedirs(OUT, exist_ok=True)
frames = [f0 + round((f1 - f0) * i / (FRAMES - 1)) for i in range(FRAMES)]
if TEST:
    rows, frames = [0, 2, 4, 6], [f0, frames[FRAMES // 2]]
else:
    rows = list(range(DIRECTIONS))
base_yaw = rig.rotation_euler.z
rig.rotation_mode = "XYZ"
angles = []
for d in range(DIRECTIONS):
    yaw = math.radians(d * 360.0 / DIRECTIONS)
    fwd = MODEL_FORWARD.copy()
    fwd.rotate(rig.rotation_euler.__class__((0, 0, yaw)))
    # ângulo do olhar visto pela câmera: 0 = de frente para ela, positivo = para a direita da tela
    angles.append(math.degrees(math.atan2(fwd.x, -fwd.y)))
for d in rows:
    rig.rotation_euler.z = base_yaw + math.radians(d * 360.0 / DIRECTIONS)
    for i, f in enumerate(frames):
        scene.frame_set(f)
        r.filepath = os.path.join(OUT, "d%d_f%02d.png" % (d, i))
        bpy.ops.render.render(write_still=True)
with open(os.path.join(OUT, "meta.json"), "w") as fh:
    json.dump({"cell": CELL, "anchor": anchor, "frames": FRAMES, "angles": angles, "ortho_scale": cam_data.ortho_scale, "height": height, "seconds": (f1 - f0) / scene.render.fps}, fh)
print("PRONTO", OUT, anchor, angles)
