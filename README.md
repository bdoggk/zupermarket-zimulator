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
**Start** to pause (Options > Controls lists everything). Menus (the store computer
too) work with the d-pad, A and B; in build mode the middle of the screen is the
cursor (d-pad picks what to buy, A places it). You can tap the touchscreen for anything
too.

**Windows:** it's a single .exe, no installer. The first time, Windows may show "Windows
protected your PC" because the game isn't code-signed: click **More info → Run anyway**.
That's the last time you need to download it: from 0.9.3 on, the game **updates
itself** (see below), and the versions it downloads itself don't get the warning.

It's the zombie twin of **Supermarket Sim**, which lives in its own folder. The two
games started from the same code; since version 0.8 Zupermarket Zimulator has a lot
more in it (see "Two games" below).

## What's new in 0.15.0

First person looks a lot better:
- **Real 3D counters.** Registers, self-checkouts, the store computer, Bone Mart's counter
  and the little shops' counters are solid counters now, with the till, the screen and
  pole, the monitor and keyboard, or the cash box standing on top. A self-checkout's light
  goes red when it jams.
- **3D cars and fences.** The wrecked cars in the street are 3D cars (rust, windows, tires),
  and the chain-link fences around the lots are see-through panels.
- **A sky.** Clouds drift over the town by day; at night there are stars and a full moon.
- **Ceiling tiles** over the stores (some with water stains), shaded sides on walls,
  shelves and counters, and a soft shadow under everyone. With Ray tracing on, everyone
  casts real shadows instead.
- **Your zombie hands** are at the bottom of the screen. They sway as you walk and reach
  out when you use something, and they work away while you stock a shelf or ring someone
  up. In a fist fight they come up, and the right one punches.
- **Sharper.** First person draws at full resolution on PC now. **Options > First person**
  switches between **Sharp** and **Chunky** (half resolution, with big pixels like the
  art). Phones start on Chunky because it's faster.

## What's new in 0.14.0

- **Ray tracing.** A new graphics level, **Options > Graphics > Ray tracing**: every
  light casts real shadows, in the normal view and in first person.
  - The ceiling lights, street lamps, burning barrels, the cauldron, lanterns, the shops'
    counter lights and the OPEN sign all count.
  - Shelves, coolers, racks, walls, counters, boxes on the floor, wrecked cars and ruins
    cast shadows. So do you, the shoppers, your staff and every skeleton walking around.
  - The shadows have soft edges, and a side of a shelf that faces away from the lights is
    darker.
  - Walls and roofs keep the street lamps out of the stores at night (and the store's
    light in).
- **On by default on PC.** If you had High before, you get Ray tracing now. Phones start
  on Medium, but you can switch to Ray tracing on a fast phone or handheld (the AYN Thor
  handles it).
- It runs on any graphics card that runs the game. There's no RTX card needed: the rays
  are traced in the game's own shaders, through a map of how tall everything is.

## What's new in 0.13.0

- **Gang war.** When your store reaches **level 15**, Mr. Bones walks in with two of his
  thugs, and a cutscene starts the war between Bone Mart's skeletons and your zombies.
  Then Big Rotto and his crew show up to offer their help.
- **Bone Mart isn't for sale anymore.** Instead there's **land east of Bone Mart**: four
  lots you can buy in the new **Turf** app on the store computer ($5,000, then $6,500,
  $8,000 and $9,500 as the land runs out).
  - Each lot becomes a **Zupermarket Express**: a branch store with its own shelves,
    counter and crew. It runs itself and makes about $400 a day (more at higher levels).
  - **Bone Mart buys land too**: one lot straight away and another every 3 days. Every
    Bone Mart Express sends it more shoppers.
- **Bone Mart's gangs raid you** once a day while you're open (twice once it has two
  branches). A gang of skeletons walks over from Bone Mart and either goes for your store
  or for one of your branches.
  - **Your store:** they smash a shelf (its stock is gone), scare your shoppers out, and
    rob the register (15% of your money, up to $2,500).
  - **A branch:** if they hold its counter for 20 seconds, it becomes a Bone Mart Express.
- **Fight them off yourself.** Walk up to one and press **E** (A on a controller, or tap
  them) to hit them. A health bar shows during a fight. If they knock you out, they rob
  you while you're down.
  - **Fists** are free and take four hits.
  - **Nunchucks** ($400) take two hits (they whirl right round).
  - A **Glock** ($2,500) takes two shots, from across the store (15 rounds, then a reload).
- **Hire a zombie gang** in the Turf app ($300, then $80 a day each, up to 6). They stand
  guard outside your store and jump into every fight. Knocked out, they're back the next
  day.
- **Raid Bone Mart.** Send your gang (it meets up down the street, then charges in):
  - **Bone Mart itself:** win, and it's closed for the rest of the day (every shopper
    comes to you) and you take $500 from its till.
  - **A Bone Mart Express:** win, and it's yours.
- If you'd bought Bone Mart in an earlier version, Mr. Bones buys it back and pays you your
  $3,000.

## What's new in 0.12.0

- **First person.** Press **V** (R3 on a controller, or the **View** button in the corner)
  to see the store through your own eyes, and again to go back to the view from above.
  The game remembers which one you used last.
  - It's the same store, drawn in 3D from the same art: the floor tiles, the walls and
    the shelves (with what's on them, and their labels) are solid, and shoppers, staff,
    townsfolk and everything else stand up like the sprites in old shooters. The town
    is out there too: walk out the door, down the street, to Bone Mart and the shops.
  - **Keyboard and mouse:** WASD walks, the mouse looks around, Left / Right arrows
    turn, **E** or a left click uses what's in front of you (the + in the middle turns
    yellow), **Q** or a right click scans it.
  - **Controller:** left stick walks, right stick looks, A uses, X scans.
  - **Touch:** drag to look around, tap the floor to walk there, or tap something to
    walk over and use it (USE and SCAN work as usual).
  - What you're carrying (a box, the mop) shows at the bottom of the screen, with a bar
    while you stock, ring up or mop.
  - Build mode is still seen from above: it switches back to first person when you're
    done. Count Vlad's visit plays in the view from above too.

## What's new in 0.11.0

- **Loans from Count Vlad.** The store computer has a new **Loans** app: "Count Vlad's
  Blood Money". Borrow from $250 up to $1,000 for every store level you have (up to
  $20,000). The more you borrow, the higher the interest: 5% on $250, 12% on $1,000,
  25% on $10,000, 30% on $20,000. The app shows every amount and its interest side by
  side.
- **7 days to pay it back.** A payment comes out of your money every morning. If you're
  short, he takes what you have and you fall behind; the app shows what's left, any
  missed payments, and lets you pay early or pay it all off.
