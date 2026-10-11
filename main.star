load("animation.star", "animation")
load("encoding/base64.star", "base64")
load("http.star", "http")
load("random.star", "random")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

# summary.json built by exporter/gtnh_export.py from the GTNH server files.
DEFAULT_SUMMARY_URL = "https://www.matthewsand.info/gtnhSummary.json"

# Tidbyt caps an app at 15s (300 frames at 50ms), so 5 cards x 60 frames.
FRAMES_PER_CARD = 60
CARDS_SHOWN = 5

# 10x10 item icons (PNG, base64). Sources live in icons/.
ICONS = {
    "book": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAV0lEQVR42mNgIBIwMjAwMFR5qf3Hp6ht2y1GFhinYs4iDAVPHt5gWNLcxsDAwMDAgiwxY8okODsjJw9FE4pCdEmcCqlrYkdKHN7gYWFgYGC48uQDA9UAACcuFpQpOO98AAAAAElFTkSuQmCC",
    "clock": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAcUlEQVR42mNkQAIfDxn9R+bz251jhLEZkRXw8Qshq2P49PEdXAPjx0NG/2EKln7cgKIwmj8AroEJJoiuCF2MCV0g2qqYIdqqGEMxE4pVSAqQ2cg+heP/F13+/7/ogiL28ZDRfxTP4AKfPr4jIXiIDXAA3xlD9dwO5EkAAAAASUVORK5CYII=",
    "diamond": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAc0lEQVR42mNgQAPSRa3/pYta/zPgA9JFrf/Pf/////z3/7gVwxRt/Pj/f80LCEZWzIRNkyPzVwaiTXO9h2oqiok7v+B2P1zh2o8MDMFsECvf/cVUyILM2f+Xm+HkNwjbnAtP0MDch83XjOiKkflP+6rh8gBoplwdpJoNzQAAAABJRU5ErkJggg==",
    "feather": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAOElEQVR42s3MsREAIAzDQB3jZ6cMkH3ch47ShA7VfwKTpJbUAMuhqoLbKTPP7QcEMEIR4cEYvbQB0tBF6g+WdJ4AAAAASUVORK5CYII=",
    "grass": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAkklEQVR42o2OoQ7CMBRFz5rntpBgphfEZAWKr+CXCH8zjeITUE9MIkh1zcSoICEBQbqUDpJd07yee14eLEwBcDjtXrfrwKZdk78Ax/2lMMBPGOcYAbAq9AxYFe4tVN1Iv31iVUBHAEw0rArOB6ruA1bnx9eNU9H5QFOXE2jqEufDvJiWYiH9Mzn8J802pkIuLcobGkA6uygmvGgAAAAASUVORK5CYII=",
    "heart": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAcElEQVR42mNgIAVU8fH9r+Lj+49PjKWKj+9/ho4OhHflyv+2T58YsYkxwXTIlpUxZOjoMKAoQgJwhY+7uhgYGBgYsCliYGBgYGr79IlxxpUrWCVnXLnC0PbpEyPcRGyKkRVh9f0jKyuMEMCpmIESAAD5pDXE//rdWQAAAABJRU5ErkJggg==",
    "leatherBoots": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAUklEQVR42mNgoCmIdzP6j43NwMDAwIRLAl2MiVjbaKAw3s3of7yb0X9lIRYMSWUhFrg7mWACd9/9wVB4990fuGImmAADAwPDwl3nGGGKYGyYHABWTR8TGuMy1QAAAABJRU5ErkJggg==",
    "map": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAW0lEQVR42mNgIBIwMjAwMNw8Pus/PkXqlmmMLDBOy61pcIlHV7fA2bMCtzEwMDAwMKHrRlYkp+0DZzNhU7Rwlw+KIhSFyCbVFmK6E8NqdJNggAXd0QwMWQz0AQDRHBeylDdEJgAAAABJRU5ErkJggg==",
    "pickaxe": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAmElEQVR42mNkQAN582b9h7EnJaUxwtgs6Ir0vT3h/Atzff4/efWVwadyPyMjLhNhGoy3ZDIYJG/BVMjAwMCwpd3xv4wYN8NZn+kMDAwMDBe3bmdgwqZIWIiP4cmrrwwXt26HizNhM+ntu08MPpX7sdrGsKXd8f/xmf7/t7Q7/sfmZkZkk2A+xGYQI8xNeK2DuZGQIgYGBgYA2xRGcLZen3MAAAAASUVORK5CYII=",
    "pig": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAhklEQVR42o2OTQqDMBSEv5RAhTZkIdStd9DrewAh3sGtCxdPLFgQXhelQdGAs5phvvdjlqZRgNV7AKwIZ7LRiLB6HwcO4Lb4w8mNz7pGVXl33a58VBXGGOYQMHMIygXduCi7Dfei2JWfYTgHpW3JyhKApe+jP4CTc0zj+AvOkaVOv/I8+eMXsNAoUtUD8VwAAAAASUVORK5CYII=",
    "skull": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAZElEQVR42pWNyw2AIBAFZ4ltCGXp1QZIoCGvWhZYiF7cRERInNvbzxvhJqd08oF1TgBM7+i5G57D0dri6Mi5/uoBIAAaWoiIGA0xeGLwtHLVuO4bAMs0F43/1S1loVbezWoEuAANI0jDGyrqewAAAABJRU5ErkJggg==",
    "sword": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAi0lEQVR42mNkwAPmrVj+n4EQmLdi+f9fv379//Xr1/95K5b/Z8KlKCYomGHTrl2YEjBrYCat2bIFbhpWxXgVYVOMrogRxtjS7vhfWIiP4Tp/BAMDAwNDUkQkI7JCJpgiGTFuhrfvPsEVoJvING/F8v+vFNMYnrz6yuBTuZ8Rm2lwExkYGOCKYABdMQBI+WiStxfQcgAAAABJRU5ErkJggg==",
    "witherSkull": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAVUlEQVR42o1P2w2AQAjjLs7RSdh/j3YR/FAuHiYKPwQofZg1a9w9/nDHcwKwXSW9GSuoPFw4d48sAAFgze4eixHAp0dJY3ZTzwyRHkkaSav7tnRX2U64PyzDiAXHJQAAAABJRU5ErkJggg==",
    "wrench": "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAOklEQVR42mNgwAFOnLjw/8SJC/8Z8AFkBTA2E7EamLBJbtmyA67IwsKAEasJNTUd+N1GZ0VEhxcpAACXukYRNUn3cgAAAABJRU5ErkJggg==",
}

