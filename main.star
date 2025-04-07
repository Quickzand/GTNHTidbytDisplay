load("render.star", "render")
load("animation.star", "animation")
load("http.star", "http")
load("encoding/base64.star", "base64")
load("random.star", "random")

statsUrl = "https://www.matthewsand.info/minecraftStats.json"


def getMinecraftStats():
    return http.get(statsUrl).json()

def main():
    stats = getMinecraftStats()["stats"]

    if stats == None:
        return render.Root(
            render.Text("Error fetching stats")
        )

    possibleStats = [
    statDisplay("Playtime", getFormattedPlaytime(stats), "clock.png"),
    statDisplay("Blocks Mined", getTotalBlocksMined(stats), "pickaxe.png"),
    statDisplay("Deaths", getDeaths(stats), "skull.png"),
    statDisplay("Diamonds", getTotalDiamondsMined(stats), "diamond.png"),
statDisplay("Traveled", getTotalDistanceTraveled(stats), "leatherBoots.png"),
statDisplay("Since Death", getTimeSinceLastDeath(stats), "clock.png"),
statDisplay("Total Kills", getTotalKills(stats), "sword.png"),
    statDisplay("Most Killed", getMostKilledMob(stats), "sword.png", font="tom-thumb"),
    statDisplay("Mobs Bred", getAnimalsBred(stats), "pig.png"),
    statDisplay("Jump Count", getJumpCount(stats), "leatherBoots.png"),
    ]


    # Pick 4 stats randomly from the possible stats and put them into a new list to be displayed 
    
    for i in range(len(possibleStats)):
        j = random.number(0,len(possibleStats) - 1)
        possibleStats[i], possibleStats[j] = possibleStats[j], possibleStats[i]

    displayedStats = possibleStats[:4]

    return render.Root(
        render.Sequence(
            children=displayedStats
        )
    )

    return render.Root(
        render.Sequence(
            children=displayedStats
        )
        
    )




def statDisplay(statName, value, imageName, font="5x8"):
    return animation.Transformation(
child = 
    render.Row ( main_align="center", 
    expanded=True, 
    children = [render.Column(
            main_align="center",
            cross_align="center",
            expanded=True,
            children=[
                render.Image(src=getBinaryDataFromImageName(imageName), width=10, height=10),
                render.Text(statName, color="#FFF", font="5x8"),
                render.Box(width=50, height=1, color="#FFF"),
                render.Text(str(value), color="#FFF", font=font),
            ]
        )]
    ),
keyframes = [
        animation.Keyframe(
        percentage = 0.0,
        transforms = [animation.Translate(100, 0)],
        curve = "ease_in_out",
        ),
        animation.Keyframe(
        percentage = 0.1,
        transforms = [animation.Translate(0, 0)],
        ),
        animation.Keyframe(
        percentage = 0.9,
        transforms = [animation.Translate(0, 0)],
        ),
        animation.Keyframe(
        percentage = 1.0,
        transforms = [animation.Translate(-100, 0)],
        curve = "ease_in_out",
        ),
    ],
    duration = 75,
    )


def getBinaryDataFromImageName(imageName):
    return http.get("https://matthewsand.info/minecraftStats/" + imageName).body()



def getTotalBlocksMined(stats):
    totalBlocksMined = 0
    for key, value in stats["minecraft:mined"].items():
        totalBlocksMined += value
    return int(totalBlocksMined)


def getDeaths(stats):
    return int(stats["minecraft:custom"]["minecraft:deaths"])

def getFormattedPlaytime(stats):
    ticks = stats["minecraft:custom"]["minecraft:play_time"]
    seconds = ticksToSeconds(ticks)
    minutes = seconds / 60
    hours = minutes / 60
    days = hours / 24
    return str(int(days)) + "d " + str(int(hours % 24)) + "h " + str(int(minutes % 60)) + "m " + str(int(seconds % 60)) + "s"


def getTotalDiamondsMined(stats):
    totalDiamondsMined = 0
    for key, value in stats["minecraft:mined"].items():
        if key == "minecraft:diamond_ore" or key == "minecraft:deepslate_diamond_ore":
            totalDiamondsMined += value
    return int(totalDiamondsMined)


def getTotalDistanceTraveled(stats):
    totalDistanceTraveled = 0
    for key, value in stats["minecraft:custom"].items():
        if key == "minecraft:walk_one_cm" or key == "minecraft:swim_one_cm" or key == "minecraft:fly_one_cm" or key == "minecraft:climb_one_cm" or key == "minecraft:fall_one_cm" or key == "minecraft:horse_one_cm": 
            totalDistanceTraveled += value
    return str(int(totalDistanceTraveled / 100)) + "m"

def getTimeSinceLastDeath(stats):
    lastDeath = stats["minecraft:custom"]["minecraft:time_since_death"]
    if lastDeath == 0:
        return "Never"
    else:
        ticks = lastDeath
        seconds = ticksToSeconds(ticks)
        minutes = seconds / 60
        hours = minutes / 60
        days = hours / 24
        return str(int(days)) + "d " + str(int(hours % 24)) + "h " + str(int(minutes % 60)) + "m " + str(int(seconds % 60)) + "s"

def getTotalKills(stats):
    totalKills = 0
    for key, value in stats["minecraft:killed"].items():
        totalKills += value
    return int(totalKills)


def getAnimalsBred(stats):
    return int(stats["minecraft:custom"]["minecraft:animals_bred"])


def getMostKilledMob(stats):
    mostKilledMob = ""
    mostKilledMobCount = 0
    for key, value in stats["minecraft:killed"].items():
        if value > mostKilledMobCount:
            mostKilledMob = key
            mostKilledMobCount = value
    return mobIdToName(mostKilledMob) 

def getJumpCount(stats):
    return int(stats["minecraft:custom"]["minecraft:jump"])

def mobIdToName(mobId):
    if mobId == "minecraft:creeper":
        return "Creeper"
    elif mobId == "minecraft:skeleton":
        return "Skeleton"
    elif mobId == "minecraft:spider":
        return "Spider"
    elif mobId == "minecraft:zombie":
        return "Zombie"
    elif mobId == "minecraft:slime":
        return "Slime"
    elif mobId == "minecraft:ghast":
        return "Ghast"
    elif mobId == "minecraft:blaze":
        return "Blaze"
    elif mobId == "minecraft:wither_skeleton":
        return "Wither Skeleton"
    elif mobId == "minecraft:enderman":
        return "Enderman"
    elif mobId == "minecraft:zombified_piglin":
        return "Zombified Piglin"
    elif mobId == "minecraft:witch":
        return "Witch"
    elif mobId == "minecraft:ender_dragon":
        return "Ender Dragon"
    elif mobId == "minecraft:guardian":
        return "Guardian"
    elif mobId == "minecraft:shulker":
        return "Shulker"
    elif mobId == "minecraft:piglin":
        return "Piglin"
    elif mobId == "minecraft:pillager":
        return "Pillager"
    elif mobId == "minecraft:vindicator":
        return "Vindicator"
    elif mobId == "minecraft:evoker":
        return "Evoker"
    else:
        return mobId

def ticksToSeconds(ticks):
    return ticks / 20