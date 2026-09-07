from __future__ import annotations

from pathlib import Path
from textwrap import wrap

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "04-report" / "figures"

WIDTH = 1800
HEIGHT = 1000
NAVY = "#17324D"
BLUE = "#2563A6"
TEAL = "#0F766E"
GREEN = "#2E7D32"
AMBER = "#C67C00"
RED = "#B42318"
PALE_BLUE = "#EAF2FB"
PALE_GREEN = "#EAF6EE"
PALE_AMBER = "#FFF4DA"
PALE_RED = "#FDEDEC"
GRAY = "#5B6670"
LIGHT = "#F5F7FA"
LINE = "#AAB4BE"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "arialbd.ttf" if bold else "arial.ttf"
    candidates = [Path("C:/Windows/Fonts") / name, Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


TITLE = font(42, True)
SUBTITLE = font(27, True)
BODY = font(25)
SMALL = font(21)


def canvas(title: str, subtitle: str = ""):
    image = Image.new("RGB", (WIDTH, HEIGHT), "white")
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, WIDTH, 92), fill=NAVY)
    draw.text((50, 21), title, font=TITLE, fill="white")
    if subtitle:
        draw.text((50, 105), subtitle, font=SMALL, fill=GRAY)
    return image, draw


def centered_text(draw: ImageDraw.ImageDraw, bounds, text: str, *, fill=NAVY, bold=False, size=25, max_chars=28):
    x1, y1, x2, y2 = bounds
    f = font(size, bold)
    lines = []
    for paragraph in text.split("\n"):
        lines.extend(wrap(paragraph, max_chars) or [""])
    heights = [draw.textbbox((0, 0), line, font=f)[3] for line in lines]
    total = sum(heights) + max(0, len(lines) - 1) * 7
    y = y1 + (y2 - y1 - total) / 2
    for line, height in zip(lines, heights):
        box = draw.textbbox((0, 0), line, font=f)
        x = x1 + (x2 - x1 - (box[2] - box[0])) / 2
        draw.text((x, y), line, font=f, fill=fill)
        y += height + 7


def box(draw, bounds, text, *, fill=PALE_BLUE, outline=BLUE, bold=False, size=25, radius=22):
    draw.rounded_rectangle(bounds, radius=radius, fill=fill, outline=outline, width=4)
    centered_text(draw, bounds, text, fill=NAVY, bold=bold, size=size)


def arrow(draw, start, end, *, color=GRAY, width=5, label=""):
    draw.line((start, end), fill=color, width=width)
    x1, y1 = start
    x2, y2 = end
    dx, dy = x2 - x1, y2 - y1
    length = max((dx * dx + dy * dy) ** 0.5, 1)
    ux, uy = dx / length, dy / length
    px, py = -uy, ux
    tip = (x2, y2)
    left = (x2 - 22 * ux + 11 * px, y2 - 22 * uy + 11 * py)
    right = (x2 - 22 * ux - 11 * px, y2 - 22 * uy - 11 * py)
    draw.polygon((tip, left, right), fill=color)
    if label:
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        bbox = draw.textbbox((0, 0), label, font=SMALL)
        pad = 8
        draw.rounded_rectangle((mx - (bbox[2] - bbox[0]) / 2 - pad, my - 34, mx + (bbox[2] - bbox[0]) / 2 + pad, my - 2), radius=8, fill="white")
        draw.text((mx - (bbox[2] - bbox[0]) / 2, my - 32), label, font=SMALL, fill=color)


def save(image: Image.Image, name: str):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    image.save(OUTPUT / name, format="PNG", optimize=True)


def flow_figure(title: str, subtitle: str, labels: list[str], name: str, colors=None):
    image, draw = canvas(title, subtitle)
    count = len(labels)
    gap = 35
    left = 50
    right = WIDTH - 50
    usable = right - left - gap * (count - 1)
    width = usable / count
    y1, y2 = 365, 635
    palette = colors or [(PALE_BLUE, BLUE)] * count
    for index, label in enumerate(labels):
        x1 = left + index * (width + gap)
        x2 = x1 + width
        fill, outline = palette[index % len(palette)]
        box(draw, (x1, y1, x2, y2), label, fill=fill, outline=outline, bold=True, size=23)
        if index < count - 1:
            arrow(draw, (x2 + 4, (y1 + y2) / 2), (x2 + gap - 4, (y1 + y2) / 2), color=NAVY)
    save(image, name)