GT_ORANGE = "#FFAA00"
LABEL_COLOR = "#AAAAAA"

def main(config):
    resp = http.get(config.get("summary_url", DEFAULT_SUMMARY_URL), ttl_seconds = 300)
    if resp.status_code != 200:
        return render.Root(
            child = render.Column(
                children = [
                    header(),
                    render.WrappedText("No data from server", color = "#F44", font = "tom-thumb"),
                ],
            ),
        )
    summary = resp.json()
    players = summary.get("players", [])

    # Quests and claims always show; group/player highlights fill the rest at random.
    fixed = group_cards(summary)
    pool = highlight_cards(summary, players)
    shuffle(pool)
    cards = (fixed + pool)[:CARDS_SHOWN]

    return render.Root(
        delay = 50,
        child = render.Column(
            children = [
                animated_header(len(cards) * FRAMES_PER_CARD),
                render.Sequence(children = [animate_card(c) for c in cards]),
            ],
        ),
    )

# ---------- Cards ----------

def group_cards(summary):
    cards = []
    done = summary.get("quests_completed")
    total = summary.get("quests_total")
    if done != None:
        if total:
            cards.append(card("Quests Done", "%d/%d" % (done, total), GT_ORANGE, icon = "book", bar = done / total, sub = format_percent(done / total)))
        else:
            cards.append(card("Quests Done", format_number(done), GT_ORANGE, icon = "book"))

    chunks = summary.get("chunks_claimed")
    if chunks != None:
        cards.append(card("Chunks Claimed", format_number(chunks), "#7EC3C4", icon = "map"))
    return cards

