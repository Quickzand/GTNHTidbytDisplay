# GTNH Tidbyt stats

Shows our GregTech: New Horizons group stats on the Tidbyt.

Flow: Apex server files → `gtnh_export.py` on my Mac → `gtnhSummary.json` on matthewsand.info → Tidbyt.

## Updating the stats

1. From the Apex file manager (or SFTP), download these from the world folder (`Longie/`) into `exporter/Longie/`, keeping the same folder layout:
   - `stats/`: one `.json` per player
   - `betterquesting/`: `NameCache.json`, `QuestDatabase.json`, `QuestingParties.json` and the `QuestProgress/` folder
   - `serverutilities/teams/claimedchunks/` and `serverutilities/players/`
   - `level.dat`: used to tell which "items used" stats are block placements
2. Build the summary:

   ```bash
   python3 exporter/gtnh_export.py exporter/Longie -o gtnhSummary.json
   ```

3. Upload `gtnhSummary.json` to `https://www.matthewsand.info/gtnhSummary.json`.

`exporter/Longie/` is git-ignored, so the world data never gets committed.

## What the Tidbyt shows

Quests Done and Chunks Claimed every cycle, plus 3 random picks from:

- Group cards: Latest Quest, Quest MVP, Group Playtime, Group Traveled, Most Deaths
- Per-person cards, each showing a random one of us (name in that person's color): Playtime,
  Since Death, Blocks Placed, Deaths, Mob Kills, Traveled, GT Ores Mined, GT Tools Made, Bosses Slain, Jumps,
  Animals Bred

Notes:

- Party quests are shared, so everyone has the same quest count. Quest MVP counts who got each quest
  first by completion time, which is the best guess at who actually did it.
- Since Death comes from ServerUtilities' `/back` tracker (the RESPAWN entry). The Tidbyt counts up from
  that time itself, so it stays current between uploads.
- Faces are 8x8 Minecraft heads from mc-heads.net, fetched when the exporter runs and stored in the
  summary, so a skin change shows up after the next upload.
- The 10x10 item icons in `icons/` are embedded in `main.star` as base64 (`ICONS`), so the app has no
  extra files to load. If you change an icon, re-encode it into that table.
- Real names are set by UUID in `NICKNAMES` at the top of `exporter/gtnh_export.py`.

## Previewing the Tidbyt app

```bash
pixlet serve main.star
```

`samples/summary.sample.json` is made-up data for testing the layout.

## Later

- `oc/exporter.lua` is for live base power once we have OpenComputers.
