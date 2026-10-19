"""
Arqueiro ★1 — modelo + rig + 3 animações, exportado em GLB para o Godot.

Rodar (headless):
    python build_archer.py <saida.glb> [saida.blend]
(precisa do pacote `bpy`; ou dentro do Blender: blender -b -P build_archer.py -- saida.glb)

Convenções:
- As medidas abaixo estão em "coordenadas Godot" (x direita, y cima, z frente) e convertidas por G().
- O personagem olha para -Y no Blender, que vira +Z no glTF/Godot (mesma frente do jogo).
- Skin rígida: cada parte da malha pertence a 1 osso (peso 1.0). Malha única, vários materiais.
"""
import sys
import math
import bpy
import bmesh
from mathutils import Vector, Matrix, Quaternion

argv = sys.argv
if "--" in argv:
    argv = argv[argv.index("--") + 1:]
else:
    argv = argv[1:]
OUT_GLB = argv[0] if len(argv) > 0 else "archer.glb"
OUT_BLEND = argv[1] if len(argv) > 1 else None

FPS = 30


def G(x, y, z):
    """coordenada Godot (x, y cima, z frente) -> Blender (x, -z, y)"""
    return Vector((x, -z, y))


def srgb_to_linear(c):
    return tuple((v ** 2.2) for v in c)


# ----------------------------------------------------------------- cena limpa
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS

# ----------------------------------------------------------------- materiais
PALETTE = {
    "skin": (0.93, 0.74, 0.58),
    "tunic": (0.45, 0.40, 0.28),   # marrom-oliva gasto
    "pants": (0.30, 0.26, 0.22),
    "boot": (0.20, 0.14, 0.10),
    "belt": (0.20, 0.13, 0.08),
    "hood": (0.28, 0.42, 0.25),
    "wood": (0.55, 0.36, 0.18),
    "quiver": (0.40, 0.26, 0.14),
    "cord": (0.92, 0.90, 0.80),
    "dark": (0.08, 0.08, 0.08),
    "fletch": (0.85, 0.20, 0.20),
}
MAT_NAMES = list(PALETTE.keys())
materials = {}
for name, col in PALETTE.items():
    m = bpy.data.materials.new("archer_" + name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    lin = srgb_to_linear(col)
    bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    materials[name] = m

# ----------------------------------------------------------------- esqueleto
# nome: (cabeça, cauda, pai)  — em coordenadas Godot
BONES = {
    "root":   ((0, 0.00, 0), (0, 0.10, 0), None),
    "hips":   ((0, 0.38, 0), (0, 0.46, 0), "root"),
    "spine":  ((0, 0.46, 0), (0, 0.81, 0), "hips"),
    "head":   ((0, 0.81, 0), (0, 1.22, 0), "spine"),
    "leg_l":  ((-0.09, 0.38, 0), (-0.09, 0.10, 0), "hips"),
    "leg_r":  ((0.09, 0.38, 0), (0.09, 0.10, 0), "hips"),
    "arm_l":  ((-0.17, 0.70, 0.02), (-0.17, 0.70, 0.38), "spine"),   # braço do arco
    "arm_r":  ((0.17, 0.70, 0.02), (-0.17, 0.70, 0.30), "spine"),    # braço que puxa a corda
    "str_up": ((-0.17, 0.99, 0.30), (-0.17, 0.70, 0.30), "arm_l"),
    "str_dn": ((-0.17, 0.41, 0.30), (-0.17, 0.70, 0.30), "arm_l"),
    "arrow":  ((-0.17, 0.70, 0.30), (-0.17, 0.70, 0.50), "arm_l"),
}

arm_data = bpy.data.armatures.new("ArcherArmature")
arm_obj = bpy.data.objects.new("ArcherRig", arm_data)
scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="EDIT")
for bname, (h, t, parent) in BONES.items():
    eb = arm_data.edit_bones.new(bname)
    eb.head = G(*h)
    eb.tail = G(*t)
    if parent:
        eb.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")

