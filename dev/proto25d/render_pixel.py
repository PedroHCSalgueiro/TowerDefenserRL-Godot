"""
Heróis em "pixel art com cara de 3D": folhas de 1920x1024 com 8 linhas (direções) e 15 colunas
(quadros) de 128x128 px, no formato do pacote 2D HD Character Knight.

O corpo é o modelo 3D com luz e textura de verdade (Cycles), renderizado pequeno e sem suavização;
depois as cores são reduzidas a uma paleta e a sombra no chão vira um tom só. As poses usam o
poselib dos scripts da montagem do Aldric. O .blend não é salvo.

blender -b <arquivo.blend> --python render_pixel.py -- <aldric|lyra> <pasta_saida> [--test] [--post]
--post refaz só as folhas a partir dos quadros já renderizados em <pasta_saida>/raw.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
CHAR = ARGS[0]
OUT = ARGS[1]
TEST = "--test" in ARGS
POST_ONLY = "--post" in ARGS
SCRIPTS = r"E:\Programacao\Jogos\TD RogueLite\Assets\personagens\reino\sir-aldric\V2.0\montagem\scripts"
sys.path.append(SCRIPTS)
from poselib import Rig, nm, unit  # noqa: E402

CELL = 128
COLS = 15
ROWS = 8
ELEVATION = 45.0
## Pés no quadro (y em pixels, de cima para baixo), como no pacote.
FEET_Y = 96.0
PALETTE = 48
SHADOW_ALPHA = 0.55
OUTLINE = (0.06, 0.05, 0.08)


def mix(a, b, k):
    out = {}
    for key in a:
        if isinstance(a[key], tuple):
            out[key] = tuple(a[key][i] + (b[key][i] - a[key][i]) * k for i in range(len(a[key])))
        else:
            out[key] = a[key] + (b[key] - a[key]) * k
    return out


def pose_at(keys, t):
    for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
        if t <= t1:
            return mix(p0, p1, (t - t0) / (t1 - t0))
    return keys[-1][1]


# ---------------------------------------------------------------- Sir Aldric
# espaço do armature: +X = esquerda do personagem, -Y = frente, +Z = cima

ALDRIC_ORTHO = 3.3
ALDRIC_FEET = {"L": (0.11, -0.17, 0.0), "R": (-0.13, 0.19, 0.0)}
ALDRIC_SHIELD = dict(upper=(0.34, -0.48, -0.81), fore=(-0.30, -0.88, 0.36), hand_f=(-0.30, -0.92, 0.12), hand_p=(0, 0, -1))
ALDRIC_GUARD = dict(hip=(-0.02, -0.17), lean=-13.0, twist=14.0, head_pitch=7.0, head_yaw=-12.0,
                    upper=(-0.38, 0.02, -0.92), fore=(-0.12, -0.86, 0.50), sword=(-0.28, -0.36, 0.89))
# Ataque: agacha, ergue a espada reta para o alto (o raio cai no quadro 5), segura e volta à guarda.
ALDRIC_RAISED = dict(hip=(0.0, -0.09), lean=3.0, twist=4.0, head_pitch=20.0, head_yaw=-4.0,
                     upper=(-0.30, -0.12, 0.95), fore=(-0.10, -0.04, 0.99), sword=(-0.04, -0.06, 0.99))
ALDRIC_ATTACK = [
    (0.00, ALDRIC_GUARD),
    (0.20, dict(hip=(-0.03, -0.21), lean=-17.0, twist=18.0, head_pitch=9.0, head_yaw=-12.0,
                upper=(-0.46, 0.14, -0.88), fore=(-0.26, -0.58, 0.77), sword=(-0.40, -0.10, 0.91))),
    (0.36, ALDRIC_RAISED),
    (0.62, ALDRIC_RAISED),
    (1.00, ALDRIC_GUARD),
]


def grip(sword, hint=(0, -1, 0)):
    """Mão que faz a espada apontar para `sword`. No rig, a lâmina segue f x p."""
    s = unit(sword)
    h = Vector(hint)
    f = unit(h - s * s.dot(h))
    return f, s.cross(f)


def aldric_pose(rig, P):
    rig.reset()
    rig.move("CC_Base_Hip", (0, P["hip"][0], P["hip"][1]))
    rig.spine(P["lean"], P["twist"], 0.0)
    rig.neck_head(P["head_pitch"], P["head_yaw"])
    rig.swing(nm("R", "Upperarm"), P["upper"])
    rig.swing(nm("R", "Forearm"), P["fore"])
    f, p = grip(P["sword"])
    rig.orient(nm("R", "Hand"), f, p, (0, 0, -1))
    rig.fingers("R", 1.0, 1.0)
    rig.forearm_twist("R")
    s = ALDRIC_SHIELD
    rig.swing(nm("L", "Upperarm"), s["upper"])
    rig.swing(nm("L", "Forearm"), s["fore"])
    rig.orient(nm("L", "Hand"), s["hand_f"], s["hand_p"], (0, 0, -1))
    rig.fingers("L", 1.0, 1.0)
    rig.forearm_twist("L")
    for side in ("L", "R"):
        rig.leg_ik(side, ALDRIC_FEET[side])


def aldric_idle(f):
    b = math.sin(f / COLS * math.tau)
    p = dict(ALDRIC_GUARD)
    p["hip"] = (ALDRIC_GUARD["hip"][0], ALDRIC_GUARD["hip"][1] + b * 0.012)
    p["lean"] = ALDRIC_GUARD["lean"] - b * 1.2
    p["sword"] = (ALDRIC_GUARD["sword"][0], ALDRIC_GUARD["sword"][1] - b * 0.03, ALDRIC_GUARD["sword"][2])
    return p


# ---------------------------------------------------------------- Lyra
# O modelo tem ~0,93 de altura. A referência (lyra_v2_ref) pede cabelo e couro castanhos, cabeça
# menor e uma besta grande de bronze, segurada com as duas mãos.

LYRA_ORTHO = 1.72
## O figurino dela é escuro: mais luz que no Aldric, cuja armadura branca estouraria.
LYRA_SUN = 3.0
LYRA_HEAD_SCALE = 0.84
LYRA_FEET = {"L": (0.055, -0.075, 0.0), "R": (-0.06, 0.09, 0.0)}
## Tamanho da besta em relação ao desenho de make_crossbow.
LYRA_BOW_SCALE = 0.7
## Onde cada mão pega a besta, em distância a partir da coronha.
LYRA_GRIP_R = 0.10 * LYRA_BOW_SCALE
LYRA_GRIP_L = 0.20 * LYRA_BOW_SCALE
LYRA_READY = dict(hip=(-0.01, -0.035), lean=-5.0, twist=12.0, head_pitch=4.0, head_yaw=-10.0,
                  butt=(-0.10, -0.09, 0.665), aim=(0.52, -0.50, -0.69))
LYRA_AIM = dict(hip=(-0.012, -0.04), lean=-7.0, twist=-20.0, head_pitch=2.0, head_yaw=20.0,
                butt=(-0.075, -0.02, 0.725), aim=(0.0, -1.0, 0.03))
# Ataque: leva a besta ao ombro, dispara no quadro 5, recua no tranco, volta a mirar e abaixa.
LYRA_ATTACK = [
    (0.00, LYRA_READY),
    (0.24, LYRA_AIM),
    (0.36, LYRA_AIM),
    (0.43, dict(LYRA_AIM, butt=(-0.075, 0.008, 0.738), aim=(0.0, -0.97, 0.25), lean=-3.0)),
    (0.57, LYRA_AIM),
    (0.72, LYRA_AIM),
    (1.00, LYRA_READY),
]


def arm_ik(rig, side, target, pole):
    up, fo, ha = nm(side, "Upperarm"), nm(side, "Forearm"), nm(side, "Hand")
    sh = rig.head(up)
    l1 = (rig.rest_head(fo) - rig.rest_head(up)).length
    l2 = (rig.rest_head(ha) - rig.rest_head(fo)).length
    d = Vector(target) - sh
    dist = min(d.length, (l1 + l2) * 0.999)
    dh = d.normalized()
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    p = Vector(pole)
    p = (p - dh * p.dot(dh)).normalized()
    elbow = sh + dh * a + p * h
    wrist = sh + dh * dist
    rig.swing(up, elbow - sh)
    rig.swing(fo, wrist - elbow)
    f = unit(wrist - elbow)
    palm = Vector((0, 0, -1))
    if abs(f.dot(palm)) > 0.9:
        palm = Vector((0, -1, 0))
    rig.orient(ha, f, palm, (0, 0, -1))
    rig.fingers(side, 1.0, 1.0)
    rig.forearm_twist(side)


def tube(bm, pts, r, mat, sides=6):
    rings = []
    for i, c in enumerate(pts):
        c = Vector(c)
        d = Vector(pts[min(i + 1, len(pts) - 1)]) - Vector(pts[max(i - 1, 0)])
        d = d.normalized()
        ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        a = d.cross(ref).normalized()
        b = d.cross(a).normalized()
        ring = [bm.verts.new(c + (a * math.cos(s * math.tau / sides) + b * math.sin(s * math.tau / sides)) * r) for s in range(sides)]
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for s in range(sides):
            f = bm.faces.new((r0[s], r0[(s + 1) % sides], r1[(s + 1) % sides], r1[s]))
            f.material_index = mat
    for ring in (rings[0], rings[-1]):
        f = bm.faces.new(ring)
        f.material_index = mat


def block(bm, y0, y1, w0, w1, h0, h1, mat):
    """Peça do corpo da besta: seção retangular variando de y0 a y1."""
    vs = []
    for y, w, h in ((y0, w0, h0), (y1, w1, h1)):
        vs += [bm.verts.new((sx * w, y, sz * h)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    for q in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        f = bm.faces.new([vs[i] for i in q])
        f.material_index = mat


def make_crossbow():
    """Besta da referência: coronha em leque, corpo de madeira e bronze, arco largo, roda na ponta de
    cada braço e estribo vazado no nariz. Origem na coronha, +Y aponta para o alvo, +Z para cima."""
    bm = bmesh.new()
    BRONZE, WOOD, STEEL, STRING = 0, 1, 2, 3
    block(bm, 0.015, 0.14, 0.012, 0.016, 0.022, 0.017, WOOD)
    block(bm, 0.14, 0.40, 0.016, 0.012, 0.017, 0.012, BRONZE)
    # leque da coronha
    for i in range(7):
        a = math.radians(-66 + i * 22)
        tube(bm, [(0, 0.03, 0), (math.sin(a) * 0.075, -0.012 + math.cos(a) * -0.012, math.cos(a) * 0.075)], 0.0075, BRONZE, 4)
    # braços do arco
    limbs = []
    for i in range(13):
        u = -1 + i / 6
        limbs.append((u * 0.25, 0.31 - 0.075 * u * u + 0.012 * abs(u), 0.0))
    tube(bm, limbs, 0.0125, STEEL)
    tube(bm, [(x, y + 0.004, z + 0.0085) for x, y, z in limbs], 0.0065, BRONZE, 4)
    for sx in (-1, 1):
        tip = limbs[0] if sx < 0 else limbs[-1]
        tube(bm, [(tip[0], tip[1], -0.018), (tip[0], tip[1], 0.018)], 0.028, BRONZE, 8)
        tube(bm, [tip, (tip[0] + sx * 0.05, tip[1] - 0.012, 0.035)], 0.007, BRONZE, 4)
    # corda
    nock = (0, 0.17, 0.018)
    tube(bm, [limbs[0], nock], 0.0035, STRING, 4)
    tube(bm, [limbs[-1], nock], 0.0035, STRING, 4)
    # estribo vazado no nariz
    ring = [(math.cos(a * math.tau / 12) * 0.052, 0.415, math.sin(a * math.tau / 12) * 0.052) for a in range(13)]
    tube(bm, ring, 0.0065, BRONZE, 4)
    for a in range(0, 12, 3):
        tube(bm, [(0, 0.405, 0), ring[a]], 0.0045, BRONZE, 4)
    me = bpy.data.meshes.new("BestaNova")
    bm.to_mesh(me)
    bm.free()

    def mat(name, color, metal, rough):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bs.inputs["Base Color"].default_value = (*color, 1)
        bs.inputs["Metallic"].default_value = metal
        bs.inputs["Roughness"].default_value = rough
        return m

    me.materials.append(mat("Bronze", (0.46, 0.29, 0.09), 0.5, 0.45))
    me.materials.append(mat("Madeira", (0.20, 0.09, 0.04), 0.0, 0.7))
    me.materials.append(mat("Aco", (0.13, 0.13, 0.16), 0.5, 0.45))
    me.materials.append(mat("Corda", (0.75, 0.72, 0.62), 0.0, 0.8))
    return me


def warm_to_reference(img):
    """A textura do modelo é alaranjada: leva cabelo e couro para o castanho da referência.
    A pele tem saturação bem menor, então escapa do filtro."""
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    rgb = px[:, :3]
    hi = rgb.max(axis=1)
    lo = rgb.min(axis=1)
    sat = (hi - lo) / np.maximum(hi, 1e-6)
    # matiz vermelho/laranja: o vermelho domina e o azul é o menor
    warm = (rgb[:, 0] >= rgb[:, 1]) & (rgb[:, 1] >= rgb[:, 2]) & (sat > 0.42)
    gray = hi[warm][:, None]
    px[warm, :3] = (gray + (rgb[warm] - gray) * 0.8) * 0.86
    # empurra o matiz do vermelho para o castanho
    px[warm, 1] += 0.04 * px[warm, 0]
    img.pixels.foreach_set(px.ravel())
    img.update()


def lyra_pose(rig, P):
    rig.reset()
    rig.pb("CC_Base_Head").scale = (LYRA_HEAD_SCALE,) * 3
    rig.move("CC_Base_Hip", (0, P["hip"][0], P["hip"][1]))
    rig.spine(P["lean"], P["twist"], 0.0)
    rig.neck_head(P["head_pitch"], P["head_yaw"])
    butt = Vector(P["butt"])
    aim = unit(P["aim"])
    arm_ik(rig, "R", butt + aim * LYRA_GRIP_R, (-0.6, 0.35, -0.7))
    arm_ik(rig, "L", butt + aim * LYRA_GRIP_L, (0.6, 0.1, -0.8))
    for side in ("L", "R"):
        rig.leg_ik(side, LYRA_FEET[side])
    x = aim.cross(Vector((0, 0, 1))).normalized()
    z = x.cross(aim).normalized()
    k = LYRA_BOW_SCALE
    CROSSBOW.matrix_local = Matrix((
        (x.x * k, aim.x * k, z.x * k, butt.x),
        (x.y * k, aim.y * k, z.y * k, butt.y),
        (x.z * k, aim.z * k, z.z * k, butt.z),
        (0, 0, 0, 1)))
    bpy.context.view_layer.update()


def lyra_idle(f):
    b = math.sin(f / COLS * math.tau)
    p = dict(LYRA_READY)
    p["hip"] = (LYRA_READY["hip"][0], LYRA_READY["hip"][1] + b * 0.006)
    p["lean"] = LYRA_READY["lean"] - b * 1.0
    p["butt"] = (LYRA_READY["butt"][0], LYRA_READY["butt"][1], LYRA_READY["butt"][2] + b * 0.004)
    return p


# ---------------------------------------------------------------- estado

def snapshot(arm):
    bones = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in arm.pose.bones}
    return bones, CROSSBOW.matrix_local.copy() if CROSSBOW else None


def restore(arm, snap):
    bones, bow = snap
    for pb in arm.pose.bones:
        pb.location, pb.rotation_quaternion, pb.scale = bones[pb.name]
    if CROSSBOW:
        CROSSBOW.matrix_local = bow
    bpy.context.view_layer.update()


# ---------------------------------------------------------------- cena

scene = bpy.context.scene
CROSSBOW = None
if CHAR == "aldric":
    arm = bpy.data.objects["SirAldric_Rig"]
    ORTHO, ATTACK_KEYS, pose_fn, idle_fn = ALDRIC_ORTHO, ALDRIC_ATTACK, aldric_pose, aldric_idle
else:
    arm = bpy.data.objects["Armature"]
    ORTHO, ATTACK_KEYS, pose_fn, idle_fn = LYRA_ORTHO, LYRA_ATTACK, lyra_pose, lyra_idle
    bpy.data.objects["Besta"].hide_render = True
    warm_to_reference(bpy.data.images["tripo_mat_29c490df_Diffuse"])
    CROSSBOW = bpy.data.objects.new("BestaNova", make_crossbow())
    scene.collection.objects.link(CROSSBOW)
    CROSSBOW.parent = arm
    CROSSBOW.matrix_parent_inverse = Matrix.Identity(4)
arm.animation_data.action = None
rig = Rig(arm)

scene.render.engine = "CYCLES"
try:
    cp = bpy.context.preferences.addons["cycles"].preferences
    cp.compute_device_type = "OPTIX"
    cp.get_devices()
    for dev in cp.devices:
        dev.use = True
    scene.cycles.device = "GPU"
    print("DISPOSITIVO GPU")
except Exception as e:
    print("DISPOSITIVO CPU", e)
scene.cycles.samples = 32
scene.cycles.use_denoising = False
# filtro mínimo: cada pixel fica com a cor de um ponto só, sem borda suavizada
scene.cycles.filter_width = 0.01
scene.cycles.max_bounces = 2
r = scene.render
r.resolution_x = r.resolution_y = CELL
r.resolution_percentage = 100
r.film_transparent = True
r.image_settings.file_format = "PNG"
r.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"

world = bpy.data.worlds.new("Ambiente")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.8, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.3
scene.world = world

sun_data = bpy.data.lights.new("Sol", "SUN")
sun_data.energy = LYRA_SUN if CHAR == "lyra" else 2.1
sun_data.angle = math.radians(1.5)
sun_data.color = (1.0, 0.95, 0.86)
sun = bpy.data.objects.new("Sol", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(42), 0, math.radians(-38))

ground_mesh = bpy.data.meshes.new("Chao")
ground_mesh.from_pydata([(-9, -9, 0), (9, -9, 0), (9, 9, 0), (-9, 9, 0)], [], [(0, 1, 2, 3)])
ground = bpy.data.objects.new("Chao", ground_mesh)
scene.collection.objects.link(ground)
ground.is_shadow_catcher = True

cam_data = bpy.data.cameras.new("SpriteCam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = ORTHO
cam_data.clip_end = 100.0
cam = bpy.data.objects.new("SpriteCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
elev = math.radians(ELEVATION)
# mira um ponto acima dos pés para que eles caiam em FEET_Y no quadro
lift = (FEET_Y - CELL * 0.5) / CELL * ORTHO / math.cos(elev)
target = Vector((0, 0, lift))
cam.location = target + Vector((0, -math.cos(elev), math.sin(elev))) * 30.0
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
bpy.context.view_layer.update()
co = world_to_camera_view(scene, cam, Vector((0, 0, 0)))
anchor = [co.x * CELL, (1.0 - co.y) * CELL]


# ---------------------------------------------------------------- render

os.makedirs(os.path.join(OUT, "raw"), exist_ok=True)
idle_snaps, attack_snaps = [], []
for f in range(COLS):
    pose_fn(rig, idle_fn(f))
    idle_snaps.append(snapshot(arm))
for f in range(COLS):
    pose_fn(rig, pose_at(ATTACK_KEYS, f / (COLS - 1)))
    attack_snaps.append(snapshot(arm))
anims = {"Idle": idle_snaps, "Attack": attack_snaps}


def raw_path(name, d, f):
    return os.path.join(OUT, "raw", "%s_d%d_f%02d.png" % (name, d, f))


jobs = [(name, d, f) for name in anims for d in range(ROWS) for f in range(COLS)]
if TEST:
    jobs = [("Idle", 0, 0), ("Idle", 1, 0), ("Idle", 3, 0), ("Idle", 6, 0),
            ("Attack", 1, 0), ("Attack", 1, 3), ("Attack", 1, 5), ("Attack", 1, 6)]
for n, (name, d, f) in enumerate([] if POST_ONLY else jobs):
    # a guarda do Aldric não mudou: REUSE_IDLE aproveita os quadros já prontos
    if os.environ.get("REUSE_IDLE") and name == "Idle" and os.path.exists(raw_path(name, d, f)):
        continue
    restore(arm, anims[name][f])
    arm.rotation_euler.z = math.radians(d * 360.0 / ROWS)
    r.filepath = raw_path(name, d, f)
    bpy.ops.render.render(write_still=True)
    if n % 20 == 0:
        print("QUADRO", n, "/", len(jobs))


# ---------------------------------------------------------------- paleta, sombra e contorno

def load_px(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)[::-1].copy()


def kmeans(samples, k, rounds=14):
    rng = np.random.default_rng(7)
    centers = samples[rng.choice(len(samples), k, replace=False)]
    for _ in range(rounds):
        d = ((samples[:, None, :] - centers[None, :, :]) ** 2).sum(axis=2)
        lab = d.argmin(axis=1)
        for i in range(k):
            m = lab == i
            if m.any():
                centers[i] = samples[m].mean(axis=0)
    return centers


def stylize(px, palette):
    alpha = px[..., 3]
    body = alpha >= 0.95
    shadow = (alpha >= 0.22) & ~body
    # tira os pontinhos soltos do ruído do render: sombra precisa de vizinhos
    solid = shadow | body
    around = np.zeros(alpha.shape, dtype=np.int32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dx or dy:
                around += np.roll(np.roll(solid, dy, axis=0), dx, axis=1)
    shadow &= around >= 4
    out = np.zeros_like(px)
    rgb = px[..., :3][body]
    if len(rgb):
        out[..., :3][body] = palette[((rgb[:, None, :] - palette[None, :, :]) ** 2).sum(axis=2).argmin(axis=1)]
        out[..., 3][body] = 1.0
    out[..., :3][shadow] = (0.03, 0.03, 0.05)
    out[..., 3][shadow] = SHADOW_ALPHA
    grown = np.zeros_like(body)
    grown[1:, :] |= body[:-1, :]
    grown[:-1, :] |= body[1:, :]
    grown[:, 1:] |= body[:, :-1]
    grown[:, :-1] |= body[:, 1:]
    edge = grown & ~body
    out[..., :3][edge] = OUTLINE
    out[..., 3][edge] = 1.0
    return out


raw = {job: load_px(raw_path(*job)) for job in jobs}
samples = np.concatenate([p[p[..., 3] >= 0.95][:, :3] for p in raw.values()])
rng = np.random.default_rng(3)
samples = samples[rng.choice(len(samples), min(len(samples), 30000), replace=False)]
palette = kmeans(samples, PALETTE)


def save_sheet(path, rows, cols, cells):
    sheet = np.zeros((rows * CELL, cols * CELL, 4), dtype=np.float32)
    for (row, col), px in cells.items():
        sheet[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL] = px
    img = bpy.data.images.new("folha", cols * CELL, rows * CELL, alpha=True)
    img.pixels.foreach_set(sheet[::-1].ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


if TEST:
    cells = {(i // 4, i % 4): stylize(raw[j], palette) for i, j in enumerate(jobs)}
    save_sheet(os.path.join(OUT, "teste.png"), 2, 4, cells)
else:
    for name in anims:
        cells = {(d, f): stylize(raw[(name, d, f)], palette) for d in range(ROWS) for f in range(COLS)}
        save_sheet(os.path.join(OUT, name + ".png"), ROWS, COLS, cells)
    angles = [math.degrees(math.atan2(math.sin(math.radians(d * 45.0)), math.cos(math.radians(d * 45.0)))) for d in range(ROWS)]
    with open(os.path.join(OUT, "meta.json"), "w") as fh:
        json.dump({"cell": CELL, "cols": COLS, "anchor": anchor, "angles": angles}, fh)
print("PRONTO", OUT, anchor)