- **Don't miss the last night.** On the night of the 7th day, whatever's still owed comes
  out of your money at closing. If you can't cover it, Count Vlad comes for your head:
  the lights go red, he swoops in through the door in a cloud of bats, reminds you what
  you owe and rips your head off. Then it's **GAME OVER** and you start over from day 1
  (in the same save slot: quitting during his visit doesn't save you). Skip the scene
  with Esc, B or the Skip button.
- The top bar shows what you owe and when it's due (red on the last day or when you're
  behind), and the day's summary shows what you borrowed and paid.

## What's new in 0.10.0

- **Decorations that bring in one kind of shopper.** Build mode has a **Decor** row now
  (gravestones, lanterns and the new ones). Each new decoration brings in 50% more of
  one kind of shopper, up to three of them per kind:
  - **Cauldron** (level 2): witches. It glows green.
  - **Coffin** (level 6): vampires.
  - **Bone Pile** (level 8): skeletons.
  - **Spirit Lamp** (level 9): ghosts. It glows blue.
  - **Sarcophagus** (level 10): mummies.
  - **Moon Lamp** (level 11): werewolves.

  A decoration you haven't reached the level for shows "Lv N" and can't be bought yet.
- **Say how your staff work.** The Staff app has a **How they work** section:
  - **Stockers fill empty shelves** (on/off): whether stockers put things on shelves
    with no label.
  - **Stockers take labels off** (on/off): whether stockers take the label off an
    empty shelf of something you've stopped stocking.
  - **The manager orders when...**: pick when the general manager orders more of a
    product. The choices go from "a box fits" (like before) through 3/4, half, 1/3
    and 1/4 full to "almost empty".
- **Decide what gets stocked.** Stock & Prices has a **Stock** switch for every product.
  With it off, stockers leave that product alone and the manager won't order it. You
  can still stock and order it yourself.
- **The general manager puts ordering first.** They order before checking on anything
  else, and break off their rounds to order as soon as something runs low. With the
  **Handheld Scanner** they order by scanning the low shelf, with no walk to the
  computer, and it's quicker.
- **No level cap.** Levels carry on past 14, each one taking 1,000 XP more than the
  one before. Every level after 14 pays a cash bonus that grows each time. Levels 7 to
  14 each bring something new:
  - **10 new products**, from Scarab Crunch to Golden Brains.
  - **3 new kinds of shopper:** mummies (level 7), ghosts (level 9, mostly at night)
    and werewolves (level 11, at night, and they drip).
  - **7 new upgrades:** Conveyor Belts, Mass Grave (the biggest delivery zone),
    Billboard, Staff Training, Floor Drains, Golden Sign and Neon Billboard.
  - **More staff:** one more stocker at levels 8 and 12, one more cashier at level 9
    and one more janitor at level 10.
  - Room for more shoppers in the store at once, up to level 10.

## What's new in 0.9.9

- **Take the box you want off a storage rack.** With more than one product on a rack,
  using it brings up a list: each product, how many boxes and how full they are, and a
  **Take** button. You get the fullest box of the product you pick. It works with a tap,
  a click, the arrow keys and Enter, or the d-pad and A, and closes if you walk away.
  A rack with only one product hands its fullest box over straight away.

## What's new in 0.9.8

- **Every button on the store computer works without the mouse or touch screen.**
  With the keyboard (on a Mac or PC): the arrow keys pick any button, Enter or Space
  presses it, **Tab** / Shift+Tab or **1-5** switch apps, and Esc goes back. With a
  controller (like the AYN Thor's): the d-pad, A and B, and **LB / RB** switch apps.
  That includes the buttons you couldn't reach before: the markup's < and >, the
  window's X, and the taskbar (Home, the apps, Close PC).
- Left and right stay on the row you're on (along one product's -, +, = and Order box),
  and pressing Set all prices or Auto keeps it selected.
- While the computer (or a shop, or the message log) is open, the arrow keys and the
  stick don't walk you away, and E doesn't kick you back to the computer's desktop.
- If nothing on the computer is selected (you turned it on with a tap or a click), the
  first press of an arrow key or the d-pad selects something.

## What's new in 0.9.7

Touch-screen fixes (Android, the AYN Thor):
- **Stock & Prices fits on the screen.** With the bigger touch-screen text it was cut
  off on the right, hiding the window's X, the Order box buttons and Auto. The store
  computer now gets as wide as the app needs, and shrinks to fit when the screen
  isn't wide enough (at a big UI size, say). The computer's taskbar isn't cut off at
  the bottom anymore either.
- **Everything fits at bigger UI sizes**: the build bar, the shops, Bone Mart's price
  list, the message log, the pause menu and Options shrink to fit instead of running
  off the screen.
- **Drag a list to scroll it, wherever your finger lands**: on a button in Options
  (the < > arrows and switches), a Buy button in the shops, or a price in Stock &
  Prices. Dragging no longer presses the button or brings up the keyboard.
- **Tapping a price** selects it all, brings up the keyboard and moves that row to
  the top of the list, so the keyboard doesn't cover it.
- **Pinch to zoom**: spread two fingers to zoom in, pinch them to zoom out, in build
  mode too.
- **A tap walks when your finger lifts**, so sliding a finger or pinching doesn't
  send you walking off somewhere.

## What's new in 0.9.6

- **UI size** in Options: make the menus, buttons and text bigger or smaller, from
  70% to 130%. The store itself stays the same size. On a small window it goes only
  as big as still fits.
- **Cashiers come back after you take over their register.** They're back a few
  seconds after you walk away, or once you've stood there a few seconds without
  ringing anyone up. Or press E on the register to hand it back right away.