# ----------------------------------------------------------------- malha (peças rígidas)
bm = bmesh.new()
deform = bm.verts.layers.deform.verify()
BONE_INDEX = {b: i for i, b in enumerate(BONES)}   # mesma ordem dos grupos de vértices criados depois


def _finish(ret_verts, bone, mat):
    mi = MAT_NAMES.index(mat)
    faces = set()
    for v in ret_verts:
        for f in v.link_faces:
            faces.add(f)
    for f in faces:
        f.material_index = mi
        f.smooth = True
    for v in ret_verts:                                   # peso 1.0 direto no vértice (sem depender de índices)
        v[deform][BONE_INDEX[bone]] = 1.0


def limb(a, b, r, bone, mat, segs=8, r2=None):
    a, b = G(*a), G(*b)
    d = b - a
    q = d.to_track_quat("Z", "Y")
    M = Matrix.Translation((a + b) * 0.5) @ q.to_matrix().to_4x4()
    ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs,
                                radius1=r, radius2=r if r2 is None else r2, depth=d.length, matrix=M)
    bm.verts.ensure_lookup_table()
    _finish(ret["verts"], bone, mat)


def sphere(center, radius, bone, mat, scale=(1, 1, 1), ub=12, vb=8):
    c = G(*center)
    S = Matrix.Diagonal((scale[0], scale[2], scale[1], 1.0))  # escala em eixos Godot (x, z->y bl, y->z bl)
    M = Matrix.Translation(c) @ S
    ret = bmesh.ops.create_uvsphere(bm, u_segments=ub, v_segments=vb, radius=radius, matrix=M)
    bm.verts.ensure_lookup_table()
    _finish(ret["verts"], bone, mat)


def box(center, size, bone, mat):
    c = G(*center)
    S = Matrix.Diagonal((size[0], size[2], size[1], 1.0))
    M = Matrix.Translation(c) @ S
    ret = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    bm.verts.ensure_lookup_table()
    _finish(ret["verts"], bone, mat)


def cone(base_center, height, radius, bone, mat, tilt_x_deg=0.0):
    """cone com ponta para cima (eixo Y Godot); inclinação em torno de X (Godot)"""
    c = G(*base_center) + Vector((0, 0, 0))
    rot = Matrix.Rotation(math.radians(tilt_x_deg), 4, Vector((1, 0, 0)))  # x igual nos dois sistemas
    # create_cone: eixo Z (Blender) = cima; centro no meio
    M = Matrix.Translation(c + Vector((0, 0, height / 2.0))) @ rot
    ret = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10,
                                radius1=radius, radius2=0.0, depth=height, matrix=M)
    bm.verts.ensure_lookup_table()
    _finish(ret["verts"], bone, mat)


# pernas e botas
for sx, bone in ((-0.09, "leg_l"), (0.09, "leg_r")):
    limb((sx, 0.38, 0), (sx, 0.10, 0), 0.055, bone, "pants")
    box((sx, 0.11, 0.035), (0.11, 0.07, 0.17), bone, "boot")
# tronco e cinto
sphere((0, 0.58, 0), 0.16, "spine", "tunic", scale=(1.0, 1.45, 1.0), ub=14, vb=10)
limb((0, 0.44, 0), (0, 0.49, 0), 0.168, "spine", "belt", segs=12)
# cabeça, olhos, capuz
sphere((0, 0.93, 0), 0.13, "head", "skin", ub=14, vb=10)
for ex in (-0.05, 0.05):
    sphere((ex, 0.95, 0.118), 0.02, "head", "dark", ub=6, vb=4)
cone((0, 0.96, -0.02), 0.30, 0.175, "head", "hood", tilt_x_deg=14.0)
# aljava + flechas nas costas
limb((0.06, 0.45, -0.15), (-0.01, 0.82, -0.21), 0.06, "spine", "quiver")
for fx in (-0.03, 0.025, 0.07):
    limb((fx - 0.02, 0.82, -0.21), (fx - 0.04, 0.95, -0.23), 0.014, "spine", "fletch", segs=6)