def gantt():
    image, draw = canvas("Planification du stage", "Découpage prévisionnel sur six semaines — du 3 août au 11 septembre 2026")
    tasks = [
        ("Cadrage et exigences", 0, 1, BLUE),
        ("Architecture et données", 0, 2, TEAL),
        ("Identités et sécurité", 1, 3, GREEN),
        ("Contenus et synchronisation", 2, 4, AMBER),
        ("Interface, agent et lecteur", 2, 5, BLUE),
        ("Tests, durcissement, rapport", 4, 6, RED),
    ]
    x0, y0 = 520, 220
    col = 190
    row = 105
    draw.text((50, y0 + 5), "Activité", font=SUBTITLE, fill=NAVY)
    for week in range(6):
        x = x0 + week * col
        draw.rectangle((x, y0, x + col, y0 + 60), fill=PALE_BLUE, outline=LINE, width=2)
        centered_text(draw, (x, y0, x + col, y0 + 60), f"Semaine {week + 1}", bold=True, size=22)
    for index, (label, start, end, color) in enumerate(tasks):
        y = y0 + 60 + index * row
        draw.text((50, y + 34), label, font=BODY, fill=NAVY)
        for week in range(6):
            x = x0 + week * col
            draw.rectangle((x, y, x + col, y + row), outline=LINE, width=2)
        draw.rounded_rectangle((x0 + start * col + 12, y + 22, x0 + end * col - 12, y + row - 22), radius=16, fill=color)
    save(image, "figure-1-1-gantt.png")


def use_cases():
    image, draw = canvas("Cas d’utilisation principaux", "Les droits administratifs sont séparés des protocoles propres aux appareils")
    actors = [("Administrateur\nplateforme", 60, 245), ("Administrateur\nclient", 60, 620), ("Gestionnaire\nde contenu", 1450, 245), ("Raspberry Pi\nenrôlé", 1450, 620)]
    for text, x, y in actors:
        box(draw, (x, y, x + 285, y + 150), text, fill=LIGHT, outline=GRAY, bold=True, size=23)
    cases = [
        ("Administrer les tenants", 610, 210),
        ("Gérer membres, appareils\net licences", 610, 360),
        ("Publier contenus et playlists", 610, 510),
        ("Envoyer heartbeat et synchroniser", 610, 660),
    ]
    for text, x, y in cases:
        draw.ellipse((x, y, x + 580, y + 115), fill=PALE_BLUE, outline=BLUE, width=4)
        centered_text(draw, (x, y, x + 580, y + 115), text, bold=True, size=23)
    for a, b in [((345, 320), (610, 267)), ((345, 695), (610, 417)), ((1450, 320), (1190, 567)), ((1450, 695), (1190, 717))]:
        arrow(draw, a, b, color=GRAY, width=4)
    save(image, "figure-2-1-cas-utilisation.png")


def global_architecture():
    image, draw = canvas("Architecture fonctionnelle globale", "Aucun accès entrant n’est requis vers le réseau où se trouve l’écran")
    box(draw, (60, 250, 390, 430), "Navigateur\nd’administration", fill=PALE_BLUE, outline=BLUE, bold=True)
    box(draw, (590, 210, 1000, 470), "Plateforme centrale\nASP.NET Core\nMonolithe modulaire", fill=PALE_GREEN, outline=GREEN, bold=True)
    box(draw, (1200, 180, 1710, 330), "PostgreSQL 18\nRLS forcée", fill=LIGHT, outline=NAVY, bold=True)
    box(draw, (1200, 385, 1710, 535), "Stockage privé + ClamAV", fill=PALE_AMBER, outline=AMBER, bold=True)
    box(draw, (590, 660, 1000, 870), "Agent Raspberry Pi\n.NET Worker", fill=PALE_BLUE, outline=BLUE, bold=True)
    box(draw, (1200, 690, 1710, 840), "Lecteur React\nChromium kiosk", fill=PALE_GREEN, outline=TEAL, bold=True)
    arrow(draw, (390, 340), (590, 340), label="HTTPS + session")
    arrow(draw, (1000, 275), (1200, 255), label="EF Core / Npgsql")
    arrow(draw, (1000, 405), (1200, 455), label="flux privés")
    arrow(draw, (795, 660), (795, 470), color=RED, label="HTTPS sortant + mTLS")
    arrow(draw, (1000, 765), (1200, 765), label="loopback uniquement")
    save(image, "figure-2-2-architecture-globale.png")