- **Shoppers only ask for products you've licensed.** What to license next comes from
  the townsfolk you walk past (the computer's sticky note keeps a list), not from
  shoppers asking for things you can't sell yet.

## What's new in 0.9.5

Fixes from players' notes:
- **Skeletons, witches and vampires ask for things too.** The game used to say
  "Zombies keep asking..." whoever asked; now the computer and the reminders say who
  ("2 witches and 1 zombie"). They ask for their favorites a lot more, and the ones
  walking around town tell you when you walk by ("Got any Eye of Newt? Bone Mart
  doesn't!", "Your Bone Meal is all gone!").
- **The general manager keeps every shelf stocked.** With several shelves for one
  product, an empty one gets a box even while the others are full, and new empty
  shelves get products that aren't on any shelf yet.
- **Stockers bring what's emptiest first**, to the emptiest shelf for it, instead of
  whatever box is closest.
- **Stockers share the storage racks.** A second stocker no longer puts boxes back on
  the delivery zone because another one was using the rack.
- **The day's summary fits on any screen**: two columns, and the long list of
  asked-for products wraps (the top 6, then "and 10 more").
- **Clicking a price puts the cursor where you clicked** instead of selecting the
  whole price (tapping on a touch screen still selects it all).
- **E picks the right thing.** Picking up a box, stocking, ringing up a shopper and
  mopping come before taking over a cashier's register, and with two things equally
  close, E picks the one you're facing.
- **No more getting stuck on gravestones and lanterns**: only their post is solid, so
  you slide around them.
- **Time to read the messages.** They stay up longer (longer ones longest), up to 4 at
  once, never cover the hints or buttons, and the same one doesn't pile up. **Log**
  (top right), **M**, or the controller's Back/View button shows the recent ones; so
  does Messages in the pause menu.
- **One markup for every price.** In Stock & Prices, < and > set a markup over the
  market (from 25% under to 50% over), and it tells you what that means for each kind
  of shopper. **Set all prices** prices everything at it, and **Auto** keeps every
  price there as the market moves.
- Fixed: firing a stocker just as they picked up a box made the box vanish.

## What's new in 0.9.4

- **Ready for the Microsoft Store.** The game can now be packaged for the Store (see
  "Microsoft Store" below). The Store version leaves updating to the Store, so it never
  updates itself or goes online. Nothing changes in the downloaded .exe or on Android.

## What's new in 0.9.3

- **The game updates itself on Windows.** A couple of seconds after it starts, it
  checks GitHub for a newer version. If there is one, it downloads it in the
  background (a card next to the main menu shows the progress), checks the file is
  complete and undamaged, and puts it in place of the old .exe. The game you have
  open keeps running; the next time you open it (or click **Restart now**), it's
  the new version, with the same saves. Windows doesn't show its security warning
  for updates, because the game downloaded them itself.
- **Android** tells you on the main menu when a new version is out; **Download** opens
  the APK (Android installs it over this one and keeps your saves).
- **Options > Automatic updates** turns it off. With no internet, nothing happens.
- If the game's folder can't be written to (say, Program Files), the card offers the
  download page instead. If a download fails or comes through damaged, the old
  version stays as it is and the card says **Try again**.

## What's new in 0.9.2

- **Six new products that skeletons, witches and vampires love:**

  | Product | Who loves it | Level | License |
  |---|---|---|---|
  | Bone Meal | Skeletons | 1 | $30 |
  | Calcium Milk (cold) | Skeletons | 2 | $70 |
  | Eye of Newt | Witches | 2 | $60 |
  | Mandrake Root | Witches | 3 | $110 |
  | Bat Wing Crisps | Vampires | 3 | $100 |
  | Type O Blood Bag (cold) | Vampires | 4 | $150 |

  Every favorite you have **on your shelves** brings 75% more of the shoppers who love
  it (both: 2.5 times as many), they mostly come in for it, and fewer of them wander
  off to Bone Mart. When it sells out, they go back to normal. If you don't sell a
  favorite yet, those shoppers ask for it (the Products tab says
  so). The Products tab says who loves what, and so does the shopper card when you
  point at a skeleton, witch or vampire ("Loves Eye of Newt and Mandrake Root").
- Fixed: a rare crash when a shopper standing in line was removed from the game.

## What's new in 0.9.1

- **Shoppers no longer vanish into the shelves:** a shelf or storage rack with a
  shopper, a member of staff or a spy behind it fades a little so you can see them
  (more when it's you behind it). Shoppers also take things from the **front** of a
  shelf, where its stock is, so they stand in the aisle it faces instead of behind it.
- **You move as fast up and down the screen as left and right** (walking, running and
  walking to a spot you tapped). It used to be half the speed going up or down.
- **Blood is gentler on business:** a fresh puddle (wet and shiny) doesn't put anyone
  off for an hour of game time, so you have time to mop it; then it dries darker. A
  couple of dried puddles don't bother anyone either. After that each one keeps 3% of
  shoppers away (it was 8% from the moment it appeared), and never more than 25% (it was
  60%). A messy store sends at most 8% more shoppers to Bone Mart. Every puddle still
  costs a little XP while you're open, so keep mopping.
- **Moving the OPEN sign** (or anything else) with a controller in build mode: A on the
  Move tool now always picks up what's on the tile under the cursor, even when
  something else is drawn over it. (Build mode > Move > tap or click the sign, then
  where it should go.)
- Fixed: firing a stocker who was carrying a box, or selling a full storage rack, when
  the floor had no room left could make those boxes disappear. Now they go on a rack or
  on top of a box of the same thing.

## What's new in 0.9

- **The witch and the vampire have real shops now:** the market stalls across the road
  are two little buildings with walls, a door and a sign over it, shelves full of
  potions or curios, the cauldron or the coffin, and the keeper behind a counter. Walk
  in and buy at the counter.
- **Bone Mart spies on you:** from day 2, a skeleton in a trench coat sneaks into your
  store now and then while you're open and takes notes at your shelves. If it gets away,
  Bone Mart prices what it saw just under yours for the rest of the day. Walk up to it
  and press **E** (A, or tap it) to throw it out (+10 XP).
- **Spy on Bone Mart:** hire a zombie **Spy** in the Staff app ($80, $35 a day). Every
  couple of game hours they sneak over to Bone Mart, snoop around, and come back to the
  computer with its whole price list and deal of the day, when its next spy is coming,
  and a rumor that keeps shoppers away from Bone Mart for a while. In between they wait
  by the front door and throw out Bone Mart's spies.
- **Witches and vampires in town:** a couple of witches wander around all day, and
  vampires come out of the curio shop at dusk.
- The day summary says how many of Bone Mart's spies you threw out and how many got
  away, and how many reports your spy brought back.
- Fixed: selling a shelf right as a shopper took its last item could duplicate that
  item. A long status in the Staff app no longer stretches the computer window.

## What's new in 0.8.8

A bug hunt: hours of automated play (chaos play over more than 100 game days, a staff
soak test, random-layout walking, saves from 0.8.6 loaded into this version) plus a
pass over every screen size and input. Fixed:

- **Controllers:** A now presses the selected button and B goes back in every menu
  (before, only the touchscreen or a keyboard worked there), and A starts the next day.
  The **store computer** works with the d-pad: pick an app, move down its list (it
  scrolls along) and press A to order, license, hire or buy. **Build mode** works with
  a controller too: the tile in the middle of the screen is the cursor, d-pad left/right
  (or LB) picks what to buy or Move / Rotate / Sell / Expand, A places, RB turns, B
  cancels. B no longer opens the pause menu (Start does).
- Typing a price isn't interrupted when the market changes while you type.
- Boxes in a save whose spot is taken now go to the nearest free spot instead of
  vanishing.
- The day summary no longer has messages showing through it.
- The first-day tip about the town mentions the market stalls; the Controls list
  mentions them too.

## What's new in 0.8.7

- **The market across the street:** walk down the dirt path on the other side of the
  road to two stalls. Old Hagatha's **Bubbling Cauldron** brews potions and wine, and
  Count Fangsworth's **Curios** sells garlic, crucifixes and wooden stakes. Each one works
  straight away for a minute or two (Swift Potion: run 50% faster; Quickhand Potion:
  scan, stock and mop twice as fast; Garlic: nobody drips blood; Wooden Stake: nobody
  shops at Bone Mart...). What's working shows under the corner buttons with the time
  left. See "The little shops across the road" below.
- **Witches and vampires** shop with you: witches from store level 2, vampires from
  level 3 (mostly after dark, and they don't mind paying more).
- **See what shoppers are buying:** they carry a basket with their stuff sticking out,
  "+2 Canned Guts" pops up when they take something, and they leave with a bag. Point at
  a shopper (or stand next to one) to see their basket, total and what they still want.
- **Type in a price:** click the price in Stock & Prices, type it and press Enter.
- **The store computer is a PC** now, with its own desktop (and a zombie girl
  wallpaper). Click an app to open it: Stock & Prices, Products, Staff, Upgrades. The
  sticky note says what's running low and what shoppers asked for.
- **XP bar** next to your level, and a **level-up panel** that lists what the new level
  unlocks.
- **Blood costs you:** every puddle keeps shoppers away (the status bar says how many:
  "Blood: 3 (-24% shoppers)") and slowly drains your XP while you're open.
- **Reasons to license more:** every product you add brings more shoppers and earns XP,
  shoppers ask for things you don't sell yet ("You don't sell Lungs?!"), and the day
  summary and computer say what they asked for.
- **Lanterns** ($40) in build mode: warm candlelight for the dark corners. And the
  build buttons show each item's name above its picture.
- **The general manager orders properly:** they reorder when a product's shelves are
  down to a third full (not 2 items), and enough boxes to fill them back up.
- **Staff only earn XP for real work** (walking around and standing at an empty
  register earn nothing).
- **Reset** button for each employee in the Staff app, if someone gets stuck.
- **The next day only starts when you press Space** (not E), so you can keep working
  after closing.
- Fixed: a stray box on the floor after loading an older save; the mouse wheel moving
  the Sound slider and the Options page at the same time.
- The floor tiles lost their painted-on blood (so the real puddles stand out), with
  mold, grime and cracks instead.

## What's new in 0.8.6

- **Sound!** Brutes (the big zombies) growl when they shamble in, now and then while
  they shop, and when they storm out. You hear them louder the closer you are.
- **Sound** slider in Options (drag it, or select it and press left/right). You hear a
  growl at the new volume when you let go.

## What's new in 0.8.5

- No more Godot logo when the game starts: it shows the Zupermarket Zimulator title
  instead (`assets/sprites/splash.png`, set in Project Settings > Application > Boot
  Splash).

## What's new in 0.8.4

- The Controls list in Options puts everything you do with **E** in one row:
  **Interact** (E, A on a controller, or tap it).

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
  you walk away, once you've stood there a few seconds without ringing anyone up,
  or when you press E on the register again.
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
| Sound | How loud the game is, from off to 100% (a slider) |
| UI size | How big the menus, buttons and text are: 70% to 130%. The store itself stays the same size. On a small window it only goes as big as still fits |
| First person | **Sharp**: the 3D view at full resolution (PC's default). **Chunky**: half resolution, with big pixels like the art (faster; phones' default) |
| Graphics | **Low**: simple lighting (older phones, battery life). **Medium**: store lights with darker corners. **High**: adds a flickering light tube and floating dust. **Ray tracing**: High, plus every light casts real shadows (shelves, walls, people), in both views. The default on PC (phones start on Medium) |
| Automatic updates | Windows: new versions download by themselves and start the next time you open the game. Android: the main menu says when a new version is out. On by default (Windows and Android only) |
| Vibration | Phone vibration and controller rumble. It turns on when a phone or controller is available, and you feel it when you make a sale, stock a shelf, scan, mop, level up, or when a zombie storms out |

**Controls** (the button at the bottom of Options) lists every key and button, for
keyboard and mouse, controller and touch screens.

**How ray tracing works.** Every frame the game works out the light on the whole map
(`scripts/ray_tracer.gd`, `shaders/rt_light.gdshader`), 8 pixels to a floor tile.
- For every spot a light reaches, it traces 8 rays to points on the light. That's what
  gives the shadows their soft edges.
- Each ray goes tile by tile through a height map of everything on the floor, at the
  same heights first person builds its boxes with. It also goes past a post for each
  person nearby.
- The floor and everything on it are then drawn with that light instead of the normal 2D
  lights. First person's floor, walls and shelves are too, and its billboards get the
  light where they stand.
- It's all ordinary shader work, so it runs on the Compatibility renderer the game uses
  everywhere, with no ray tracing hardware. It's more work for the graphics card than
  High, so it's off on phones until you turn it on.

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
floor. A fresh puddle is wet and shiny and doesn't put anyone off yet; after an hour of
game time (30 seconds while you're open) it dries darker. A couple of dried puddles
don't bother anyone (it's a zombie store), but **after that each dried puddle keeps 3%
of shoppers away**, up to 25% for a floor covered in blood, and a messy store sends a
few more to Bone Mart. **Every puddle slowly costs you XP** while
you're open. The status bar shows how many there are and how many shoppers they're
costing you ("Blood: 5 (-9% shoppers)"). Garlic from
the vampire's shop stops the dripping for a bit, and a crucifix makes everyone ignore
the blood for a while.
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
- **Markup** (< and > at the bottom): how far over (or under) the market you want to
  sell, from -25% to +50%. It says how often each kind of shopper still buys at it.
- **=** sets one product to the market price plus your markup. **Set all prices** does
  it for everything, and **Auto** keeps every price there as the market moves.
- **Type a price:** click the price box, type it (like `3.50`) and press Enter (or click
  somewhere else). **-** and **+** still nudge it by 25 cents.

### Store level and new products
Every $1 of sales is 1 XP (the bar next to your level shows how close the next level
is), and every license you buy earns a bit too. Blood on the floor slowly costs you XP
while you're open. When you level up, a panel lists everything the new level unlocks.
Leveling up your store lets you buy **licenses** for new products in the
**Products** tab. There's no top level: up to level 14 every level brings something
new (products, shoppers, upgrades, decorations, more staff), and after that every
level takes 1,000 XP more than the one before and pays a cash bonus ($500 at level 15,
then $250 more each level). Every product you add brings a few more shoppers (up to +50%).
Shoppers only want what you've licensed, but the skeletons, witches and vampires in
town tell you which of their favorites to license next (the Products tab and the day
summary say who asked). There are 28 products in total:

| Level | Products |
|---|---|
| Start | Canned Guts, Blood Bottles, Finger Chips |
| 1 | Eyeball Jars, Bone Meal (skeletons love it) |
| 2 | Lungs, Fresh Hearts (cold), Eye of Newt (witches), Calcium Milk (cold, skeletons) |
| 3 | Kidneys, Toe Jerky, Bat Wing Crisps (vampires), Mandrake Root (witches) |
| 4 | Liver (cold), Bone Marrow, Type O Blood Bags (cold, vampires) |
| 5 | Fresh Brains (cold, rich zombies), Spine Snacks |
| 7 | Scarab Crunch (mummies), Canopic Pâté (cold, mummies) |
| 8 | Spleen Smoothie (cold), Nail Clippings |
| 9 | Ectoplasm Soda (cold, ghosts), Cobweb Candy (ghosts) |
| 10 | Tongue Tacos |
| 11 | Moon Steak (cold, werewolves), Howl Jerky (werewolves) |
| 12 | Golden Brains (cold, rich zombies) |

Cold products need a **Meat Cooler** (build mode). Keep the favorites of skeletons,
witches and vampires on your shelves to bring more of them in (see Kinds of shoppers).

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

Bone Mart isn't for sale. From store level 15 it's war instead (see **The gang war**
below).

### Spies
**Bone Mart's spies:** from day 2, Bone Mart sends a spy over once a day (twice from
store level 3), at some time between 9 AM and 6:30 PM while you're open: a skeleton in
a trench coat and dark glasses, with a red **!** over its head once it's inside. It
stops at up to 3 of your shelves to take notes. If it gets away, Bone Mart prices
everything it saw 8% under your price for the rest of the day (never below half the
market price), and the message tells you its new prices. Walk up to it and press **E**
(A on a controller, or tap it) to throw it out: it runs off without telling Bone Mart
anything, and you get 10 XP.

**Your spy** (Staff app, $80 to hire, $35 a day, one): every 2 game hours (and first
thing in the morning) they sneak over to Bone Mart, snoop at a couple of its shelves
and its counter, and come back to the computer with a report:
- Bone Mart's whole price list goes in the Bone Mart column of Stock & Prices, with its
  deal of the day
- when Bone Mart's next spy is coming
- a **rumor** about Bone Mart: 10% fewer shoppers go there for a minute of open time
  (it shows under the corner buttons with the time left)

In between trips they wait by the front door, and if one of Bone Mart's spies comes in
they go and throw it out. Spies level up like the other staff (for reports and for
spies they throw out).

### Kinds of shoppers
| | |
|---|---|
| Zombie | The regular shopper |
| Crawler | Drags itself along slowly but waits patiently. Drips a lot |
| Runner | Fast, impatient. Shows up from store level 2 |
| Skeleton | Comes over from Bone Mart's side of town. Fussy about prices. Some just wander around town. Loves Bone Meal and Calcium Milk |
| Brute | Big and slow, buys a cart full (4-6 different things). Growls. Level 3 |
| Rich zombie | Doesn't mind paying 50% over market. Loves Fresh Brains and Golden Brains. Level 3 |
| Witch | A bit fussy about prices, never drips. Loves Eye of Newt and Mandrake Root. Level 2 |
| Vampire | Comes out mostly after 5 PM, patient, pays up to 30% over market, never drips. Loves Bat Wing Crisps and Type O Blood Bags. Level 3 |
| Mummy | Slow and patient, pays a bit over market. Loves Scarab Crunch and Canopic Pâté. Level 7 |
| Ghost | Quick and impatient, comes out mostly after 5 PM. Loves Ectoplasm Soda and Cobweb Candy. Level 9 |
| Werewolf | Comes out mostly after 5 PM, buys a lot, and drips. Loves Moon Steak and Howl Jerky. Level 11 |

**Decorations:** a cauldron brings 50% more witches, and each of the other decorations
in build mode's Decor row brings in its own kind (coffins for vampires, bone piles for
skeletons, spirit lamps for ghosts, sarcophagi for mummies, moon lamps for werewolves).
Up to three of each count.

**Favorite products:** every favorite of theirs you have on your shelves (in stock)
brings 75% more of the kind that loves it (skeletons, rich zombies, witches, vampires,
mummies, ghosts or werewolves; both favorites: 2.5 times as many).
They're 4 times as likely to want it, and 5% less likely to go to Bone Mart for each
one. Shoppers only want what you sell; if you don't sell a favorite yet, the ones in
town tell you about it as you pass ("Got any Eye of Newt? Bone Mart doesn't!").
Vampires with both their favorites
stocked are the most common shoppers after dark.

Out in town, a few skeletons and witches wander around all day, and a couple of
vampires come out of the curio shop at dusk.

**What are they buying?** The bubble over a shopper's head is what they're looking
for, "+2 Canned Guts" pops up when they take something, and it goes in the basket they
carry. Point the mouse at a shopper (or stand next to one) to see what's in their
basket, the total, and what's still on their list.

### The little shops across the road
Across the road from your store, along the dirt path, are two little shops: a witch's
brewery and a vampire's curio shop. Walk in the door and press E at the counter (or tap
it):

| Shop | Sells | What it does | Lasts |
|---|---|---|---|
| The Bubbling Cauldron (Old Hagatha, a witch) | Swift Potion, $20 | Run 50% faster | 1 minute |
| | Quickhand Potion, $35 | Scan, stock and mop twice as fast | 1 minute |
| | Charm Potion, $50 | Half again as many shoppers come in | 90 seconds |
| | Grave Wine, $15 | Shoppers wait in line twice as long | 2 minutes |
| Fangsworth's Curios (Count Fangsworth, a vampire) | Garlic, $10 | Nobody drips blood | 90 seconds |
| | Crucifix, $30 | Blood doesn't scare shoppers off or cost XP | 2 minutes |
| | Wooden Stake, $40 | Nobody shops at Bone Mart | 2 minutes |

It works as soon as you buy it, and buying another adds more time (up to 10 minutes).
What's working shows under the corner buttons with the time left.

### Staff
Hire help in the computer's **Staff** tab. Each hire costs $50 up front, and staff
are paid **wages at the end of every day** (shown in the day summary, even if it puts
you in the red).
- **Stocker** ($25/day, up to 3, one more at levels 8 and 12): shambles to the stockroom, picks up delivery boxes
  and stocks the shelves. It
  tops up shelves that already have that product first, then fills empty ones, and
  puts a box down if there's nowhere for it to go. It leaves cold products alone
  until you have a meat cooler.
- **Cashier** ($30/day, one per register, up to 4, or 5 from level 9): walks to a register and rings up the
  zombies in its line by themselves, so you're free to stock and order. Customers
  will wait a little longer in a line that has a cashier. Your staff are zombies too.
  Want to run a register yourself? Walk up to it and press E to **take over**: the
  cashier goes to a free register or takes a break, and comes back once you've
  walked away or stood there a few seconds without ringing anyone up (or press E on
  the register to hand it back).
- **Janitor** ($20/day, up to 2, or 3 from level 10): brings their own mop and cleans up the blood.
- **Spy** ($80 to hire, $35/day, one): spies on Bone Mart and throws out its spies (see
  "Spies" above).
- **General Manager** ($100 to hire, $45/day, one): ordering comes first, then
  walking around checking the shelves and the staff. When a product's shelves have
  room for a whole box (counting boxes that are already around or on the way; you can
  make them wait longer, see below), they drop what they're doing and order enough
  boxes to fill them back up, up to 4 at a time and as many as fit on the delivery
  zone (if you can afford it; the message says what they ordered). They walk to the
  computer to order, or with the **Handheld Scanner** they scan the low shelf instead,
  which is quicker. While you have a
  manager, everyone else works 15% faster, and anyone stuck on a job gets a
  "Back to work!".

**Staff level up** as they work, and only for real work: items stocked, items rung
up, spills mopped, boxes ordered, self-checkouts fixed. Walking around or standing
at an empty register earns nothing, and a manager only gets credit for a
"Back to work!" once that person actually gets something done. There are 5 levels
(7 with the **Staff Training** upgrade, which also doubles the XP they earn) and every
level makes them 15% faster at everything, walking included.
The Staff tab shows what everyone is doing right now, their level and XP. **Reset**
sends someone back to where they start the day (their register, the mop bucket, the
delivery zone...) if they ever get stuck, and **Let go** fires someone.

**How they work** (in the Staff tab):
- **Stockers fill empty shelves**: on (the default), stockers put things on shelves
  that have no label, and the manager orders something new for them. Off: those
  shelves stay empty until you fill them.
- **Stockers take labels off**: on (the default), a stocker takes the label off an
  empty shelf of something you've switched Stock off for, so the shelf can be used
  for something else.
- **The manager orders when...**: "a box fits" (the default), 3/4 full, half full, 1/3
  full, 1/4 full or almost empty. The later it is, the fewer boxes sit around, but the
  more likely a shelf runs out.
- **Stock** switch (in Stock & Prices, one per product): off means stockers don't
  stock it and the manager doesn't order it. You can still do both yourself.

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
to put the box away, or with empty hands to take one out. With more than one product
on it, a list comes up to **pick which product** you want (tap or click Take, or use the
arrow keys or d-pad and Enter / A), and you get the fullest box of it. With just one
product on it, you get that straight away. Great for keeping the delivery zone clear.

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
- **Buy** rusty shelves ($60), meat coolers ($150), storage racks ($120), registers
  ($250) and self-checkouts ($400). Each button shows the name, a picture and the
  price.
- **Decor** opens the decorations' row: gravestones ($25), lanterns ($40), cauldrons
  ($60, level 2), coffins ($90, level 6), bone piles ($80, level 8), spirit lamps ($110,
  level 9), sarcophagi ($140, level 10) and moon lamps ($160, level 11). Any decoration
  makes zombies come more often (it feels like home), and each one from the cauldron on
  brings more of one kind of shopper (see Kinds of shoppers). Lanterns, cauldrons,
  spirit lamps and moon lamps light up the floor around them. One you haven't reached
  the level for shows "Lv N" instead of a price.
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
computer. A scanner icon appears next to your money once you own it. Your general
manager uses it too.

### Loans (Count Vlad)
Short of cash? Open the computer's **Loans** app. Count Vlad lends up to $1,000 for every
store level you have (up to $20,000), one loan at a time:

| Borrow | Interest | Pay back | Each morning (7 days) |
|---|---|---|---|
| $250 | 5% | $262.50 | $37.50 |
| $500 | 8% | $540 | $77.15 |
| $1,000 | 12% | $1,120 | $160 |
| $2,000 | 15% | $2,300 | $328.58 |
| $3,000 | 18% | $3,540 | $505.72 |
| $5,000 | 20% | $6,000 | $857.15 |
| $7,500 | 23% | $9,225 | $1,317.86 |
| $10,000 | 25% | $12,500 | $1,785.72 |
| $15,000 | 28% | $19,200 | $2,742.86 |
| $20,000 | 30% | $26,000 | $3,714.29 |

(The payments are rounded up to the cent, so the last one is a few cents less.)

A payment comes out of your money every morning for 7 days. If you don't have enough, he
takes what you have, and the rest is behind (the Loans app and the top bar show it). You
can pay early, or pay it all off, any time. On the night of the last day, whatever's still
owed comes out of your money at closing. If you can't cover it, Count Vlad comes for your
head: you lose everything and start over from day 1.

### The gang war
At **store level 15** a cutscene starts the war: Mr. Bones and his thugs pay you a visit
(Bone Mart isn't for sale, and every lot he gets east of his store is another Bone Mart),
and then Big Rotto offers you his crew. Everything is in the store computer's **Turf** app.

**Land east of Bone Mart.** Four lots, behind fences, with FOR SALE signs:
- Buy one ($5,000 for the first lot anyone buys, then $6,500, $8,000 and $9,500), and a
  **Zupermarket Express** opens on it. It has its own shelves, counter and crew, it runs
  itself, and it makes **$400 a day** plus $25 for every store level past 15. That money
  comes in at closing, and the day summary shows it.
- **Bone Mart buys lots too**: one when the war starts, then another every 3 days while
  any are left.
- Each branch sends shoppers one way: Bone Mart's send more of them to Bone Mart, yours
  send fewer (3% each).

**Bone Mart's raids.** While you're open, a gang of 2 to 5 skeletons comes once a day
(twice once Bone Mart has two branches). A RAID! banner, your health and your weapon show
in the middle of the screen.
- **On your store:** each skeleton smashes a shelf (the stock on it is gone) and then they
  rob the register: 15% of your money, up to $2,500. Shoppers near them run out (it counts
  as a walkout). No new shoppers come in while they're inside.
- **On one of your branches:** if they hold its counter for 20 seconds, it becomes a Bone
  Mart Express.
- At closing time they go home.

**Fighting.** Walk up to one of Bone Mart's skeletons and press **E** (A on a controller,
click or tap them) to hit them. Knock one out and it falls apart into a heap of bones.

| Weapon | Cost | Skeletons (4 health) go down in |
|---|---|---|
| Fists | free | 4 punches |
| Nunchucks | $400 | 2 hits |
| Glock | $2,500 | 2 shots, from up to 8 tiles away (15 rounds, then a reload) |

You have 10 health and get it back a few seconds after the fighting stops. If they knock
you out, you're down for 3 seconds, and if they're in your store they rob the register
while you're down. Every skeleton you or your gang knock out earns 10 XP.

**Your gang.** Hire up to 6 zombie gangsters ($300 each, then $80 a day each, paid with
your staff's wages). They stand guard on the sidewalk outside your store and run to every
fight, at your store or at a branch. A gangster who gets knocked out is back the next day.

**Raiding Bone Mart.** Send your gang (everyone who's ready) while you're open. They meet
up down the street, then charge in together, and you can join the fight.
- **Bone Mart itself** (3 to 5 skeletons guard it): win, and it's closed for the rest of
  the day. Its staff go home, the sign says CLOSED and every shopper comes to you. You also
  take $500 (plus $50 a level past 15) from its till. It opens again the next morning.
- **A Bone Mart Express** (2 skeletons): win, and it's yours.
- Lose, and your gang is out cold until tomorrow.

### Upgrades for bigger stores
| Level | Upgrade | Cost | What it does |
|---|---|---|---|
| 7 | Conveyor Belts | $1,200 | Registers and self-checkouts ring up 25% faster |
| 8 | Mass Grave | $1,400 | The biggest delivery zone (5x4, 20 boxes). Needs the third zone upgrade |
| 9 | Billboard | $1,500 | 15% more shoppers |
| 10 | Staff Training | $1,800 | Staff earn XP twice as fast and can reach level 7 |
| 12 | Floor Drains | $2,200 | Blood that's been on the floor for 2 hours drains away |
| 13 | Golden Sign | $2,500 | Shoppers pay up to 10% more before it feels pricey |
| 14 | Neon Billboard | $3,000 | Another 15% more shoppers. Needs the Billboard |

### Controls

| | PC | Android |
|---|---|---|
| Move | WASD / arrow keys, or click a spot | Tap a spot (sliding a finger just looks, it doesn't walk) |
| Sprint | Hold Shift | RUN button (tap again to stop) |
| Interact: pick up / drop boxes, stock or empty shelves, ring up shoppers, take over a register, racks, the computer, the OPEN sign, the mop, a jammed self-checkout, Bone Mart's prices, the shop counters across the road, throwing out Bone Mart's spies, hitting Bone Mart's gangsters | E (or click the thing) | Tap it, or the big button |
| Scan a shelf | Q | SCAN button |
| Next day (end of the day) | Space (only Space: you can keep working after closing) | Tap the bar at the bottom |
| Build mode | B | Build button |
| Turn something (build mode) | R | Rotate button, then tap it |
| Zoom | Mouse wheel or the +/- buttons | Pinch with two fingers, or the +/- buttons |
| First / third person | V, or the View button | View button |
| Look around (first person) | Mouse; Left / Right arrows turn | Drag |
| Use / scan what you look at (first person) | Left-click / right-click (or E / Q) | Tap it, or USE / SCAN |
| Pause menu | Esc or P | II button / back button |
| Recent messages | M, or the Log button | Log button |
| Close / cancel | Esc | Back button |
| Store computer | Arrow keys pick any button, Enter or Space presses it, Tab / Shift+Tab or 1-6 switch apps, Esc goes back | Tap |

A gamepad works too: left stick to move, LT or L3 (sprint), A (use), X (scan), Y
(build), R3 (first / third person; the right stick looks around in first person),
Start (pause), Back/View (messages), B (back). Every menu works with the d-pad, A and B, the store
computer and its apps included. In build mode the tile in the middle of the screen is
the cursor: left stick to look around, d-pad left/right (or LB) to pick what to buy or
Move / Rotate / Sell / Expand, A to place it (or pick up, sell...), RB to turn it, B to
cancel. On the store computer the d-pad reaches every button (the markup, Set all prices,
Auto, the window's X and the taskbar too), and LB / RB switch apps.

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
  updater.gd           Autoload "Updater": checks GitHub for a new version, downloads,
                       checks and swaps in the new .exe on Windows
  store_lights.gd      Store lighting for each graphics level, day/night tint
  ray_tracer.gd        Ray tracing: the height map, the lights, the lightmap, and
                       putting it on the normal view and first person
  market.gd            Prices that drift over time + daily news events
  store.gd             Builds the store from the map, furniture placement rules,
                       registers and their lines, deliveries, decor, staff, spills,
                       customer spawning, the lots next door
  town.gd              The town outside, the lots for sale and Bone Mart
  gang_war.gd          The gang war's score: land, your gang, weapons, raids (Game.war)
  turf.gd              The gang war in town: the lots east of Bone Mart, branch stores, the fights
  gangster.gd          A gangster (Bone Mart's skeletons, your zombie gang): walking and fighting
  branch_shelf.gd      A shelf in a branch store
  wanderer.gd          People walking around town (Bone Mart's shoppers and staff)
  prop.gd              Town scenery (trees, cars, lamps, ruins, fences...)
  rival_shelf.gd       Bone Mart's shelves (check its prices)
  rival_desk.gd        Bone Mart's counter and price board
  rival_spy.gd         Bone Mart's spies (sneak in, take notes, get thrown out)
  shop_counter.gd      The counters in the little shops across the road
  build_mode.gd        Build mode: place / move / sell furniture and registers
  iso.gd               Isometric grid math (cell <-> screen)
  player.gd            Movement, tap-to-walk, carrying boxes, timed actions, scanning
  customer.gd          Customer AI (walk in -> shop -> pick a line -> pay -> leave),
                       kinds of shoppers
  staff.gd             Staff AI: stockers, cashiers, janitors, the manager and the
                       spy, staff levels
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
  ui/computer_menu.gd  The computer: Stock & Prices / Products / Staff / Upgrades / Loans / Turf
  ui/rival_panel.gd    Bone Mart's price list
  ui/tutorial.gd       The first-day tips
  ui/build_bar.gd      The build mode toolbar, decorations row and paint menu
  ui/loan_cutscene.gd  Count Vlad's visit when a loan isn't paid back in time
  ui/war_cutscene.gd   The gang war starting (store level 15)
  first_person.gd      First person: the store in 3D, built from the 2D one, and the controls
  fp_art.gd            Turns the iso art into what first person needs (flat floor tiles, box sides)
  fp_models.gd         First person's little 3D models: counters and what's on them, cars, fences
  ui/pause_menu.gd     The in-game pause menu
  ui/message_log.gd    Recent messages (M, the Log button, or the pause menu)
  ui/options_menu.gd   The Options screen (main menu and pause menu)
  ui/ui.gd             UI helpers and theme
  menu/menu.gd         Main menu: Continue / New Game / Load Game / Options / Quit
  menu/menu_backdrop.gd  The store drawn behind the main menu (from your latest save)
shaders/
  rt_light.gdshader    Ray tracing: traces the shadow rays, one quad per light
  rt_canvas.gdshader   Ray tracing in the normal view (the floor, boxes, people)
  rt_fp.gdshader       Ray tracing in first person
  fp_sky.gdshader      First person's sky: clouds by day, stars and the moon at night
assets/sprites/        All the pixel art
assets/sounds/         Sounds (.ogg / .wav). A shopper kind's "sound" in brand.gd is what it growls
tools/make_sprites.py  The Python script that draws the placeholder art (for both games)
tools/make_sounds.py   Makes the sound effects (Count Vlad's visit, the gang war's punches, shots...) from scratch
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
prices, the buyout price, its spies), `SHOPS` the two little shops (each has its own
letters in the map for its walls, floor, door, shelves, counter and keeper) and
`SHOPPERS` the kinds of shoppers.

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

The start-up screen is `assets/sprites/splash.png` (the title, drawn by
`make_sprites.py`); it's shown on the dark background color set in Project Settings >
Application > Boot Splash.

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
xvfb-run godot --path . --rendering-driver opengl3 res://tests/touch_test.tscn   # real finger taps, slides and pinches on a 1920x1080 touch screen (first person too)
DAYS=5 godot --headless --path . --fixed-fps 60 res://tests/bot_test.tscn   # a bot plays 5 days
STAFF=1 SHUFFLE=1 godot --headless --path . --fixed-fps 60 res://tests/stuck_test.tscn  # busy-store stress test
godot --headless --path . --fixed-fps 60 res://tests/shops_test.tscn   # the little shops, brews, witches and vampires, favorite products
godot --headless --path . --fixed-fps 60 res://tests/spy_test.tscn     # Bone Mart's spies and yours
godot --headless --path . --fixed-fps 60 res://tests/pad_test.tscn     # menus, the computer and build mode with a controller
SEED=1 godot --headless --path . --fixed-fps 60 res://tests/walk_test.tscn  # walking between random spots in random layouts
godot --headless --path . res://tests/update_test.tscn  # the updater, against a stand-in GitHub (needs python3)
godot --headless --path . --fixed-fps 60 res://tests/fixes_test.tscn  # 0.9.5's fixes from players' notes
godot --headless --path . --fixed-fps 60 res://tests/rack_test.tscn   # picking which box to take off a storage rack
godot --headless --path . --fixed-fps 60 res://tests/rules_test.tscn  # how staff work: Stock switches, stocker rules, when the manager orders
godot --headless --path . --fixed-fps 60 res://tests/levels_test.tscn # levels with no cap, levels 7-14, decorations, the new upgrades
godot --headless --path . -s res://tests/loan_test.gd                 # loans, the payments, Count Vlad's visit and starting over
godot --headless --path . --fixed-fps 60 res://tests/fp_test.tscn     # first person: the 3D store and its models, sky, shadows, Sharp / Chunky, walking, looking, using, tapping
godot --headless --path . --fixed-fps 60 res://tests/war_test.tscn    # the gang war: land, branches, raids both ways, fighting, the cutscene
xvfb-run godot --path . --rendering-driver opengl3 res://tests/rt_test.tscn  # ray tracing: the setting, the height map, shadows read back from the lightmap, both views
SEED=1 MINUTES=240 godot --headless --path . --fixed-fps 60 -s res://tests/chaos_test.gd  # chaos play (below; TOUCH=1 for a touch screen)
```

The flow and chaos tests back up your real saves and settings first and put them back
afterwards.

**Chaos play** (`tests/chaos_test.gd`) plays for hours of game time doing random things a
player could do (walking, using things, the computer, build mode, the shops, spies, the gang war,
clicking and pressing keys anywhere, saving and loading, settings, letting days go by)
and checks every few frames that the game still makes sense: no script errors, nothing
in the wrong place, no stock appearing or vanishing, nobody stuck, no day that never
ends, no deliveries that never arrive, no growing pile of nodes. `MODE=staff` builds a
big store with every kind of staff and just watches them run it. When running two at
once, give each its own `XDG_DATA_HOME` so they don't share save files.

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

**Microsoft Store:** everything for the Store is in `store/`:
- `AppxManifest.xml.in`, `Assets/` (Start menu and taskbar icons) and `make_msix.ps1`,
  which packs the Windows .exe into `ZupermarketZimulator-store.msix` with Windows'
  `makeappx` (it runs on GitHub Actions; the Store signs the package itself).
- `identity.ini`: the three values from Partner Center > Product identity. Once it's
  filled in, each release also gets a `ZupermarketZimulator-store.msix` to upload.
- `listing/`: the screenshots and art for the Store page, made by
  `tools/make_store_art.py` from `CLEAN=1` showcase screenshots (see the script).
The Store doesn't allow 0 as a package's first number, so game version 0.9.4 is
package version 1.9.4.0. A game installed from the Store lives in
`Program Files/WindowsApps`; the updater sees that and stays off.

**Releases and updates:** the game updates itself from the latest GitHub release
(`scripts/updater.gd`). It compares the release's tag (`v0.9.3`) with
`application/config/version` in Project Settings, so bump the version before
exporting, and keep the file names: `ZupermarketZimulator-windows.exe` and
`ZupermarketZimulator-android.apk`. GitHub lists each file's SHA-256, and the game
refuses a download that doesn't match.

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


- Run a branch store yourself (walk in and stock it), and more turf to fight over
- More upgrades: a faster checkout scanner, bigger delivery trucks
- More staff: a security guard, a manager who hires for you
- Real walk animations (4 directions) with `AnimatedSprite2D`
- More sound: register beeps, scanner beep, door chime, music
- Humans breaking in (lock the doors!), power outages, a blood bank delivery truck