# braço do arco + arco
limb((-0.17, 0.70, 0.02), (-0.17, 0.70, 0.36), 0.045, "arm_l", "tunic")
limb((-0.17, 0.58, 0.38), (-0.17, 0.82, 0.38), 0.024, "arm_l", "wood", segs=6)
limb((-0.17, 0.82, 0.38), (-0.17, 0.99, 0.30), 0.020, "arm_l", "wood", segs=6)
limb((-0.17, 0.58, 0.38), (-0.17, 0.41, 0.30), 0.020, "arm_l", "wood", segs=6)
# braço que puxa, corda (2 metades) e flecha encaixada
limb((0.17, 0.70, 0.02), (-0.17, 0.70, 0.30), 0.045, "arm_r", "tunic")
limb((-0.17, 0.99, 0.30), (-0.17, 0.70, 0.30), 0.008, "str_up", "cord", segs=4)
limb((-0.17, 0.41, 0.30), (-0.17, 0.70, 0.30), 0.008, "str_dn", "cord", segs=4)
limb((-0.17, 0.70, 0.30), (-0.17, 0.70, 0.50), 0.013, "arrow", "wood", segs=6)

mesh = bpy.data.meshes.new("ArcherMesh")
bm.to_mesh(mesh)
bm.free()
for name in MAT_NAMES:
    mesh.materials.append(materials[name])
mesh_obj = bpy.data.objects.new("Archer", mesh)
scene.collection.objects.link(mesh_obj)

# grupos de vértices na MESMA ordem de BONES (o índice do grupo = índice do osso)
for bname in BONES:
    mesh_obj.vertex_groups.new(name=bname)

mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
mod.object = arm_obj
mesh_obj.parent = arm_obj

# ----------------------------------------------------------------- animações
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="POSE")
pb = arm_obj.pose.bones
for b in pb:
    b.rotation_mode = "QUATERNION"

REST = {n: b.bone.matrix_local.to_3x3() for n, b in pb.items()}   # eixos do osso em espaço do armature


def reset_pose():
    for b in pb:
        b.location = (0, 0, 0)
        b.rotation_quaternion = (1, 0, 0, 0)
        b.scale = (1, 1, 1)


def rot_arm(axis_godot, deg):
    """rotação em espaço do armature (eixo dado em coords Godot)"""
    ax = G(*axis_godot)
    return Matrix.Rotation(math.radians(deg), 3, ax)


def set_rot(bone, R_arm):
    B = REST[bone]
    L = B.inverted() @ R_arm @ B
    pb[bone].rotation_quaternion = L.to_quaternion()


def set_loc(bone, delta_godot):
    B = REST[bone]
    pb[bone].location = B.inverted() @ G(*delta_godot)


def aim(bone, tip_godot, hand_rest, hand_now):
    """gira/estica o osso para que sua ponta acompanhe a mão (corda e braço que puxa)"""
    tip = G(*tip_godot)
    d0 = hand_rest - tip
    d1 = hand_now - tip
    R = d0.rotation_difference(d1).to_matrix()
    set_rot(bone, R)
    pb[bone].scale = (1.0, d1.length / d0.length, 1.0)


HAND_REST = G(-0.17, 0.70, 0.30)


def pose_draw(d):
    """d = 0 (corda solta) ... 1 (totalmente puxada)"""
    hand = G(-0.17, 0.70, 0.30 - 0.20 * d)
    aim("arm_r", (0.17, 0.70, 0.02), HAND_REST, hand)
    aim("str_up", (-0.17, 0.99, 0.30), HAND_REST, hand)
    aim("str_dn", (-0.17, 0.41, 0.30), HAND_REST, hand)
    # flecha acompanha a mão (translação no espaço do armature)
    pb["arrow"].location = REST["arrow"].inverted() @ (hand - HAND_REST)
    s = 1.0 if d > 0.12 else 0.001
    pb["arrow"].scale = (s, s, s)


def key(frame, bones=None):
    for b in pb:
        if bones and b.name not in bones:
            continue
        b.keyframe_insert("location", frame=frame)
        b.keyframe_insert("rotation_quaternion", frame=frame)
        b.keyframe_insert("scale", frame=frame)


