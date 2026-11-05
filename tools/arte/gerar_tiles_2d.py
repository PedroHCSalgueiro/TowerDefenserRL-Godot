"""Prepara os assets do mapa 2D (cena de teste `scenes/teste_mapa_2d.tscn`) a partir das artes que já existem.
Não desenha arte nova: só reduz, recorta e projeta no isométrico 2:1.

Saída em assets/cenario/valcoroa/mapa2d/:
- pecas/<nome>.png  peças reduzidas por FATOR INTEIRO do pixel nativo (a grade de pixels fica certa) + pecas.json com
                    o ponto do pé (onde a peça encosta no chão) de cada uma;
- chao.png          atlas de losangos 48x24: lajes (parede_b) e caminho (parede_a) projetados de cima, 4x4 variantes que
                    emendam (a textura continua de uma casa para a outra), grama e terra (tiles 48x24 que já existiam);
- borda.png         saia da plataforma (12 px de tijolo de parede_c) embaixo das bordas da frente, com rebordo de 1 px;
- muralha.png       muralha de meia casa (40 px + 12 de saia), ameias, cantos e pontas, com luz por face;
- mapa2d.json       nomes -> posição no atlas, tamanhos e origens.

Uso (da raiz do repositório): python tools/arte/gerar_tiles_2d.py
Precisa de numpy e Pillow, e dos recortes nativos das peças em `Arte/cenario/valcoroa/recortes/` (arte de trabalho, fora
do repositório; ver CLAUDE.md). O resto (texturas de parede, losangos de grama, cristal do núcleo e portal) vem de
`assets/cenario/` do próprio repositório. O jogo não precisa deste script para rodar: os PNGs e o mapa2d.json gerados
ficam no repositório; ele só serve para gerar tudo de novo.
"""
import json, os, collections
import numpy as np
from PIL import Image

# assets/cenario/ do repositório (este arquivo fica em tools/arte/) e os recortes na pasta de arte, ao lado do repositório
JOGO = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "cenario").replace("\\", "/") + "/"
REC = os.environ.get("RECORTES", os.path.join(os.path.dirname(JOGO.rstrip("/")), "..", "..", "Arte", "cenario", "valcoroa", "recortes"))
REC = os.path.normpath(REC).replace("\\", "/") + "/"
OUT = JOGO + "valcoroa/mapa2d/"
os.makedirs(OUT + "pecas", exist_ok=True)

TW, TH = 48, 24           # losango
WALL, SKIRT, MER_H, MER_T, MER_L, RIM = 40, 12, 6, 4, 6, 3
LEFT, RIGHT = np.array([0.92, 0.94, 1.0]), np.array([0.65, 0.68, 0.82])
TOP = np.array([0.50, 0.55, 0.65]) * 255
RIM_C = np.array([0.45, 0.48, 0.56]) * 255
OUTLINE = 0.45


def rgb(path, k=1.0):
    return (np.asarray(Image.open(path).convert("RGB")).astype(float) * k)


# ------------------------------------------------------------------ peças: fator inteiro + pé
ALVO = {  # altura desejada em pixels da arte (herói ~34)
    "Lote01_0": ("tocha", 30), "Lote01_1": ("braseiro", 20), "Lote01_2": ("barril", 18), "Lote01_3": ("caixa", 16),
    "Lote02_0": ("pilar", 52), "Lote02_1": ("coluna", 32), "Lote02_2": ("cristal", 30), "Lote02_3": ("pedra_pe", 20),
    "Lote03_0": ("arvore", 58), "Lote03_1": ("seca", 40), "Lote03_2": ("toco", 26), "Lote03_3": ("moita", 24),
    "Lote03_4": ("espinho", 22), "Lote05_0": ("torre", 86), "Lote05_1": ("arco", 58), "Lote05_2": ("obelisco", 50),
    "Pixel__0": ("raiz", 13), "Pixel__1": ("capim", 9), "Pixel__2": ("cranio", 11), "Pixel__3": ("pedras", 12),
    "Pixel__4": ("cogumelo", 14), "Pixel__5": ("tabua", 9),
}


