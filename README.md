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

**Controls on a handheld:** left stick / d-pad to move, **LT** to sprint, **A** to use,
**X** to scan a shelf, **Y** for build mode, **RB** to turn things in build mode,
**Start** to pause (Options > Controls lists everything). Menus work with the d-pad and A/B,
and you can tap the touchscreen for anything too (the store computer and build mode
are easiest by touch).

**Windows:** it's a single .exe, no installer. Windows may show "Windows protected your
PC" because the game isn't code-signed: click **More info → Run anyway**.

It's the zombie twin of **Supermarket Sim**, which lives in its own folder. The two
games started from the same code; since version 0.8 Zupermarket Zimulator has a lot
more in it (see "Two games" below).

## What's new in 0.8.3

- **Sprint:** hold **Shift** (LT or a click of the left stick on a controller, or the
  **RUN** button on a touch screen) to move about 60% faster. It works when you click
  or tap somewhere to walk, too.
- **Smoother movement:** you now move every frame instead of 60 times a second, so
  at high frame rates (and on 120/144 Hz screens) you no longer stutter or smear
  against the background, and the camera keeps up better. The zoom steps now always
  make each art pixel a whole number of screen pixels, so the pixel art stays sharp
  while the view moves.
- **Controls list:** Options > **Controls** shows every key and button.
- **More FPS options:** a **Frame rate** setting (30 up to 240, or no limit), **Show
  FPS**, and **Exclusive fullscreen** (usually the most FPS on Windows). Graphics no
  longer caps the frame rate. VSync says what it's doing (off = more FPS).
- **The window isn't stuck at one size anymore:** drag its edges or maximize it and
  the game remembers; **Fill the screen** is a window size option; a size too big for
  your screen opens maximized instead of hanging off the edge.

## What's new in 0.8.2

- **Turn things around:** everything you can move in build mode can be turned a
  quarter turn: shelves, meat coolers, racks, gravestones, registers, self-checkouts,
  the computer, the sign, the mop bucket and the delivery zone. Use the **Rotate**
  button and tap things, or press **R** while placing or moving something (or with
  the mouse over it). Shelves and coolers now have a front: their stock shows on that
  side, and from behind you see the back panel (the label on top still shows what's
  in it, with a little bar for how full it is). Turning a register swings its
  checkout line around to the side it faces.
- **Bigger delivery zone:** three upgrades at the computer, each needing a store
  level: **Bigger Delivery Zone** ($200, level 2) holds 9 boxes, **Loading Bay**
  ($450, level 3) 12, **Body Dump** ($800, level 4) 16. The zone grows into the
  space around it (clear some room first if something's in the way).
- **Take over a register:** walk up to a register a cashier is running and press E.
  The cashier moves to a free register or takes a break, and gets back to work once
  you walk away.
- **Skeletons in town:** a few skeleton locals wander around town all day, and
  skeleton shoppers show up from day one.
- **General manager** (Staff tab, $100 + $45/day): walks the floor checking the
  shelves and the staff. Anything that's down to 2 on the shelves (with nothing on
  the way) gets reordered at the computer, everyone else works 15% faster, and anyone
  stuck on a job gets told to get back to work.
- **Stockers put spare boxes away:** when the shelves are full, the rest of the box
  goes on a storage rack or back on the delivery zone instead of on the floor.
- **End of the day:** when the last shopper leaves, a bar at the bottom of the screen
  says the day is over. Press **Space** (A on a controller, or tap it) to see the
  summary, and **Space** again to start the next day.
- Self-checkouts that jam reboot themselves after a while, and the general manager
  fixes them.
- Fixed: scrolling the mouse wheel over the store computer (or any menu) zoomed the
  view behind it.
- Fixed: shoppers still walking over from town at closing time came in after the
  store closed. Now they turn around ("Closed?!") and go home.
- Fixed: a shopper could get stuck standing in the middle of the store. Shoppers who
  stop where they shouldn't now work out a new way to go.

## What's new in 0.8.1

- **Shelf labels:** the first product you put on a shelf gives it a label (a little
  sign on top). A labeled shelf only takes that product, even when it's empty, so
  your stockers know what to refill it with.
- **Take items off a shelf:** with empty hands, use a shelf to take everything off it
  into a box you can carry somewhere else. Use the empty shelf again to peel off its
  label.
- **First-day tips:** on day 1 a tip box walks you through the basics and each tip
  stays up until you've done it. Messages also stay on screen longer on day 1.
- Fixed: cashiers no longer drop a checkout halfway and start over when you move
  furniture around.

