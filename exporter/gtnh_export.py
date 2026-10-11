#!/usr/bin/env python3
"""Build gtnhSummary.json for the GTNH Tidbyt app from a downloaded GTNH world.

Reads (all inside the world folder, e.g. Longie/):
  stats/*.json                              vanilla 1.7.10 player stats
  betterquesting/NameCache.json             uuid -> player name
  betterquesting/QuestDatabase.json         quest names
  betterquesting/QuestProgress/<uuid>.json  per-player quest completions
  betterquesting/QuestingParties.json       party name
  serverutilities/teams/claimedchunks/*.dat ServerUtilities chunk claims (NBT)
  serverutilities/players/*.dat             last death time (NBT)
  level.dat                                 which registry names are blocks

Usage:
  python3 gtnh_export.py Longie -o gtnhSummary.json
"""

import argparse
import base64
import gzip
import json
import os
import re
import struct
import sys
import time
import urllib.request

# Real names shown on the Tidbyt, keyed by Minecraft UUID so renames don't break them.
NICKNAMES = {
    "37c44c32-b56d-4693-bc23-bde5f7a7b9b6": "Matthew",  # Quickzand
    "da0cc032-e2c0-41ec-a0b0-f36f86696a40": "Spencer",  # awesomesawsse
    "af1decfa-8d13-4a1c-8bb8-ab64bcd93089": "Ayden",    # ColbyJack1134
}

SUFFIX = re.compile(r":\d+$")
FORMATTING = re.compile("§.")

# Distance stats (fall distance left out on purpose).
DISTANCE_KEYS = ["walkOneCm", "crouchOneCm", "sprintOneCm", "swimOneCm", "diveOneCm",
                 "climbOneCm", "flyOneCm", "boatOneCm", "minecartOneCm", "pigOneCm", "horseOneCm"]

BOSSES = ["EnderDragon", "WitherBoss",
          "TwilightForest.Naga", "TwilightForest.Twilight Lich", "TwilightForest.Hydra",
          "TwilightForest.Minoshroom", "TwilightForest.Knight Phantom", "TwilightForest.Tower Boss",
          "TwilightForest.Yeti Boss", "TwilightForest.Snow Queen"]


# ---------------- helpers ----------------