def highlight_cards(summary, players):
    cards = []

    latest = summary.get("latest_quest")
    if latest != None:
        by = find_player(players, latest["by"]) or {"name": latest["by"]}
        cards.append(card("Latest Quest", latest["name"], "#FFFF1E", wrap = True, player = by, players = players))

    if not players:
        return cards

    mvp = top(players, "quests_first")
    if mvp != None and mvp.get("quests_first"):
        # Too wide for tb-8 next to the icon, so this one uses the small font.
        cards.append(card("Quest MVP", "%d completed" % mvp["quests_first"], "#FFFF1E", icon = "diamond", player = mvp, players = players, value_font = "tom-thumb"))

    playtime = group_total(players, "playtime_s")
    if playtime:
        cards.append(card("Group Playtime", format_duration(playtime), GT_ORANGE, icon = "clock"))

    meters = group_total(players, "distance_m")
    if meters:
        cards.append(card("Group Traveled", format_number(meters // 1000) + "km", "#7EB07E", icon = "leatherBoots"))

    clumsy = top(players, "deaths")
    if clumsy != None and clumsy.get("deaths"):
        cards.append(card("Most Deaths", "%d" % clumsy["deaths"], "#F44", icon = "skull", player = clumsy, players = players))

    return cards + player_cards(players)

# Per-person stats: each card shows one randomly picked player.
PLAYER_STATS = [
    ("playtime_s", "Playtime", GT_ORANGE, "clock"),
    ("last_death", "Since Death", "#7EB07E", "heart"),
    ("blocks_placed", "Blocks Placed", "#7EC3C4", "grass"),
    ("deaths", "Deaths", "#F44", "skull"),
    ("mob_kills", "Mob Kills", "#E99797", "sword"),
    ("distance_m", "Traveled", "#7EB07E", "leatherBoots"),
    ("gt_ores_mined", "GT Ores Mined", "#7EC3C4", "pickaxe"),
    ("gt_tools_crafted", "GT Tools Made", "#FF6400", "wrench"),
    ("boss_kills", "Bosses Slain", "#BF74C0", "witherSkull"),
    ("jumps", "Jumps", "#FFFF1E", "feather"),
    ("animals_bred", "Animals Bred", "#F7A1C4", "pig"),
]

def player_cards(players):
    now = time.now().unix
    cards = []
    for key, label, color, icon in PLAYER_STATS:
        has_stat = [p for p in players if p.get(key) != None]
        if not has_stat:
            continue
        p = has_stat[random.number(0, len(has_stat) - 1)]
        value = p[key]
        if key == "playtime_s":
            text = format_duration(value)
        elif key == "last_death":
            text = format_duration(now - value)
        elif key == "distance_m":
            text = format_number(value // 1000) + "km"
        else:
            text = format_number(value)
        cards.append(card(label, text, color, icon = icon, player = p, players = players))
    return cards

def find_player(players, name):
    for p in players:
        if p["name"] == name:
            return p
    return None

PLAYER_COLORS = ["#5BC0EB", "#9BC53D", "#F7A1C4", "#FDE74C"]

def player_color(players, player):
    # Stable per person: players arrive sorted by name.
    for i, p in enumerate(players):
        if p["name"] == player["name"]:
            return PLAYER_COLORS[i % len(PLAYER_COLORS)]
    return LABEL_COLOR

def group_total(players, key):
    total = 0
    for p in players:
        total += int(p.get(key, 0))
    return total

def top(players, key):
    best = None
    for p in players:
        if best == None or p.get(key, 0) > best.get(key, 0):
            best = p
    return best

# ---------- Rendering ----------

def header():
    return render.Stack(
        children = [
            render.Box(width = 64, height = 6, color = "#2B2B3A"),
            render.Row(
                main_align = "center",
                expanded = True,
                children = [render.Text("GREGTECH STATS", color = GT_ORANGE, font = "CG-pixel-3x5-mono", offset = -1)],
            ),
        ],
    )

def animated_header(duration):
    # Like the original app: drop in at the start, slide back up at the end.
    return animation.Transformation(
        child = header(),
        height = 6,
        duration = duration,
        keyframes = [
            animation.Keyframe(percentage = 0.0, transforms = [animation.Translate(0, -6)], curve = "ease_in_out"),
            animation.Keyframe(percentage = 0.025, transforms = [animation.Translate(0, 0)]),
            animation.Keyframe(percentage = 0.975, transforms = [animation.Translate(0, 0)], curve = "ease_in_out"),
            animation.Keyframe(percentage = 1.0, transforms = [animation.Translate(0, -6)]),
        ],
    )

def card(label, value, color, icon = None, bar = None, sub = None, wrap = False, player = None, players = [], value_font = "tb-8"):
    if wrap:
        # Long text like quest names: two lines of the small font.
        value_widget = render.WrappedText(value, width = 64, height = 12, align = "center", color = color, font = "tom-thumb")
    else:
        value_widget = with_image(icon_image(icon), render.Text(value, color = color, font = value_font))
    children = [
        render.Text(label, color = LABEL_COLOR, font = "tom-thumb"),
        value_widget,
    ]
    if bar != None:
        filled = int(max(0, min(1, bar)) * 50)
        children.append(render.Stack(children = [
            render.Box(width = 50, height = 2, color = "#333"),
            render.Box(width = max(filled, 1), height = 2, color = color if filled else "#333"),
        ]))
    if player != None:
        name = render.Text(player["name"], color = player_color(players, player), font = "tom-thumb")
        children.append(with_image(face_image(player), name))
    elif sub != None:
        children.append(render.Text(sub, color = LABEL_COLOR, font = "tom-thumb"))
    return render.Box(
        width = 64,
        height = 26,
        child = render.Column(
            main_align = "space_evenly",
            cross_align = "center",
            expanded = True,
            children = children,
        ),
    )

def with_image(image, child):
    if image == None:
        return child
    return render.Row(
        cross_align = "center",
        children = [image, render.Box(width = 2, height = 1), child],
    )

def icon_image(name):
    if name == None:
        return None
    return render.Image(src = base64.decode(ICONS[name]), width = 10, height = 10)

def face_image(player):
    if not player.get("face"):
        return None
    return render.Image(src = base64.decode(player["face"]), width = 8, height = 8)

def animate_card(child):
    # Slide in from the right, hold, slide out to the left.
    return animation.Transformation(
        child = child,
        duration = FRAMES_PER_CARD,
        keyframes = [
            animation.Keyframe(percentage = 0.0, transforms = [animation.Translate(64, 0)], curve = "ease_in_out"),
            animation.Keyframe(percentage = 0.1, transforms = [animation.Translate(0, 0)]),
            animation.Keyframe(percentage = 0.9, transforms = [animation.Translate(0, 0)], curve = "ease_in_out"),
            animation.Keyframe(percentage = 1.0, transforms = [animation.Translate(-64, 0)]),
        ],
    )

# ---------- Formatting ----------

def format_number(n):
    n = int(n)
    if n < 10000:
        return str(n)
    suffixes = ["K", "M", "G", "T", "P", "E"]
    value = n
    i = -1
    for _ in suffixes:
        if value < 1000:
            break
        value = value / 1000
        i += 1
    whole = int(value)
    tenth = int((value - whole) * 10)
    if whole < 100:
        return "%d.%d%s" % (whole, tenth, suffixes[i])
    return "%d%s" % (whole, suffixes[i])

def format_percent(frac):
    tenths = int(frac * 1000)
    return "%d.%d%%" % (tenths // 10, tenths % 10)

def format_duration(seconds):
    s = int(seconds)
    d, s = s // 86400, s % 86400
    h, s = s // 3600, s % 3600
    m = s // 60
    if d:
        return "%dd %dh" % (d, h)
    if h:
        return "%dh %dm" % (h, m)
    return "%dm" % m

def shuffle(items):
    for i in range(len(items) - 1, 0, -1):
        j = random.number(0, i)
        items[i], items[j] = items[j], items[i]

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(id = "summary_url", name = "Summary URL", desc = "URL of summary.json from gtnh_export.py", icon = "chartLine", default = DEFAULT_SUMMARY_URL),
        ],
    )