## What's new in 0.8

- **Step outside:** walk out the front door into a barren town, with wrecked cars,
  ruins, a little cemetery and street lamps that come on at night. Shoppers now walk
  in from the edge of town.
- **Bone Mart**, a skeleton-run store down the street, competes for your shoppers.
  Walk over and check its prices, beat them, or buy the place out later on.
- **Expand the store:** buy the fenced lots next door (3 of them) in build mode.
- **Self-checkouts**, **storage racks**, and a **delivery zone** you can move.
- **Faster deliveries:** Delivery Bike, Delivery Van and Hearse Express upgrades.
- **Janitors** who mop up the blood, and **staff levels**: everyone gets faster as
  they work.
- **New kinds of shoppers:** crawlers, runners, brutes, rich zombies and skeletons.
- Fixed: in build mode, the view no longer follows the mouse around after you drag it.

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
| Display | **Windowed**, **Fullscreen** (fills the screen at its own resolution) or **Exclusive fullscreen** (the game takes the screen over: usually the highest frame rate on Windows). PC only |
| Window size | In a window: 1280x720 up to what fits your screen, or **Fill the screen** (maximized). You can also drag the window's edges or maximize it, and the game remembers the size (PC only) |
| Frame rate | A cap on the frames per second: 30, 60, 90, 120, 144, 165, 240 or **No limit** (the default on PC; phones default to 60 to save battery) |
| VSync | On: the frame rate matches your screen's refresh rate and the picture never tears. Turn it off for the most FPS |
| Show FPS | A frame counter next to the clock |
| Graphics | **Low**: simple lighting (older phones, battery life). **Medium**: store lights with darker corners. **High**: adds a flickering light tube and floating dust |
| Vibration | Phone vibration and controller rumble. It turns on when a phone or controller is available, and you feel it when you make a sale, stock a shelf, scan, mop, level up, or when a zombie storms out |

**Controls** (the button at the bottom of Options) lists every key and button, for
keyboard and mouse, controller and touch screens.

Settings are saved to `user://settings.cfg`.

## How to play

You run the store. Keep the shelves full, the line moving, the floor (mostly) clean
and the business growing.

**Every day starts closed.** The clock is stopped at 8:00 AM and no zombies come
in, so you can stock shelves, order boxes, set prices, mop and build. When you're ready,
**flip the OPEN sign by the front door**: walk up and press E, or tap it. The clock
then starts and the horde shambles in. At 8 PM the sign flips back to CLOSED by itself.
Boxes you order still get delivered while you're closed.

1. **Boxes** arrive on the yellow-striped delivery zone in the back corner (you can
   move it in build mode). Pick one up.
2. **Stock a shelf**: carry the box to a shelf and use it. A shelf holds one product
   at a time (12 max), and the first product you put on it gives it a **label**
   (see below).
3. **Zombies** walk in from the edge of town with a shopping list (the bubble over
   their head), grab items and line up at the register with the shortest line.
4. **Scan** their items at the register to get paid. Wait too long and they leave
   without paying (watch the bar over their head).
5. **Use the computer** in the back to order stock, set prices, unlock products, hire
   staff and buy upgrades.
6. The store closes at 8 PM. After the last zombie leaves, a bar at the bottom of the
   screen says the day is over: press **Space** (or tap it) for the day's summary, then
   **Space** or **Go to Day N** for the next morning (closed again until you flip the
   sign).

Actions take time with a progress bar, like Project Zomboid. Moving cancels them.

**On day 1, tips** in the top left walk you through all of this. Each one stays up until
you've done it; **Next tip** skips one and **Hide tips** turns them off.

### Shelf labels
The little sign on top of a shelf is its label: the product it's for. A shelf gets its
label from the first product you (or a stocker) put on it, and keeps it when it sells
out, so the empty shelf only takes that product. Stockers refill each shelf with the
product on its label and only use unlabeled shelves for new products.

To change what a shelf is for, walk up to it with empty hands and use it: everything
on it comes off into a box you carry (take it to another shelf, a storage rack, or put
it down). Use the empty shelf again to peel the label off; then it takes anything.
If a box is on the floor right there too, using picks up the box first.

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

### The town and Bone Mart
Walk out the front door and you're in town. The road runs past your store, with the
fenced lots for sale next door and **Bone Mart** a little further down the street.

