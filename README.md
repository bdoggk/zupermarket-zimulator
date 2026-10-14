# Zupermarket Zimulator

A 2D pixel-art, isometric supermarket simulator... for zombies. You're a zombie running
a store where zombie shoppers buy blood bottles, hearts, lungs, brains and other fresh
organs, and drip blood on your floor. Built with **Godot 4.7** (tested on 4.7.2) in the
style of Project Zomboid. One project runs on **Windows/PC, Mac and Android**.

All the art is placeholder pixel art drawn by a Python script, so you can swap in
your own sprites whenever you're ready.

## Download

**[Latest release](https://github.com/bdoggk/zupermarket-zimulator/releases/latest)**

| Device | Download |
|---|---|
| Android (phones, tablets, AYN Thor and other handhelds) | [ZupermarketZimulator-android.apk](https://github.com/bdoggk/zupermarket-zimulator/releases/latest/download/ZupermarketZimulator-android.apk) |
| Windows (64-bit) | [ZupermarketZimulator-windows.exe](https://github.com/bdoggk/zupermarket-zimulator/releases/latest/download/ZupermarketZimulator-windows.exe) |

**Installing on Android / AYN Thor:** open the APK link in the device's browser and
tap the download. Android will ask you to allow installs from that browser (**Settings →
Install unknown apps**); allow it, go back and tap **Install**. New versions install
over the old one and keep your saves.

**Controls on a handheld:** left stick / d-pad to move, **A** to use, **X** to scan a
shelf, **Y** for build mode, **Start** to pause. Menus work with the d-pad and A/B,
and you can tap the touchscreen for anything too (the store computer and build mode
are easiest by touch).

**Windows:** it's a single .exe, no installer. Windows may show "Windows protected your
PC" because the game isn't code-signed: click **More info → Run anyway**.

It's the zombie twin of **Supermarket Sim**, which lives in its own folder. The two
games share all their code. Only `scripts/brand.gd` (names, products, layout,
wording) and the art are different (see "Two games, one codebase" below).

## Open it

1. Download Godot 4.7 (the standard version, not .NET) from https://godotengine.org/download
2. Unzip this project somewhere. **If you have the older version, replace the whole
   folder.** Some sprite files were renamed, so don't copy the new files over the old ones.
3. Open Godot → **Import** → pick `project.godot` → **Import & Edit**.
4. Press **F5** (or the ▶ button) to play. The game starts on the main menu.

## Main menu and saving

- **Continue** picks up the game you played most recently.
- **New Game** asks which of the **3 save slots** to use. If the slot already has a
  game, it asks before replacing it.
- **Load Game** shows each slot's day, money, level, play time and when it was last
  saved. You can also **Delete** a slot from here (it asks first).
- **Options** has display, graphics, VSync and vibration settings (see below).

The game **saves automatically**:
- when you start a new game
- every morning
- when you choose Save Game or Save & Main Menu in the pause menu
- when you close the window
- when the app goes to the background on a phone

Zombies who are in the store when you save aren't kept (they just shamble off). Saves
are JSON files in `user://saves/`, separate from Supermarket Sim's. On Windows that's
`%APPDATA%\Godot\app_userdata\Zupermarket Zimulator\saves`.

**Pause menu:** Esc, P, the Start button, the **II** button or the phone's back button.
It has Resume, Save Game, Options, Save & Main Menu, and Save & Quit (PC).

## Options

| Setting | What it does |
|---|---|
| Display | Windowed or Fullscreen (PC only) |
| Resolution | Window size in windowed mode, from 1280x720 up to what fits your screen. Fullscreen uses your screen's resolution (PC only) |
| Graphics | **Low**: simple lighting, 30 FPS cap (older phones, battery life). **Medium**: store lights with darker corners, 60 FPS cap. **High**: adds a flickering light tube and floating dust, no FPS cap |
| VSync | Syncs to your monitor to stop screen tearing |
| Vibration | Phone vibration and controller rumble. It turns on when a phone or controller is available, and you feel it when you make a sale, stock a shelf, scan, mop, level up, or when a zombie storms out |

Settings are saved to `user://settings.cfg`.

## How to play

You run the store. Keep the shelves full, the line moving, the floor (mostly) clean
and the business growing.

**Every day starts closed.** The clock is stopped at 8:00 AM and no zombies come
in, so you can stock shelves, order boxes, set prices, mop and build. When you're ready,
**flip the OPEN sign by the front door**: walk up and press E, or tap it. The clock
then starts and the horde shambles in. At 8 PM the sign flips back to CLOSED by itself.
Boxes you order still get delivered while you're closed.

1. **Boxes** arrive on the yellow-striped delivery zone in the back corner. Pick one up.
2. **Stock a shelf**: carry the box to a shelf and use it. A shelf holds one product
   at a time (12 max); once it's empty it takes anything.
3. **Zombies** shamble in with a shopping list (the bubble over their head), grab
   items and line up at the register with the shortest line.
4. **Scan** their items at the register to get paid. Wait too long and they leave
   without paying (watch the bar over their head).
5. **Use the computer** in the back to order stock, set prices, unlock products, hire
   staff and buy upgrades.
6. The store closes at 8 PM. After the last zombie leaves, you get a summary of the
   day, then **Go to Day N** takes you to the next morning (closed again until you flip
   the sign).

Actions take time with a progress bar, like Project Zomboid. Moving cancels them.

### Blood and the mop
About a third of the zombies drip blood as they walk around, leaving puddles on the
floor. **Every puddle keeps some shoppers away** (even zombies hate a messy store), so
the status bar shows how many there are ("Blood: 3").
1. Walk to the **mop bucket** (the yellow bucket near the computer) and press E (or
   tap it) to grab the mop.
2. Walk onto or next to a puddle and press E (or tap the puddle) to mop it up.
3. Put the mop back in the bucket when you're done. You can't carry boxes while
   you're holding it.

The bucket can be moved in build mode. Furniture placed on top of a puddle covers it up.

### Market prices
Prices change every 4 in-game hours (8 AM, 12 PM and 4 PM). Box costs and the prices
zombies expect both follow the market, so stock up when something is cheap.
Each morning there may be news:
- **Shortage:** that product's price jumps up.
- **Surplus:** its price drops.
- **Craze:** "Everyone wants fresh brains today!" and zombies ask for it far more often.

In the **Stock & Prices** tab:
- The market column shows the current price and how much it just moved.
- Your price turns yellow or red when it's above market. The higher it goes, the
  more zombies skip it ("Grrr... pricey!").
- **=** sets one product to the market price. **Match all to market** does it for
  everything.
- **Auto-match** keeps all your prices at market automatically.

### Store level and new products
Every $1 of sales is 1 XP. Leveling up your store (6 levels) lets you buy **licenses**
for new products in the **Products** tab. There are 12 products in total:

| Level | Products |
|---|---|
| Start | Canned Guts, Blood Bottles, Finger Chips |
| 1 | Eyeball Jars |
| 2 | Lungs, Fresh Hearts (cold) |
| 3 | Kidneys, Toe Jerky |
| 4 | Liver (cold), Bone Marrow |
| 5 | Fresh Brains (cold), Spine Snacks |

Cold products need a **Meat Cooler** (build mode).

### Staff
Hire help in the computer's **Staff** tab. Each hire costs $50 up front, and staff
are paid **wages at the end of every day** (shown in the day summary, even if it puts
you in the red).
- **Stocker** ($25/day, up to 3): shambles to the stockroom, picks up delivery boxes
  and stocks the shelves. It
  tops up shelves that already have that product first, then fills empty ones, and
  puts a box down if there's nowhere for it to go. It leaves cold products alone
  until you have a meat cooler.
- **Cashier** ($30/day, one per register): walks to a register and rings up the
  zombies in its line by themselves. While a cashier is at a register, you can't
  use that one, so you're free to stock and order. Customers will wait a little
  longer in a line that has a cashier. Your staff are zombies too.

The Staff tab shows what everyone is doing right now, and **Let go** fires someone.

### More registers
Buy extra registers in build mode ($250, up to 4 in total). Each one gets its own
checkout line (shown in yellow while you place it), and zombies pick the shortest
line. Put a cashier on each one, or run one yourself. Extra registers can be sold
again; the first one can only be moved.

### Build mode (customize your store)
Press **B** (or the **Build** button). The game pauses while you build.
- **Buy** rusty shelves ($60), meat coolers ($150), gravestones ($25) and registers
  ($250). Gravestones make zombies come more often (it feels like home).
- **Move** anything you've placed (stock stays on the shelf), plus the **registers**,
  the **computer**, the **OPEN sign** and the **mop bucket**. When you pick up a register, a yellow
  preview shows where its checkout line will go. The line comes along with the
  register: it starts next to the register and turns around walls and shelves if it
  needs to.
- **Sell** for half price. Anything left on a shelf gets boxed up. (The first
  register, the computer, the sign and the mop bucket can be moved but not sold.)
- **Paint** the floor (5 styles, $40) and walls (5 colors, $30).
- Red tiles (door, checkout line, delivery zone) are off limits. Build mode won't let
  you block anyone's path.
- **On PC:** move the mouse to preview, click to confirm, right-click/Esc to cancel.
- **On a phone:** tap to preview, tap the same spot again to confirm.
- Drag (or use WASD) to look around.

### Handheld scanner
Buy it in the **Upgrades** tab ($120). Stand next to any shelf and press **Q** (or
**SCAN**) to order another box of that product on the spot, without walking to the
computer. A scanner icon appears next to your money once you own it.

### Controls

| | PC | Android |
|---|---|---|
| Move | WASD / arrow keys, or click a spot | Tap a spot |
| Use | E or Space (or click the object) | Tap the object, or the big button |
| Scan a shelf | Q | SCAN button |
| Drop a box | E with nothing usable nearby | Big button ("Drop box") |
| Grab / return the mop | E at the mop bucket | Tap the bucket |
| Mop up blood | E next to a puddle (holding the mop) | Tap the puddle |
| Build mode | B | Build button |
| Zoom | Mouse wheel or the +/- buttons | +/- buttons |
| Pause menu | Esc or P | II button / back button |
| Close / cancel | Esc | Back button |

A gamepad works too: left stick to move, A (use), X (scan), Y (build), Start (pause).
Menus can be navigated with the d-pad, arrow keys, A/Enter and B/Esc.

**Preview the phone controls on PC:** select the `HUD` node in `scenes/main.tscn` and
tick **Force Touch Ui** in the Inspector.

## Project layout

```
project.godot          Project settings (pixel-perfect filtering, landscape, input map)
export_presets.cfg     Ready-made Windows, Android and macOS export presets
scenes/
  menu.tscn            The main menu (starts here)
  main.tscn            The game: Store (+ Lights, BuildMode) and HUD
  player.tscn          Player (sprite, collision, camera)
  customer.tscn        Customer
scripts/
  brand.gd             THE file that makes this game this game: name, starting
                       layout, products, furniture/paint/staff names, wording, colors
  game.gd              Autoload "Game": money, levels, licenses, upgrades, staff
                       roster and wages, clock, daily stats
  saves.gd             Autoload "Saves": the 3 save slots, autosaving, continue
  settings.gd          Autoload "Settings": options, saved to settings.cfg, vibration
  store_lights.gd      Store lighting for each graphics level, day/night tint
  market.gd            Prices that drift over time + daily news events
  store.gd             Builds the store from the map, furniture placement rules,
                       registers and their lines, deliveries, decor, staff, spills,
                       customer spawning
  build_mode.gd        Build mode: place / move / sell furniture and registers
  iso.gd               Isometric grid math (cell <-> screen)
  player.gd            Movement, tap-to-walk, carrying boxes, timed actions, scanning
  customer.gd          Customer AI (shop -> pick a line -> pay -> leave)
  staff.gd             Staff AI: stockers and cashiers
  interactable.gd      Base class for anything the player can use
  shelf.gd             Shelves (and the items drawn on them), scanner support
  fridge.gd            Meat cooler = a shelf for cold products
  decoration.gd        Gravestones
  stock_box.gd         Delivery boxes
  register.gd          A checkout and its customer line
  spill.gd             Blood spills (zombie game)
  mop_bucket.gd        The mop bucket (zombie game)
  computer.gd          Opens the store computer
  floor.gd             Draws the floor tiles and the tap marker
  hud.gd               Main UI (status bar, prompts, messages, summary)
  ui/computer_menu.gd  The computer: Stock & Prices / Products / Staff / Upgrades tabs
  ui/build_bar.gd      The build mode toolbar and paint menu
  ui/pause_menu.gd     The in-game pause menu
  ui/options_menu.gd   The Options screen (main menu and pause menu)
  ui/ui.gd             UI helpers and theme
  menu/menu.gd         Main menu: Continue / New Game / Load Game / Options / Quit
  menu/menu_backdrop.gd  The store drawn behind the main menu (from your latest save)
assets/sprites/        All the pixel art
tools/make_sprites.py  The Python script that draws the placeholder art (for both games)
tests/                 Automated checks (not included in exports, safe to ignore)
Update Mac App.command Rebuilds the Mac app and installs it (see "Mac app")
```

## Changing things

**The starting layout** is a text map in `scripts/brand.gd`:

```
"################",
"#DDD.......M.C.#",     #  wall        S  shelf       D  delivery zone
"#DDD...........#",     .  floor       F  fridge      C  computer
"#..............#",     E  door        L  plant       R  register
"#...SSS........#",     P  player     1-4  checkout line     O  OPEN sign
...
```

Every row has to be the same length. The top row and left column are the tall back
walls. `M` is the mop bucket. Build mode can rearrange everything except the
delivery zone and the door,
which only move if you edit the map.

**Saving new things:** if you add new game state, add it to `to_dict()` / `from_dict()`
in `game.gd` (or `store.gd` for things in the store). Missing values fall back to
defaults, so old saves keep loading.

**Add a product:** add an entry to `PRODUCTS` in `scripts/brand.gd` with its box size,
cost, price, unlock level, license cost and whether it's cold. Then add an 8x10 icon
in `assets/sprites/`. It shows up in the computer, on shopping lists and in the market.

**Add furniture or paint:** see `FURNITURE`, `FLOOR_STYLES` and `WALL_COLORS` in
`scripts/brand.gd`. Floor and wall sprites are drawn by `tools/make_sprites.py`.

**Staff:** hiring cost, wages and how many you can have are in `STAFF` in
`scripts/brand.gd`; their names are in `STAFF_NAMES`. Speeds are at the top of
`scripts/staff.gd`.

**Add an upgrade:** add it to `UPGRADES` in `brand.gd`, then check
`Game.has_upgrade("your_id")` wherever it should do something. The scanner is the
example to follow (see `shelf.gd`).

**Balance:** the numbers are constants at the top of each script:
- `game.gd`: day length, delivery time, level XP
- `market.gd`: how often and how much prices move, news chances
- `store.gd`: zombie numbers, how much gravestones help, how much blood hurts, max registers
- `customer.gd`: patience, how many zombies drip and how often
- `shelf.gd`: shelf size

**Art:** replace any PNG in `assets/sprites/` with your own and keep the same size.
Or edit the colors in `tools/make_sprites.py` and run:

```
pip install pillow
python3 tools/make_sprites.py
```

Iso rules the game expects:
- Floor tiles are 64x32 diamonds.
- Objects are 64 px wide, with their floor footprint's center 16 px above the bottom.
- Characters are 16x36, with their feet at (8, 33).

## Tests

```
godot --headless --path . res://tests/feature_test.tscn     # 60+ rule checks
godot --headless --path . -s res://tests/flow_test.gd       # menus + saving, 50+ checks
godot --headless --path . --fixed-fps 60 res://tests/staff_test.tscn  # registers, staff, spills
DAYS=5 godot --headless --path . --fixed-fps 60 res://tests/bot_test.tscn   # a bot plays 5 days
STAFF=1 SHUFFLE=1 godot --headless --path . --fixed-fps 60 res://tests/stuck_test.tscn  # busy-store stress test
```

The flow test backs up your real saves and settings first and puts them back afterwards.

## Two games, one codebase

Supermarket Sim and Zupermarket Zimulator are two separate projects (two folders,
two apps, separate saves), but every script, scene, test and tool is the same in
both. What's different:

- `scripts/brand.gd`: name, tagline, starting layout, products, furniture/paint/staff
  names, wording, lighting colors, and whether blood spills are on
- `assets/sprites/` and `icon.png`: the art (`tools/make_sprites.py` draws the right
  set for whichever game it's in, by reading `brand.gd`)
- `project.godot` (the game's name, which also decides where saves go),
  `export_presets.cfg` (app names and ids) and this README

To bring a new feature from one game to the other, copy over `scripts/` (keeping that
game's `brand.gd`), `scenes/`, `tests/` and `tools/`.

## Mac app

The game is set up to build as a normal Mac app (`Zupermarket Zimulator.app`). It's a
universal app, so it runs on Apple Silicon and Intel Macs.

**Updating the app after you change the game:** double-click **`Update Mac App.command`**
in this folder. It rebuilds the game from this folder and replaces the app in
`~/Applications`, then starts it. Your saves and settings are kept, because they live
in `~/Library/Application Support/Godot/app_userdata/Zupermarket Zimulator`, not inside the app.

One-time setup for the update script:
1. Install Godot 4.7 into Applications (https://godotengine.org/download).
2. Open Godot once and choose **Editor → Manage Export Templates → Download and Install**.

You can also export by hand: Project → Export → "macOS" → Export Project.

**If macOS says the app "can't be opened":** the app isn't notarized by Apple (that
needs a paid developer account). Open **System Settings → Privacy & Security**, scroll
down, and click **Open Anyway** next to Zupermarket Zimulator. You only have to do this once.

## Exporting

First, in Godot: **Editor → Manage Export Templates → Download and Install**.

**Windows:** Project → Export → "Windows Desktop" → Export Project. You get a single
.exe in `build/windows/`.

**Android:**
1. Install Android Studio (for the Android SDK) and OpenJDK 17.
2. In Godot: Editor → Editor Settings → Export → Android, then set the
   **Java SDK Path** and **Android SDK Path**.
3. Project → Export → "Android". Under **Keystore → Release**, pick
   `keys/zupermarket-release.keystore` and enter the alias and password from
   `keys/README.txt`. That folder is on your Mac (it's deliberately not on GitHub).
   Every Android version must be signed with that same key, or devices won't install
   it over the old version.
4. Plug in your phone with USB debugging on and click the Android icon at the top
   right of the editor to run on the device, or Export Project to get an APK.

Official guide: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html

The project uses the Compatibility renderer, so it runs on older phones too.

## Ideas for what to build next

- Expand the store (buy more floor space)
- More upgrades: express delivery, a faster checkout scanner
- More staff: a zombie janitor who mops, a security guard, staff that level up
- Real walk animations (4 directions) with `AnimatedSprite2D`
- Sound: register beeps, scanner beep, door chime, music
- Humans breaking in (lock the doors!), power outages, a blood bank delivery truck