def modular_monolith():
    image, draw = canvas("Architecture du monolithe modulaire", "Une unité de déploiement, des responsabilités métier explicitement séparées")
    draw.rounded_rectangle((120, 185, 1680, 875), radius=28, fill=LIGHT, outline=NAVY, width=6)
    draw.text((155, 205), "DisplayControl.Api — composition et exposition HTTP", font=SUBTITLE, fill=NAVY)
    modules = [
        ("API\nContrôleurs, autorisation, workflows", 190, 315, PALE_BLUE, BLUE),
        ("Application\nContrats et services applicatifs", 930, 315, PALE_GREEN, GREEN),
        ("Domain\nEntités, invariants, règles temporelles", 190, 590, PALE_AMBER, AMBER),
        ("Infrastructure\nEF Core, PostgreSQL, crypto, stockage", 930, 590, PALE_RED, RED),
    ]
    for text, x, y, fill, outline in modules:
        box(draw, (x, y, x + 680, y + 190), text, fill=fill, outline=outline, bold=True, size=25)
    arrow(draw, (870, 410), (930, 410), label="appelle")
    arrow(draw, (530, 505), (530, 590), label="dépend de")
    arrow(draw, (1270, 505), (1270, 590), label="implémente")
    save(image, "figure-2-3-monolithe-modulaire.png")


def data_model():
    image, draw = canvas("Modèle de données simplifié", "Les relations sensibles incluent tenant_id afin d’empêcher les références croisées")
    entities = {
        "Tenant": (70, 180), "Utilisateur / Adhésion": (470, 180), "Appareil": (870, 180), "Certificat": (1320, 180),
        "Licence": (70, 650), "Affectation": (470, 650), "Playlist / Version": (870, 650), "Contenu / Version": (1320, 650),
    }
    for text, (x, y) in entities.items():
        box(draw, (x, y, x + 340, y + 145), text, fill=PALE_BLUE if y < 500 else PALE_GREEN, outline=BLUE if y < 500 else GREEN, bold=True, size=22)
    links = [
        ("Tenant", "Utilisateur / Adhésion"), ("Tenant", "Appareil"), ("Appareil", "Certificat"),
        ("Appareil", "Licence"), ("Appareil", "Affectation"), ("Affectation", "Playlist / Version"), ("Playlist / Version", "Contenu / Version"),
    ]
    for left, right in links:
        x1, y1 = entities[left]
        x2, y2 = entities[right]
        if y1 == y2:
            arrow(draw, (x1 + 340, y1 + 72), (x2, y2 + 72), color=GRAY, width=4)
        else:
            arrow(draw, (x1 + 170, y1 + 145), (x2 + 170, y2), color=GRAY, width=4)
    draw.rounded_rectangle((520, 405, 1280, 555), radius=22, fill=PALE_AMBER, outline=AMBER, width=4)
    centered_text(draw, (520, 405, 1280, 555), "Clés étrangères composites\n(tenant_id, identifiant métier)", bold=True, size=25)
    save(image, "figure-2-4-modele-donnees.png")


def trust_boundaries():
    image, draw = canvas("Frontières de confiance et mécanismes de sécurité", "Chaque transition de zone impose une preuve adaptée au risque")
    zones = [
        ((40, 180, 530, 900), "Poste utilisateur", PALE_BLUE, BLUE),
        ((655, 180, 1145, 900), "Plateforme centrale", PALE_GREEN, GREEN),
        ((1270, 180, 1760, 900), "Raspberry Pi", PALE_AMBER, AMBER),
    ]
    for bounds, label, fill, outline in zones:
        draw.rounded_rectangle(bounds, radius=25, fill=fill, outline=outline, width=5)
        centered_text(draw, (bounds[0], bounds[1] + 15, bounds[2], bounds[1] + 90), label, bold=True, size=28)
    for bounds, text in [((105, 330, 465, 500), "Session sécurisée\nMFA + CSRF"), ((720, 330, 1080, 500), "RBAC + RLS\nAudit + stockage privé"), ((1335, 330, 1695, 500), "Clé ECDSA\nCache privé")]:
        box(draw, bounds, text, fill="white", outline=NAVY, bold=True, size=23)
    arrow(draw, (530, 415), (655, 415), color=RED, label="HTTPS")
    arrow(draw, (1270, 650), (1145, 650), color=RED, label="mTLS sortant")
    draw.text((730, 760), "Refus par défaut si l’identité, la licence, le temps ou l’intégrité sont incertains", font=BODY, fill=RED)
    save(image, "figure-2-7-frontieres-confiance.png")


def repository():
    image, draw = canvas("Organisation du dépôt source", "Le monorepo regroupe les applications, les couches serveur, les tests et le déploiement")
    columns = [
        ("apps/", ["admin-web", "player-web"], 70, BLUE, PALE_BLUE),
        ("src/", ["Domain", "Application", "Infrastructure", "Api", "DeviceAgent"], 450, GREEN, PALE_GREEN),
        ("tests/", ["Domain.Tests", "IntegrationTests", "DeviceAgent.Tests", "e2e"], 920, AMBER, PALE_AMBER),
        ("support/", ["deploy", "scripts", "docs", "tools"], 1390, RED, PALE_RED),
    ]
    for title, items, x, outline, fill in columns:
        draw.rounded_rectangle((x, 190, x + 350, 870), radius=24, fill=fill, outline=outline, width=5)
        centered_text(draw, (x, 215, x + 350, 290), title, bold=True, size=31)
        y = 320
        for item in items:
            box(draw, (x + 35, y, x + 315, y + 85), item, fill="white", outline=outline, bold=True, size=21)
            y += 105
    save(image, "figure-3-1-depot.png")