Bone Mart is run by skeletons (the owner is Mr. Bones) and it's usually a bit cheaper
than the market, with one big **deal of the day** (the morning news tells you which).
Every shopper in town decides which store to go to:
- the more of your prices beat Bone Mart's, the more of them come to you
- a bloody, messy store sends them to Bone Mart; gravestones bring them to you
- when your store is packed, the overflow goes to Bone Mart
- skeletons prefer Bone Mart; rich zombies prefer you

**Check Bone Mart's prices** by walking up to its shelves, or use its counter or price
board to see the whole price list. Prices you've checked show up in a **Bone Mart**
column in your computer's Stock & Prices tab (with the day you checked). The day
summary tells you how many shoppers went there instead of you.

**Buy Bone Mart out** ($3000, store level 5) from its price list. Its staff leave,
Mr. Bones throws in his leftover stock, and every shopper in town comes to you from
then on.

### Kinds of shoppers
| | |
|---|---|
| Zombie | The regular shopper |
| Crawler | Drags itself along slowly but waits patiently. Drips a lot |
| Runner | Fast, impatient. Shows up from store level 2 |
| Skeleton | Comes over from Bone Mart's side of town. Fussy about prices. Some just wander around town |
| Brute | Big and slow, buys a cart full (4-6 different things). Level 3 |
| Rich zombie | Doesn't mind paying 50% over market. Level 3 |

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
  zombies in its line by themselves, so you're free to stock and order. Customers
  will wait a little longer in a line that has a cashier. Your staff are zombies too.
  Want to run a register yourself? Walk up to it and press E to **take over**: the
  cashier goes to a free register or takes a break, and comes back once you've
  walked away.
- **Janitor** ($20/day, up to 2): brings their own mop and cleans up the blood.
- **General Manager** ($100 to hire, $45/day, one): walks around checking the shelves
  and the staff. When a product is down to 2 on the shelves and there's none on the
  way, they walk to the computer and order a box (if you can afford it; the message
  says what they ordered). While you have a manager, everyone else works 15% faster,
  and anyone stuck on a job gets a "Back to work!".

**Staff level up** as they work (stocking items, ringing up items, mopping). There
are 5 levels and every level makes them 15% faster at everything, walking included.
The Staff tab shows what everyone is doing right now, their level and XP, and
**Let go** fires someone.

When a stocker fills a shelf and there's some of the box left, they put the rest away:
on a **storage rack** if one has room, otherwise back on the delivery zone. Boxes
that have no shelf to go on get moved off the delivery zone onto a rack, and come
back out once a shelf has room.

### More registers and self-checkouts
Buy extra registers in build mode ($250, up to 4 in total). Each one gets its own
checkout line (shown in yellow while you place it), and zombies pick the shortest
line. Put a cashier on each one, or run one yourself. Extra registers can be sold
again; the first one can only be moved.