def new_action(name):
    reset_pose()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm_obj.animation_data_create()
    arm_obj.animation_data.action = act
    return act


def f(sec):
    return int(round(sec * FPS))


# --- idle: respira, balança de leve (loop de 2 s)
def idle_pose(phase):
    reset_pose()
    s = math.sin(phase * math.tau)
    set_loc("hips", (0, 0.010 * s, 0))
    set_rot("spine", rot_arm((1, 0, 0), 1.6 * s))
    set_rot("head", rot_arm((0, 1, 0), 4.0 * math.sin(phase * math.tau + 1.2)))
    set_rot("arm_l", rot_arm((1, 0, 0), 1.2 * s))
    pose_draw(0.0)


act_idle = new_action("idle")
for i, ph in enumerate((0.0, 0.25, 0.5, 0.75, 1.0)):
    idle_pose(ph if ph < 1.0 else 0.0)
    key(i * f(0.5))
act_idle.use_cyclic = True

# --- shoot: puxa (0–0.53 s), solta no instante 0.53 s, recua e volta (até 0.8 s)
act_shoot = new_action("shoot")
DRAW_END = 16   # frame da soltura


def shoot_pose(d, lean=0.0, recoil=0.0, kick=0.0):
    reset_pose()
    set_rot("spine", rot_arm((1, 0, 0), -lean) @ rot_arm((0, 1, 0), 4.0 * d))
    set_rot("head", rot_arm((1, 0, 0), 2.0 * lean))
    set_rot("arm_l", rot_arm((1, 0, 0), -recoil))
    set_loc("hips", (0, 0, -kick))
    pose_draw(d)


for fr in range(0, DRAW_END + 1, 2):
    d = (fr / DRAW_END)
    d = d * d * (3 - 2 * d)            # suaviza
    shoot_pose(d, lean=5.0 * d)
    key(fr)
shoot_pose(0.0, lean=-1.5, recoil=8.0, kick=0.04)    # soltou: corda volta de uma vez, arco chacoalha
key(DRAW_END + 2)
shoot_pose(0.0, lean=-2.0, recoil=3.0, kick=0.02)
key(DRAW_END + 5)
shoot_pose(0.0)
key(f(0.8))

# --- star_up: abaixa, pula com os braços para cima, cai, "pop" de escala
act_star = new_action("star_up")


def star_pose(hips_y=0.0, crouch=0.0, arms=0.0, pop=1.0):
    reset_pose()
    set_loc("hips", (0, hips_y, 0))
    set_rot("spine", rot_arm((1, 0, 0), crouch))
    set_rot("arm_l", rot_arm((1, 0, 0), -arms))
    set_rot("arm_r", rot_arm((1, 0, 0), -arms * 0.9))
    set_rot("head", rot_arm((1, 0, 0), -arms * 0.3))
    pose_draw(0.0)
    pb["root"].scale = (pop, pop, pop)


star_pose(); key(0)
star_pose(hips_y=-0.08, crouch=14.0, arms=-10.0); key(8)
star_pose(hips_y=0.26, crouch=-6.0, arms=70.0); key(18)
star_pose(hips_y=-0.05, crouch=8.0, arms=20.0); key(28)
star_pose(hips_y=0.0, crouch=0.0, arms=0.0, pop=1.16); key(34)
star_pose(); key(f(1.5))

arm_obj.animation_data.action = act_idle
reset_pose()
bpy.ops.object.mode_set(mode="OBJECT")
scene.frame_start = 0
scene.frame_end = 60

# ----------------------------------------------------------------- exportar
if OUT_BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

bpy.ops.object.select_all(action="DESELECT")
arm_obj.select_set(True)
mesh_obj.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=OUT_GLB,
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_force_sampling=True,
    export_optimize_animation_size=False,
    export_skins=True,
    export_yup=True,
    export_apply=False,
)
print("EXPORT OK", OUT_GLB, "tris:", sum(len(p.vertices) - 2 for p in mesh.polygons))