def strip_suffixes(obj):
    """BetterQuesting writes NBT-as-JSON with type suffixes ("uuid:8"); drop them."""
    if isinstance(obj, dict):
        return {SUFFIX.sub("", k): strip_suffixes(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [strip_suffixes(v) for v in obj]
    return obj


def entries(obj):
    """NBT lists come through as {"0": ..., "1": ...}; accept either shape."""
    if isinstance(obj, dict):
        return list(obj.values())
    if isinstance(obj, list):
        return obj
    return []


def load_json(path, quiet=False):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        if not quiet:
            print(f"warn: could not read {path}: {e}", file=sys.stderr)
        return None


def load_bq(path):
    data = load_json(path)
    return strip_suffixes(data) if data is not None else None


def norm(u):
    return str(u).replace("-", "").lower()


def clean(text):
    return FORMATTING.sub("", text or "").strip()


# ---------------- players & stats ----------------

def load_names(world):
    names = {}
    cache = load_bq(os.path.join(world, "betterquesting", "NameCache.json")) or {}
    for e in entries(cache.get("nameCache")):
        names[norm(e["uuid"])] = e["name"]
    # Fall back to the server's usercache.json if it was downloaded too.
    for path in [os.path.join(world, "usercache.json"), os.path.join(world, "..", "usercache.json")]:
        for e in load_json(path, quiet=True) or []:
            names.setdefault(norm(e["uuid"]), e["name"])
    for uuid, nickname in NICKNAMES.items():
        names[norm(uuid)] = nickname
    return names


def block_names(world):
    """Registry names that are blocks, from FML's ID map in level.dat ("\\x01" = block)."""
    path = os.path.join(world, "level.dat")
    if not os.path.isfile(path):
        print(f"warn: no level.dat at {path}, blocks placed will be vanilla only", file=sys.stderr)
        return set()
    registry = read_nbt(path).get("FML", {}).get("ItemData", [])
    return {e["K"][1:] for e in registry if e["K"].startswith("\x01")}


def blocks_placed(s, blocks):
    """Placing a block counts as using its item, so sum useItem stats for block items."""
    total = 0
    for k, v in s.items():
        if not k.startswith("stat.useItem."):
            continue
        key = k[len("stat.useItem."):]
        if key.isdigit():
            is_block = int(key) < 4096  # 1.7.10 block IDs live below 4096
        else:
            is_block = key.removeprefix("autogen.") in blocks
        if is_block:
            total += v
    return int(total)


def player_stats(world):
    out = {}
    blocks = block_names(world)
    stats_dir = os.path.join(world, "stats")
    if not os.path.isdir(stats_dir):
        print(f"warn: no stats folder at {stats_dir}", file=sys.stderr)
        return out
    for name in os.listdir(stats_dir):
        if not name.endswith(".json"):
            continue
        s = load_json(os.path.join(stats_dir, name)) or {}

        def total(prefix, contains=""):
            return int(sum(v for k, v in s.items()
                           if k.startswith(prefix) and contains in k and isinstance(v, (int, float))))

        out[norm(name[:-5])] = {
            "playtime_s": int(s.get("stat.playOneMinute", 0) / 20),
            "deaths": int(s.get("stat.deaths", 0)),
            "mob_kills": int(s.get("stat.mobKills", 0)),
            "boss_kills": int(sum(s.get("stat.killEntity." + b, 0) for b in BOSSES)),
            "distance_m": int(sum(s.get("stat." + k, 0) for k in DISTANCE_KEYS) / 100),
            "jumps": int(s.get("stat.jump", 0)),
            "animals_bred": int(s.get("stat.animalsBred", 0)),
            "blocks_placed": blocks_placed(s, blocks),
            "gt_ores_mined": total("stat.mineBlock.", "gregtech:gt.blockores"),
            "gt_tools_crafted": total("stat.craftItem.", "gregtech:gt.metatool"),
        }
    return out


def fetch_face(uuid):
    """8x8 face (with hat layer) as base64 PNG, so the Tidbyt needs no extra requests."""
    url = f"https://mc-heads.net/avatar/{uuid}/8"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "gtnh-tidbyt-export"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            return base64.b64encode(resp.read()).decode()
    except OSError as e:
        print(f"warn: could not fetch face for {uuid}: {e}", file=sys.stderr)
        return None


# ServerUtilities TeleportType.RESPAWN; its /back entry is stamped when the player dies.
RESPAWN = "6"


def last_deaths(world):
    """uuid -> unix time of last death, from ServerUtilities' /back tracker."""
    folder = os.path.join(world, "serverutilities", "players")
    out = {}
    if not os.path.isdir(folder):
        print(f"warn: no ServerUtilities players at {folder}", file=sys.stderr)
        return out
    for name in os.listdir(folder):
        if not name.endswith(".dat"):
            continue
        try:
            data = read_nbt(os.path.join(folder, name))
        except Exception as e:  # noqa: BLE001 - skip unreadable files
            print(f"warn: could not read {name}: {e}", file=sys.stderr)
            continue
        tracker = data.get("Data", {}).get("serverutilities", {}).get("TeleportTracker", {})
        death = tracker.get(RESPAWN, {}).get("created_at")
        if death and data.get("UUID"):
            out[norm(data["UUID"])] = int(death / 1000)
    return out


# ---------------- BetterQuesting ----------------

def quest_id(q):
    return (q.get("questIDHigh", 0), q.get("questIDLow", q.get("questID", 0)))


def quest_names(world):
    db = load_bq(os.path.join(world, "betterquesting", "QuestDatabase.json")) or {}
    names = {}
    for q in entries(db.get("questDatabase")):
        props = q.get("properties", {}).get("betterquesting", {})
        names[quest_id(q)] = clean(props.get("name"))
    return names


def quest_progress(world):
    """Return (per-player quest stats, set of quest ids anyone finished, latest completion).

    Party members all get every shared quest, so per-player counts are equal.
    The earliest timestamp is (most likely) whoever actually finished it;
    the others get it later through the party sync.
    """
    bq = os.path.join(world, "betterquesting")
    files = [os.path.join(bq, "QuestProgress.json")]
    folder = os.path.join(bq, "QuestProgress")
    if os.path.isdir(folder):
        files += [os.path.join(folder, f) for f in sorted(os.listdir(folder)) if f.endswith(".json")]
    files = [f for f in files if os.path.isfile(f)]
    if not files:
        print(f"warn: no BetterQuesting progress under {bq}", file=sys.stderr)
        return None, None, None

    times = {}  # quest id -> {uuid: completion timestamp ms}
    claimed = {}
    latest = None  # (timestamp_ms, quest id, uuid)
    for path in files:
        data = load_bq(path) or {}
        for q in entries(data.get("questProgress")):
            qid = quest_id(q)
            for c in entries(q.get("completed")):
                u = norm(c.get("uuid", ""))
                if not u:
                    continue
                ts = c.get("timestamp", 0)
                times.setdefault(qid, {})[u] = ts
                if c.get("claimed"):
                    claimed[u] = claimed.get(u, 0) + 1
                if latest is None or ts > latest[0]:
                    latest = (ts, qid, u)

    per_player = {}
    for by_user in times.values():
        for u in by_user:
            per_player.setdefault(u, {"quests": 0, "quests_first": 0})
            per_player[u]["quests"] += 1
        real = {u: ts for u, ts in by_user.items() if ts > 0}
        if real:
            earliest = min(real.values())
            winners = [u for u, ts in real.items() if ts == earliest]
            if len(winners) == 1:
                per_player[winners[0]]["quests_first"] += 1
    for u, p in per_player.items():
        p["rewards_claimed"] = claimed.get(u, 0)
    return per_player, set(times), latest


def party_name(world):
    data = load_bq(os.path.join(world, "betterquesting", "QuestingParties.json")) or {}
    for p in entries(data.get("parties")):
        name = p.get("properties", {}).get("betterquesting", {}).get("name")
        if name:
            return clean(name)
    return None


# ---------------- ServerUtilities claims (NBT) ----------------

def read_nbt(path):
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:2] == b"\x1f\x8b":
        raw = gzip.decompress(raw)
    pos = 0

    def take(n):
        nonlocal pos
        chunk = raw[pos:pos + n]
        pos += n
        return chunk

    def payload(tag):
        if tag == 1: return struct.unpack(">b", take(1))[0]
        if tag == 2: return struct.unpack(">h", take(2))[0]
        if tag == 3: return struct.unpack(">i", take(4))[0]
        if tag == 4: return struct.unpack(">q", take(8))[0]
        if tag == 5: return struct.unpack(">f", take(4))[0]
        if tag == 6: return struct.unpack(">d", take(8))[0]
        if tag == 7: return list(take(struct.unpack(">i", take(4))[0]))
        if tag == 8: return take(struct.unpack(">H", take(2))[0]).decode("utf-8", "replace")
        if tag == 9:
            inner, n = struct.unpack(">bi", take(5))
            return [payload(inner) for _ in range(n)]
        if tag == 10:
            out = {}
            while True:
                t = take(1)[0]
                if t == 0:
                    return out
                name = take(struct.unpack(">H", take(2))[0]).decode("utf-8", "replace")
                out[name] = payload(t)
        if tag == 11:
            n = struct.unpack(">i", take(4))[0]
            return list(struct.unpack(f">{n}i", take(4 * n)))
        if tag == 12:
            n = struct.unpack(">i", take(4))[0]
            return list(struct.unpack(f">{n}q", take(8 * n)))
        raise ValueError(f"unknown NBT tag {tag}")

    root_tag = take(1)[0]
    take(struct.unpack(">H", take(2))[0])  # root name
    return payload(root_tag)


def chunks_claimed(world):
    """ClaimedChunks is {dimension: [chunk, ...]} in each team's claimedchunks/*.dat."""
    folder = os.path.join(world, "serverutilities", "teams", "claimedchunks")
    if not os.path.isdir(folder):
        print(f"warn: no ServerUtilities claims at {folder}", file=sys.stderr)
        return None
    total = 0
    for name in os.listdir(folder):
        if not name.endswith(".dat"):
            continue
        try:
            data = read_nbt(os.path.join(folder, name))
        except Exception as e:  # noqa: BLE001 - skip unreadable files
            print(f"warn: could not read {name}: {e}", file=sys.stderr)
            continue
        for dim_chunks in (data.get("ClaimedChunks") or {}).values():
            total += len(dim_chunks)
    return total


# ---------------- main ----------------

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("world", help="world folder (contains stats/ and betterquesting/)")
    ap.add_argument("-o", "--out", default="gtnhSummary.json")
    args = ap.parse_args()

    world = args.world
    names = load_names(world)
    stats = player_stats(world)
    quests_by_player, done, latest = quest_progress(world)
    deaths = last_deaths(world)
    titles = quest_names(world)

    players = []
    for uuid in sorted(set(stats) | set(quests_by_player or {})):
        p = {"name": names.get(uuid, uuid[:8])}
        p.update(stats.get(uuid, {}))
        if uuid in deaths:
            p["last_death"] = deaths[uuid]
        face = fetch_face(uuid)
        if face:
            p["face"] = face
        if quests_by_player is not None:
            p.update(quests_by_player.get(uuid, {}))
        players.append(p)
    players.sort(key=lambda p: p["name"].lower())

    latest_quest = None
    if latest:
        latest_quest = {
            "name": titles.get(latest[1]) or "Unknown quest",
            "by": names.get(latest[2], latest[2][:8]),
            "timestamp": int(latest[0] / 1000),
        }

    summary = {
        "updated": int(time.time()),
        "group": party_name(world),
        "quests_completed": len(done) if done is not None else None,
        "quests_total": len(titles) or None,
        "latest_quest": latest_quest,
        "chunks_claimed": chunks_claimed(world),
        "players": players,
    }
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
    print(f"wrote {args.out}: {len(players)} players, {summary['quests_completed']}/"
          f"{summary['quests_total']} quests, {summary['chunks_claimed']} chunks")


if __name__ == "__main__":
    main()