def main():
    gantt()
    use_cases()
    global_architecture()
    modular_monolith()
    data_model()
    flow_figure(
        "Parcours d’enrôlement d’un Raspberry Pi",
        "La clé privée ECDSA P-256 est créée et conservée localement",
        ["Code temporaire\nà usage unique", "Clé privée + CSR\ngénérées sur le Pi", "Validation atomique\net création appareil", "Certificat client\nlié au tenant", "Échanges suivants\nen mTLS"],
        "figure-2-5-enrolement.png",
        [(PALE_BLUE, BLUE), (PALE_AMBER, AMBER), (PALE_GREEN, GREEN), (PALE_BLUE, BLUE), (PALE_RED, RED)],
    )
    flow_figure(
        "Décision de licence et synchronisation",
        "Toute incertitude conduit à un état sûr plutôt qu’à une lecture non autorisée",
        ["Heartbeat mTLS\n+ inventaire", "Évaluer tenant, appareil, certificat, licence, horaire", "Émettre bail ES256\nborné à 24 h", "Télécharger et vérifier\ntaille + SHA-256", "Activer atomiquement\nou Not licensed"],
        "figure-2-6-licence-sync.png",
        [(PALE_BLUE, BLUE), (PALE_AMBER, AMBER), (PALE_GREEN, GREEN), (PALE_BLUE, BLUE), (PALE_RED, RED)],
    )
    trust_boundaries()
    repository()
    flow_figure(
        "Flux d’un heartbeat mTLS",
        "Le certificat présenté sur TLS est recoupé avec l’identité et l’état stockés",
        ["Agent Pi\ncertificat client", "Terminaison HTTPS\nexigeant mTLS", "Middleware appareil\nvalidation et liaison", "Workflow heartbeat\ntransaction tenant", "Décision licence +\nmanifest/version"],
        "figure-3-2-heartbeat.png",
        [(PALE_BLUE, BLUE), (PALE_RED, RED), (PALE_AMBER, AMBER), (PALE_GREEN, GREEN), (PALE_BLUE, BLUE)],
    )
    flow_figure(
        "Chaîne de validation d’un contenu",
        "Un résultat antivirus propre ne remplace pas l’approbation humaine",
        ["Dépôt en flux\net taille bornée", "Signature binaire\n+ type MIME réel", "Quarantaine\n+ analyse ClamAV", "Approbation\nhumaine", "Version immuable\n+ SHA-256"],
        "figure-3-3-validation-contenu.png",
        [(PALE_BLUE, BLUE), (PALE_AMBER, AMBER), (PALE_RED, RED), (PALE_GREEN, GREEN), (PALE_BLUE, BLUE)],
    )
    flow_figure(
        "Architecture locale agent–lecteur",
        "Le navigateur ne reçoit aucun secret d’appareil et ne lit que le manifeste actif",
        ["Service systemd\nDeviceAgent", "API locale\n127.0.0.1:8787", "État + manifeste\nautorisés", "Chromium kiosk\nlecteur React", "Écran HDMI\nétat sûr / contenu"],
        "figure-3-4-architecture-locale.png",
        [(PALE_GREEN, GREEN), (PALE_BLUE, BLUE), (PALE_AMBER, AMBER), (PALE_BLUE, BLUE), (PALE_GREEN, GREEN)],
    )
    flow_figure(
        "Scénario du Raspberry Pi virtuel",
        "Le poste Windows exécute le véritable agent contre l’API et PostgreSQL réels",
        ["Démarrer PostgreSQL,\nClamAV et API", "Enrôler / authentifier\nl’agent virtuel", "Attribuer licence\net playlist", "Synchroniser puis\ncouper l’API", "Maintenir le cache borné\npuis reprendre"],
        "figure-3-5-pi-virtuel.png",
        [(PALE_BLUE, BLUE), (PALE_AMBER, AMBER), (PALE_GREEN, GREEN), (PALE_RED, RED), (PALE_BLUE, BLUE)],
    )
    print(f"{len(list(OUTPUT.glob('figure-*.png')))} figures générées dans {OUTPUT}")


if __name__ == "__main__":
    main()