**Self-checkouts** ($400, up to 4) work on their own: shoppers with 5 items or fewer
scan their own stuff (slower than a cashier). Now and then one jams ("Unexpected
limb in the bagging area!"): its light flashes red and you have to walk over and fix
it before the shopper loses patience. Left alone, it reboots itself after a while, and
a general manager fixes jams for you.

### Storage racks
A **storage rack** ($120) holds up to 6 boxes of anything. Use it while carrying a box
to put the box away, or with empty hands to take the top box. Great for keeping the
delivery zone clear.

### Making the store bigger
In build mode, press **Expand** and tap the outlined lot next door to buy it. Each lot
makes the store 4 tiles wider:

| Lot | Cost | Store level |
|---|---|---|
| 1 | $600 | 2 |
| 2 | $1200 | 3 |
| 3 | $2000 | 4 |

The lots are the fenced dirt next to the store with FOR SALE signs.

### Faster deliveries and a bigger delivery zone
Deliveries take 8 seconds to start with. Upgrades in the computer:
**Delivery Bike** ($150, level 2) 5 seconds, **Delivery Van** ($400, level 3)
3 seconds, **Hearse Express** ($900, level 5) about a second.

The delivery zone starts with room for 6 boxes. Make it bigger in the same tab:

| Upgrade | Cost | Store level | Boxes |
|---|---|---|---|
| Bigger Delivery Zone | $200 | 2 | 9 (3 x 3) |
| Loading Bay | $450 | 3 | 12 (4 x 3) |
| Body Dump | $800 | 4 | 16 (4 x 4) |

The zone grows into the floor around it, the way it's turned. If furniture is in the
way, the upgrade says what: move it (or move the zone somewhere roomier) first.

### Build mode (customize your store)
Press **B** (or the **Build** button). The game pauses while you build.
- **Buy** rusty shelves ($60), meat coolers ($150), storage racks ($120), gravestones
  ($25), registers ($250) and self-checkouts ($400). Hover over (or select) a button to
  see its name. Gravestones make zombies come more often (it feels like home).
- **Move** anything you've placed (stock stays on the shelf), plus the **registers**,
  the **computer**, the **OPEN sign**, the **mop bucket** and the **delivery zone**
  (boxes on it come along). When you pick up a register, a yellow
  preview shows where its checkout line will go. The line comes along with the
  register: it starts next to the register and turns around walls and shelves if it
  needs to.
- **Rotate** turns things a quarter turn: tap (or click) anything you can move. While
  you're placing or moving something, **R** (or the Rotate button) turns it before you
  put it down, and with nothing in hand R turns whatever is under the mouse. Shelves
  and coolers show their stock on the front, so turn them to face the aisle (a row
  running left-to-right shows its fronts facing down-left; a row running the other
  way, facing down-right). Turning a register turns its checkout line too (if the line
  doesn't fit one way, it skips to the next). The delivery zone turns around its top
  corner, and bigger zones grow the way it's turned.
- **Sell** for half price. Anything left on a shelf gets boxed up. (The first
  register, the computer, the sign and the mop bucket can be moved but not sold.)
- **Paint** the floor (5 styles, $40) and walls (5 colors, $30).
- **Expand** buys the lot next door (see above).
- Red tiles (door, checkout line, delivery zone) are off limits. Build mode won't let
  you block anyone's path. You can only build inside the store.
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
| Sprint | Hold Shift | RUN button (tap again to stop) |
| Use | E or Space (or click the object) | Tap the object, or the big button |
| Scan a shelf | Q | SCAN button |
| Drop a box | E with nothing usable nearby | Big button ("Drop box") |
| Grab / return the mop | E at the mop bucket | Tap the bucket |
| Mop up blood | E next to a puddle (holding the mop) | Tap the puddle |
| Take items off a shelf / remove its label | E at the shelf with empty hands | Tap the shelf |
| Put a box on a rack / take one | E at a storage rack | Tap the rack |
| Check a Bone Mart price | E at one of its shelves | Tap the shelf |
| Fix a jammed self-checkout | E next to it | Tap it |
| Take over a register from a cashier | E at the register | Tap the register |
| Build mode | B | Build button |
| Turn something (build mode) | R | Rotate button, then tap it |
| Zoom | Mouse wheel or the +/- buttons | +/- buttons |
| Pause menu | Esc or P | II button / back button |
| Close / cancel | Esc | Back button |

A gamepad works too: left stick to move, LT or L3 (sprint), A (use), X (scan), Y
(build), RB (turn things in build mode), Start (pause).

**Forgot a key?** Pause (Esc) > Options > **Controls** lists them all in the game.
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
                       customer spawning, the lots next door
  town.gd              The town outside, the lots for sale and Bone Mart
  wanderer.gd          People walking around town (Bone Mart's shoppers and staff)
  prop.gd              Town scenery (trees, cars, lamps, ruins, fences...)
  rival_shelf.gd       Bone Mart's shelves (check its prices)
  rival_desk.gd        Bone Mart's counter and price board
  build_mode.gd        Build mode: place / move / sell furniture and registers
  iso.gd               Isometric grid math (cell <-> screen)
  player.gd            Movement, tap-to-walk, carrying boxes, timed actions, scanning
  customer.gd          Customer AI (walk in -> shop -> pick a line -> pay -> leave),
                       kinds of shoppers
  staff.gd             Staff AI: stockers, cashiers and janitors, staff levels
  interactable.gd      Base class for anything the player can use
  shelf.gd             Shelves (the items drawn on them, labels, taking items
                       off), scanner support
  fridge.gd            Meat cooler = a shelf for cold products
  decoration.gd        Gravestones
  stock_box.gd         Delivery boxes
  register.gd          A checkout and its customer line
  self_checkout.gd     A self-checkout (a register that runs itself)
  storage_rack.gd      Storage racks for spare boxes
  delivery_zone.gd     Lets build mode pick up and move the delivery zone
  spill.gd             Blood spills (zombie game)
  mop_bucket.gd        The mop bucket (zombie game)
  computer.gd          Opens the store computer
  floor.gd             Draws the floor tiles and the tap marker
  hud.gd               Main UI (status bar, prompts, messages, summary)
  ui/computer_menu.gd  The computer: Stock & Prices / Products / Staff / Upgrades tabs
  ui/rival_panel.gd    Bone Mart's price list (and buying it out)
  ui/tutorial.gd       The first-day tips
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
walls. `M` is the mop bucket. Build mode can rearrange everything except the door,
which only moves if you edit the map.

**The town** is another text map, `TOWN` in `scripts/brand.gd` (48x32, with a legend
above it). The store sits where the `@`s are, `1`-`3` are the lots for sale, and the
`#` box is Bone Mart. `TOWN_SPAWNS` is where shoppers walk in from, `EXPANSIONS` the
lot prices, `RIVAL` everything about Bone Mart (name, how many shoppers it gets, its
prices, the buyout price) and `SHOPPERS` the kinds of shoppers.

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
- `store.gd`: zombie numbers, how much gravestones help, how much blood hurts, max
  registers and self-checkouts, extra town traffic
- `customer.gd`: patience and how often zombies drip
- `brand.gd`: shopper kinds, Bone Mart's prices and share, lot prices
- `staff.gd` / `game.gd`: staff speeds, XP per level
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
- Furniture is drawn with its front on the left face (`shelf.png`). An optional
  `<name>_back.png` is the same thing turned away from you; the game mirrors both for
  the other two directions. Something that mustn't be mirrored (the sign's lettering)
  can have `<name>_r1.png` (and `_r2`, `_r3`) for each direction instead.
- Characters are 16x36, with their feet at (8, 33).

## Tests

```
godot --headless --path . res://tests/feature_test.tscn     # 60+ rule checks
godot --headless --path . -s res://tests/flow_test.gd       # menus + saving, 50+ checks
godot --headless --path . --fixed-fps 60 res://tests/staff_test.tscn  # registers, staff, spills
godot --headless --path . --fixed-fps 60 res://tests/town_test.tscn   # 0.8: town, Bone Mart, lots, racks, self-checkout...
godot --headless --path . --fixed-fps 60 res://tests/label_test.tscn  # shelf labels, taking items off, first-day tips
godot --headless --path . --fixed-fps 60 res://tests/manager_test.tscn  # general manager, spare boxes, end of day
godot --headless --path . --fixed-fps 60 res://tests/takeover_test.tscn  # taking over registers, stuck shoppers, jams, skeletons
godot --headless --path . --fixed-fps 60 res://tests/rotate_test.tscn   # turning things, bigger delivery zones, closing time
godot --headless --path . --fixed-fps 60 res://tests/controls_test.tscn # sprinting, zoom steps, Controls list, frame rate + window settings
xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 res://tests/controls_test.tscn  # + zoom in a real window
xvfb-run godot --path . --rendering-driver opengl3 res://tests/camera_test.tscn  # build mode view
DAYS=5 godot --headless --path . --fixed-fps 60 res://tests/bot_test.tscn   # a bot plays 5 days
STAFF=1 SHUFFLE=1 godot --headless --path . --fixed-fps 60 res://tests/stuck_test.tscn  # busy-store stress test
```

The flow test backs up your real saves and settings first and puts them back afterwards.

## Two games

Supermarket Sim and Zupermarket Zimulator are two separate projects (two folders,
two apps, separate saves). Up to version 0.7 every script, scene, test and tool was
the same in both. Version 0.8 added the town, Bone Mart, lots, self-checkouts,
storage racks, janitors, staff levels, delivery upgrades and shopper kinds to
Zupermarket Zimulator only, so its scripts have moved on. To bring those to Supermarket
Sim, copy this game's `scripts/`, `scenes/`, `tests/` and `tools/` over and give its
`brand.gd` the new sections (`TOWN`, `TOWN_SPAWNS`, `EXPANSIONS`, `RIVAL`, `SHOPPERS`,
plus the new `FURNITURE`, `UPGRADES` and `STAFF` entries) with its own names and art.

What's different between the two:

- `scripts/brand.gd`: name, tagline, starting layout, products, furniture/paint/staff
  names, wording, lighting colors, and whether blood spills are on
- `assets/sprites/` and `icon.png`: the art (`tools/make_sprites.py` draws the right
  set for whichever game it's in, by reading `brand.gd`)
- `project.godot` (the game's name, which also decides where saves go),
  `export_presets.cfg` (app names and ids) and this README


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

- A second store of your own (run Bone Mart once you've bought it)
- More upgrades: a faster checkout scanner, bigger delivery trucks
- More staff: a security guard, a manager who hires for you
- Real walk animations (4 directions) with `AnimatedSprite2D`
- Sound: register beeps, scanner beep, door chime, music
- Humans breaking in (lock the doors!), power outages, a blood bank delivery truck