def reduz_inteiro(im, k):
    """Cada bloco k x k vira 1 pixel: a cor mais comum entre os opacos; opaco se a maioria for opaca."""
    a = np.asarray(im.convert("RGBA"))
    h, w = a.shape[0] // k * k, a.shape[1] // k * k
    a = a[:h, :w]
    out = np.zeros((h // k, w // k, 4), np.uint8)
    for j in range(h // k):
        for i in range(w // k):
            b = a[j * k:(j + 1) * k, i * k:(i + 1) * k].reshape(-1, 4)
            op = b[b[:, 3] > 0]
            if len(op) * 2 < len(b):
                continue
            cor = collections.Counter(map(tuple, op[:, :3])).most_common(1)[0][0]
            out[j, i, :3] = cor
            out[j, i, 3] = 255
    return Image.fromarray(out)


def pe(im):
    """Âncora "base": centro dos pixels opacos das 3 linhas de baixo, na linha mais baixa. Serve para o que é achatado
    no chão (capim, pedrinhas, crânio), onde a linha mais baixa já é o contato."""
    a = np.asarray(im)[..., 3] > 0
    ys = np.nonzero(a.any(1))[0]
    base = ys.max()
    xs = np.nonzero(a[max(0, base - 2):base + 1].any(0))[0]
    return [int(round((xs.min() + xs.max() + 1) / 2)), int(base + 1)]


def pe_pegada(im):
    """Âncora "pegada": centro da base de um objeto de pé desenhado em isométrico. A linha mais baixa é a ponta da
    frente da pegada; subindo dela, a largura cresce até a largura da base (os lados do losango) e então para. O
    contato com o chão fica no centro da pegada, largura_da_base / 4 acima da ponta (o losango é 2:1)."""
    a = np.asarray(im)[..., 3] > 0
    ys = np.nonzero(a.any(1))[0]
    base = int(ys.max())
    larg, meio, y = 0, 0.0, base
    for y in range(base, max(ys.min(), base - a.shape[0] // 2) - 1, -1):
        xs = np.nonzero(a[y])[0]
        w = int(xs.max() - xs.min() + 1)
        if w + 1 < larg:             # a largura voltou a cair: passou da base
            break
        if w >= larg:
            larg, meio = w, (xs.min() + xs.max() + 1) / 2
    # round() do Python arredonda o meio para o par (52,5 -> 52, 25,5 -> 26). As âncoras de mapa2d.json foram geradas
    # assim; trocar a regra mudaria a da árvore (52 -> 53). Os testes reproduzem a mesma regra.
    return [int(round(meio)), int(round(base + 1 - larg / 4))], larg


# Como achar o pé de cada peça. "pegada": objeto de pé (centro da base); "base": coisa achatada no chão (linha mais
# baixa); a torre e o portal ficam como estão nesta etapa. Correção manual: o campo "ajuste" [dx, dy] de cada peça
# em mapa2d.json, que é mantido quando o gerador roda de novo e somado ao pé no jogo (Map2DAssets.prop).
MODO = {
    "tocha": "pegada", "braseiro": "pegada", "barril": "pegada", "caixa": "pegada", "pilar": "pegada", "coluna": "pegada",
    "cristal": "pegada", "pedra_pe": "pegada", "arvore": "pegada", "seca": "pegada", "toco": "pegada",
    "moita": "pegada", "espinho": "pegada", "obelisco": "pegada", "cristal_nucleo": "pegada",
    "arco": "base", "torre": "base", "portal": "portal",
    "raiz": "base", "capim": "base", "cranio": "base", "pedras": "base", "cogumelo": "base", "tabua": "base",
}
try:
    _antes = json.load(open(OUT + "mapa2d.json", encoding="utf-8"))["pecas"]
except (OSError, ValueError, KeyError):
    _antes = {}


def pe_pilares(im):
    """Âncora "portal": o meio entre os pés dos dois pilares (a ponta de baixo de cada metade da imagem). É o centro da
    passagem no chão, o ponto que fica no meio da espessura da muralha."""
    a = np.asarray(im)[..., 3] > 0
    w = a.shape[1]
    pes = []
    for x0, x1 in ((0, w // 2), (w // 2, w)):
        ys, xs = np.nonzero(a[:, x0:x1])
        y = ys.max()
        xs_base = xs[ys == y] + x0
        pes.append(((xs_base.min() + xs_base.max() + 1) / 2, y + 1))
    return [int(round((pes[0][0] + pes[1][0]) / 2)), int(round((pes[0][1] + pes[1][1]) / 2))]


def portal_de_arco(src, k):
    """Portal = o arco do recorte nativo reduzido por fator inteiro, com o redemoinho pintado só na abertura (os
    pixels transparentes que têm pedra dos dois lados na mesma linha e pedra acima na mesma coluna)."""
    red = reduz_inteiro(Image.open(src), k)
    red = red.crop(red.getbbox())
    a = np.asarray(red).copy()
    op = a[..., 3] > 0
    h, w = op.shape
    esq = np.maximum.accumulate(op, axis=1)
    dir_ = np.maximum.accumulate(op[:, ::-1], axis=1)[:, ::-1]
    cima = np.maximum.accumulate(op, axis=0)
    ab = (~op) & esq & dir_ & cima
    ys, xs = np.nonzero(ab)
    cx, cy = xs.mean(), ys.mean()
    rx, ry = (xs.max() - xs.min() + 1) / 2, (ys.max() - ys.min() + 1) / 2
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    ang = np.arctan2((yy - cy) / ry, (xx - cx) / rx)
    esp = np.sin(ang * 3 + r * 9) > 0
    pal = np.array([[40, 40, 140], [70, 80, 220], [120, 150, 255], [200, 220, 255]])
    idx = np.clip((1 - r) * 2.2 + esp * 0.9, 0, 3).astype(int)
    a[ab, :3] = pal[idx[ab]]
    a[ab, 3] = 255
    return Image.fromarray(a), [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)]


def registra(nome, im, k):
    modo = MODO[nome]
    if modo == "pegada":
        p, larg = pe_pegada(im)
    elif modo == "portal":
        p, larg = pe_pilares(im), 0
    else:
        p, larg = pe(im), 0
    pecas[nome] = {"pe": p, "modo": modo, "base": larg, "tamanho": list(im.size), "fator": k,
                   "ajuste": _ajuste(nome)}


def _ajuste(nome):
    """O ajuste manual que já estava no mapa2d.json vale mais que o padrão daqui (quem editou o json à mão ganha)."""
    feito = _antes.get(nome, {}).get("ajuste")
    if feito and list(feito) != [0, 0]:
        return list(feito)
    return AJUSTE.get(nome, [0, 0])


# Ajuste manual inicial, em pixels da arte (só vale se o mapa2d.json não tiver outro):
# - árvore: a pegada pega a raiz da esquerda; o tronco toca o chão 8 px à direita e 3 px acima;
# - moita e espinheiro: são achatados (sem lados retos), então o contato fica mais perto da linha de baixo.
# - portal: os pés dos pilares ficam na linha do chão (y = 0), mas o tile da muralha desenha a face de dentro até o
#   fundo da saia (SKIRT = 12 px abaixo do chão), por cima do chão da casa da frente. A base visível da parede fica
#   12 px abaixo; o portal desce os mesmos 12 px para os pilares encostarem nela (medido coluna a coluna).
AJUSTE = {"arvore": [8, -3], "moita": [0, 4], "espinho": [0, 3], "portal": [0, -SKIRT]}


pecas = {}
for src, (nome, alvo) in ALVO.items():
    im = Image.open(REC + src + ".png")
    k = max(1, int(round(im.height / alvo)))
    red = reduz_inteiro(im, k)
    bb = red.getbbox()
    red = red.crop(bb)
    red.save(OUT + f"pecas/{nome}.png")
    registra(nome, red, k)
# o cristal do núcleo vem da versão do jogo
for nome in ("cristal_nucleo",):
    im = Image.open(JOGO + f"valcoroa/pecas/{nome}.png").convert("RGBA")
    im.save(OUT + f"pecas/{nome}.png")
    registra(nome, im, 1)
# o portal: o arco nativo (56x77) por fator 2, para caber na muralha de 40 px; a abertura fica guardada
PORTAL_FATOR = 2
_portal, _abertura = portal_de_arco(REC + "Lote05_1.png", PORTAL_FATOR)
_portal.save(OUT + "pecas/portal.png")
registra("portal", _portal, PORTAL_FATOR)
pecas["portal"]["abertura"] = _abertura


# ------------------------------------------------------------------ chão (losangos 48x24)
def losango_mask():
    m = np.zeros((TH, TW), bool)
    for y in range(TH):
        k = y if y < TH // 2 else TH - 1 - y
        m[y, TW // 2 - 1 - 2 * k: TW // 2 + 1 + 2 * k] = True
    return m


MASK = losango_mask()


def textura_quadrada(path, lado, k=1.0):
    return np.asarray(Image.open(path).convert("RGB").resize((lado, lado), Image.NEAREST)).astype(float) * k


def losango_de_textura(tex, cx, cz, per_cell=24):
    """Projeta uma textura vista de cima no losango da casa (cx, cz): o texel do chão (u, v) vem do ponto do chão sob
    o pixel, então casas vizinhas continuam a textura (com 96 texels = 4 casas, as variantes repetem a cada 4)."""
    out = np.zeros((TH, TW, 4), np.uint8)
    S = tex.shape[0]
    for y in range(TH):
        for x in range(TW):
            if not MASK[y, x]:
                continue
            sx, sy = x + 0.5 - TW / 2, y + 0.5 - TH / 2           # pixel relativo ao centro da casa
            gx = (sx / (TW / 2) + sy / (TH / 2)) / 2 + cx            # ponto do chão (em casas)
            gz = (sy / (TH / 2) - sx / (TW / 2)) / 2 + cz
            u = int(np.floor(gx * per_cell)) % S
            v = int(np.floor(gz * per_cell)) % S
            out[y, x, :3] = np.clip(tex[v, u], 0, 255)
            out[y, x, 3] = 255
    return out


chao_tiles = collections.OrderedDict()
lajes = textura_quadrada(JOGO + "valcoroa/parede_b.png", 96, 0.8)
pedra = textura_quadrada(JOGO + "valcoroa/parede_a.png", 96, 0.95)
for cz in range(4):
    for cx in range(4):
        chao_tiles[f"laje_{cx}_{cz}"] = losango_de_textura(lajes, cx, cz)
        chao_tiles[f"caminho_{cx}_{cz}"] = losango_de_textura(pedra, cx, cz)
# soleira: o chão do caminho só na metade de dentro da casa do portal (a espessura da muralha, que é de meia casa).
# "soleira_z": muralha ao longo de z, aberta em +x (fica a metade de x >= 0); "soleira_x": aberta em +z.
for cz in range(4):
    for cx in range(4):
        cheio = chao_tiles[f"caminho_{cx}_{cz}"]
        for lado in ("z", "x"):
            t = cheio.copy()
            for y in range(TH):
                for x in range(TW):
                    sx, sy = x + 0.5 - TW / 2, y + 0.5 - TH / 2
                    gx = (sx / (TW / 2) + sy / (TH / 2)) / 2
                    gz = (sy / (TH / 2) - sx / (TW / 2)) / 2
                    if (gx if lado == "z" else gz) < 0:
                        t[y, x] = 0
            chao_tiles[f"soleira_{lado}_{cx}_{cz}"] = t
# grama e terra: os losangos de 48x24 que já existiam, escurecidos para o clima da noite
for nome, k in [("lisa_01", 0.45), ("lisa_02", 0.45), ("lisa_03", 0.45), ("lisa_04", 0.45), ("escura_01", 0.5),
                ("pedrinhas_01", 0.45), ("terra_01", 0.5), ("caminho_01", 0.45), ("caminho_02", 0.45)]:
    a = np.asarray(Image.open(JOGO + f"grama/{nome}.png").convert("RGBA")).astype(float)
    # noite: mais escuro, menos saturado e puxado para o azul (a terra laranja some no chão)
    cinza = a[..., :3].mean(-1, keepdims=True)
    a[..., :3] = (a[..., :3] * 0.55 + cinza * 0.45) * k * np.array([0.9, 0.95, 1.12])
    chao_tiles[("grama_" if nome.startswith(("lisa", "escura", "pedrinhas")) else "terra_") + nome] = np.clip(a, 0, 255).astype(np.uint8)


# ------------------------------------------------------------------ prismas (saia e muralha) desenhados em pixels
def proj(x, z, y_px, ox, oy):
    """Ponto do mundo (x, z em casas a partir do centro da casa; y em pixels da arte para cima) -> pixel do canvas."""
    return ox + (x - z) * TW / 2, oy + (x + z) * TH / 2 - y_px


def poligono_mask(shape, pts):
    from PIL import ImageDraw
    im = Image.new("L", (shape[1], shape[0]), 0)
    ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=255)
    return np.asarray(im) > 0


PAREDE = rgb(JOGO + "valcoroa/parede_c.png")
PH, PW = PAREDE.shape[:2]


def face_vertical(canvas, a, b, y0, y1, ox, oy, tint, u_base):
    """Face vertical entre os pontos do chão a e b (x, z), de y0 a y1 (px). A textura vista de frente anda 1 coluna por
    pixel na horizontal da tela; a linha é a altura em pixels (os tijolos ficam no tamanho original)."""
    pts = [proj(a[0], a[1], y0, ox, oy), proj(b[0], b[1], y0, ox, oy), proj(b[0], b[1], y1, ox, oy), proj(a[0], a[1], y1, ox, oy)]
    m = poligono_mask(canvas.shape, pts)
    ys, xs = np.nonzero(m)
    xa, ya = proj(a[0], a[1], 0, ox, oy)
    xb, yb = proj(b[0], b[1], 0, ox, oy)
    for y, x in zip(ys, xs):
        t = (x + 0.5 - xa) / (xb - xa) if xb != xa else 0
        ground_y = ya + t * (yb - ya)
        h = int(np.floor(ground_y - (y + 0.5)))               # altura do pixel acima do chão
        u = int(u_base + (x - xa)) % PW
        v = (PH - 1 - (h % PH)) % PH
        c = PAREDE[v, u] * tint
        if h >= y1 - 1:                                       # quina de cima: linha clara
            c = c * 1.3
        canvas[y, x, :3] = np.clip(c, 0, 255)
        canvas[y, x, 3] = 255


def topo(canvas, x0, x1, z0, z1, y, ox, oy, cor):
    pts = [proj(x0, z0, y, ox, oy), proj(x1, z0, y, ox, oy), proj(x1, z1, y, ox, oy), proj(x0, z1, y, ox, oy)]
    m = poligono_mask(canvas.shape, pts)
    canvas[m, :3] = cor
    canvas[m, 3] = 255
    # contorno de 1 px
    borda = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    canvas[borda, :3] = cor * OUTLINE


def prisma(canvas, x0, x1, z0, z1, y0, y1, ox, oy, u_x, u_z, cor_topo=TOP):
    """Caixa com as faces que a câmera vê: +z (esquerda-baixo, iluminada), +x (direita-baixo, sombra) e o topo."""
    face_vertical(canvas, (x0, z1), (x1, z1), y0, y1, ox, oy, LEFT, u_x)
    face_vertical(canvas, (x1, z1), (x1, z0), y0, y1, ox, oy, RIGHT, u_z)
    topo(canvas, x0, x1, z0, z1, y1, ox, oy, cor_topo)


CW, CH = 72, 104             # canvas de cada peça de muralha
OX, OY = CW // 2, CH - 34    # centro da casa (no chão) dentro do canvas
mer_t, mer_l, rim = MER_T / 24, MER_L / 24, RIM / 24


def ameias(canvas, along_z, a0, a1, fixo, anchor, ox, oy, u):
    step = 1 / 3
    c = anchor - mer_l / 2
    while c - mer_l / 2 > a1 + 1e-6:
        c -= step
    pecas_ = []
    while c - mer_l / 2 >= a0 - 1e-6:
        pecas_.append(c)
        c -= step
    for c in sorted(pecas_, key=lambda v: v):   # de trás para a frente
        if along_z:
            prisma(canvas, fixo, fixo + mer_t, c - mer_l / 2, c + mer_l / 2, WALL, WALL + MER_H, ox, oy, u, u)
        else:
            prisma(canvas, c - mer_l / 2, c + mer_l / 2, fixo, fixo + mer_t, WALL, WALL + MER_H, ox, oy, u, u)


muralha = collections.OrderedDict()
for var in range(4):                      # variante = posição % 4 ao longo da parede (a textura continua)
    u = var * 24
    for ponta in (False, True):
        # parede ao longo de z (aberta em +x): x de 0 a 0,5; na ponta da frente avança o rebordo em +z
        c = np.zeros((CH, CW, 4), np.uint8)
        z1 = 0.5 + (rim if ponta else 0)
        prisma(c, 0, 0.5, -0.5, z1, -SKIRT, WALL, OX, OY, u, u)
        ameias(c, True, -0.5, z1, 0.0, z1 if ponta else 0.5, OX, OY, u)
        muralha[f"z_{var}" + ("_ponta" if ponta else "")] = c
        # parede ao longo de x (aberta em +z)
        c = np.zeros((CH, CW, 4), np.uint8)
        x1 = 0.5 + (rim if ponta else 0)
        prisma(c, -0.5, x1, 0, 0.5, -SKIRT, WALL, OX, OY, u, u)
        ameias(c, False, -0.5, x1, 0.0, x1 if ponta else 0.5, OX, OY, u)
        muralha[f"x_{var}" + ("_ponta" if ponta else "")] = c
c = np.zeros((CH, CW, 4), np.uint8)
prisma(c, 0, 0.5, 0, 0.5, -SKIRT, WALL, OX, OY, 0, 0)
ameias(c, True, 0, 0.5, 0.0, 0.5, OX, OY, 0)
ameias(c, False, 0, 0.5, 0.0, 0.5, OX, OY, 0)
muralha["canto"] = c

# ------------------------------------------------------------------ saia da frente (embaixo da casa aberta da borda)
BW, BH = 56, 44
BOX, BOY = BW // 2, 14          # centro da casa dentro do canvas da saia
borda = collections.OrderedDict()
for var in range(4):
    u = var * 24
    for lado in ("z", "x", "zx"):
        c = np.zeros((BH, BW, 4), np.uint8)
        if "z" in lado:   # borda de baixo-esquerda (casa na última linha de z): face +z
            face_vertical(c, (-0.5, 0.5), (0.5, 0.5), -SKIRT, 0, BOX, BOY, LEFT, u)
        if "x" in lado:   # borda de baixo-direita (casa na última coluna de x): face +x
            face_vertical(c, (0.5, 0.5), (0.5, -0.5), -SKIRT, 0, BOX, BOY, RIGHT, u)
        # rebordo: a linha de cima da saia vira meio-fio liso
        top_rows = np.zeros(c.shape[:2], bool)
        for y in range(BH):
            for x in range(BW):
                if c[y, x, 3] and (y == 0 or not c[y - 1, x, 3]):
                    top_rows[y, x] = True
        c[top_rows, :3] = RIM_C
        borda[f"{lado}_{var}"] = c


# ------------------------------------------------------------------ atlas + json
def atlas(tiles, w, h, nome):
    n = len(tiles); cols = 8; rows = (n + cols - 1) // cols
    A = np.zeros((rows * h, cols * w, 4), np.uint8)
    idx = {}
    for k, (key, t) in enumerate(tiles.items()):
        r, col = divmod(k, cols)
        A[r * h:r * h + t.shape[0], col * w:col * w + t.shape[1]] = t
        idx[key] = [col, r]
    Image.fromarray(A).save(OUT + nome + ".png")
    return idx


meta = {
    "tile": [TW, TH],
    "chao": {"tamanho": [TW, TH], "centro": [TW // 2, TH // 2], "tiles": atlas(chao_tiles, TW, TH, "chao")},
    "borda": {"tamanho": [BW, BH], "centro": [BOX, BOY], "tiles": atlas(borda, BW, BH, "borda")},
    "muralha": {"tamanho": [CW, CH], "centro": [OX, OY], "tiles": atlas(muralha, CW, CH, "muralha")},
    "pecas": pecas,
}
json.dump(meta, open(OUT + "mapa2d.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("ok", len(chao_tiles), len(borda), len(muralha), len(pecas))
