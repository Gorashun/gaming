# NPC Dialogue — Wickwright

> Owner: game-writer. Generated from the same source as `game/content/base/npc_text.json` (keep them in sync; edit the JSON if the MD drifts).
> Id pattern: `npc_<act>_<role>` (roles: smith, alchemist, jeweler, runecarver, trader, stash, stablemaster, petkeeper, innkeeper, questgiver, storyteller, waypoint). Quests: `q_<act>_<slug>`.
> Quest `type` and `target` follow CONTENT_SCHEMA (`kill|collect|explore|boss|talk`). Player-facing text never says "kill": we **rekindle**.
> `bark_after_act` plays once the act boss is rekindled. Barks are ≤ ~12 words; no pressure language (PLAYER_WELFARE.md).

## Act I — Wickmire · Lamplight Hollow (`a1_town`)

### Brannoc Sparkwell — Smith (`npc_a1_smith`)
*Quirk:* Huge, gentle, terrified of moths. Names every hammer.

- **Greeting:** Big Bran's forge! Mind the sparks. And the moths. Mostly the moths.
- **Bark:** This is Hammer Gerald. Say hello to Gerald.
- **Bark:** Upgrading never breaks a thing. Not on my anvil.
- **Bark:** Is that a moth? Tell me that's not a moth.
- **Bark:** Bring me Soot Dust. I'll bring the shine.
- **Bark:** Hot iron, warm heart. That's the rule.
- **Bark:** Hammer Gerald's cousin is Hammer Gertrude. She's for fancy work.
- **Bark:** Every sword remembers the hand that made it. Mine remember hugs.
- **After the act:** You rang the old bell back to life! Gerald is so proud.

### Nettle Pim — Alchemist (`npc_a1_alchemist`)
*Quirk:* Tiny. Sneezes glitter when potions fizz.

- **Greeting:** Oh! A customer! Hold on, I need to climb onto my stool.
- **Bark:** Red potion: feel better. Blue potion: don't drink the blue one.
- **Bark:** Ah— ah— ACHOO! Sorry. Glitter. It happens.
- **Bark:** Bone Meal makes lovely potions. Don't ask how.
- **Bark:** Tall people always knock over my shelves.
- **Bark:** Fizzing means it's working! Or broken. Usually working.
- **Bark:** Drink a potion when your light gets low. Easy!
- **After the act:** The bog lights came back! My potions fizz twice as happy now.
- **Quests:** `q_a1_bone_meal`

### Madame Glimmerwick — Jeweler (`npc_a1_jeweler`)
*Quirk:* Wears 40 rings. Always looking for the one she's wearing.

- **Greeting:** Welcome, darling! Have you seen my blue ring? …Oh. Found it.
- **Bark:** Forty rings, and not one is the right one.
- **Bark:** A gem in a socket is a little star in your pocket.
- **Bark:** Candle Ruby for courage. Frost Sapphire for calm.
- **Bark:** I polish my rings so often they polish me back.
- **Bark:** Never trust a Magpie Imp near a jewellery box.
- **Bark:** Darling, that amulet is SO you.
- **After the act:** The Bellringer's rekindled! I shall wear my celebration ring. Where is it…

### Grandpa Knurl — Runecarver (`npc_a1_runecarver`)
*Quirk:* Carves runes on everything, including his spoons.

- **Greeting:** Hm? Oh, hello. Mind the table. I carved a rune on it.
- **Bark:** This spoon has a rune for 'soup'. Very useful.
- **Bark:** Runes are just words that remember to work.
- **Bark:** Carve slow. The wood tells you where.
- **Bark:** I once carved 'brave' on my boots. Didn't help.
- **Bark:** When you reach Rimehall, find Master Quillon. He carves ice!
- **Bark:** My chair says 'sit'. So I do.
- **After the act:** I carved 'thank you' on my door for you. Go and see.
- **Quests:** `q_a1_candle_mages`

### Pocket Polly — Trader (`npc_a1_trader`)
*Quirk:* Coat with a hundred pockets. Never the right one.

- **Greeting:** Buying? Selling? Let me check my pockets. All of them.
- **Bark:** Pocket forty-two… no, that's a frog. Sorry, frog.
- **Bark:** I've got a pocket for everything. Finding it is extra.
- **Bark:** I buy anything shiny. Except Magpie Imps. They buy back.
- **Bark:** Fair prices, honest pockets!
- **Bark:** One of my pockets hums at night. I don't check that one.
- **Bark:** Something you don't need? I'll give you coins for it.
- **After the act:** You're a hero now! I've made you your own pocket.
- **Quests:** `q_a1_magpie`

### Humphrey — Stash Keeper (`npc_a1_stash`)
*Quirk:* A very old tortoise. Counts everything twice.

- **Greeting:** Your… things… are… safe. One. One. Two. Two.
- **Bark:** Nothing… lost… in… a hundred… years.
- **Bark:** Slow… and… safe.
- **Bark:** Your stash… follows you… to every… town. Clever… that.
- **Bark:** I counted… your socks. Twice. All there.
- **Bark:** Don't… rush. I never… do.
- **Bark:** Shell… is also… a stash.
- **After the act:** The… bell… rang. I… heard it. Twice.

### Hattie Hayloft — Stablemaster (`npc_a1_stablemaster`)
*Quirk:* Rents giant bog-newts. Speaks for them.

- **Greeting:** Hello! Puddle says hello too. Don't you, Puddle? She does.
- **Bark:** Puddle says you look like a good rider.
- **Bark:** A newt on the path is faster than two boots in the mud.
- **Bark:** If something bonks you, you'll hop off. Newts are shy.
- **Bark:** Squelch says he wants a snack. Squelch always wants a snack.
- **Bark:** Riding's quicker in the zones and in town, dear.
- **Bark:** Pat them on the nose. Gently. They like that.
- **After the act:** Puddle says you're the bravest person she's ever carried.
- **Quests:** `q_a1_newt_ride`

### Wren Whistleby — Pet Keeper (`npc_a1_petkeeper`)
*Quirk:* Nine years old. Extremely serious about pets.

- **Greeting:** State your pet's name and favourite snack, please.
- **Bark:** Pets pick up loot for you. Very professional.
- **Bark:** Pets get stronger when you go adventuring together.
- **Bark:** Some pets dig up treasure. I'm not jealous. I'm a bit jealous.
- **Bark:** Every pet deserves a good name. Not 'Pet'.
- **Bark:** I've got a list of all the pets in Lumenholm. It's long.
- **Bark:** Pets don't fight. They help. That's different.
- **After the act:** My pets and I made you a medal. It's a leaf. It's a medal leaf.

### Mother Mabble — Innkeeper (`npc_a1_innkeeper`)
*Quirk:* Runs The Soggy Candle. Believes soup fixes everything.

- **Greeting:** Sit down, pet. Soup's hot. Everything's better after soup.
- **Bark:** Rest here and the Homeward Wick will bring you back.
- **Bark:** Resting makes your light glow brighter. That's just true.
- **Bark:** Soup of the day: soup.
- **Bark:** The roof leaks, but only on people who complain.
- **Bark:** You look tired. Tired is allowed.
- **Bark:** A warm bed, a warm bowl, a warm light. That's home.
- **After the act:** Soup's on the house tonight. Well. Soup's always on the house.

### Warden Hollis Reed — Warden (`npc_a1_questgiver`)
*Quirk:* Last Lamplighter of Wickmire. Helmet two sizes too big.

- **Greeting:** Wickbearer! Thank the light. I mean it. I really need help.
- **Bark:** The helmet was my father's. I'll grow into it.
- **Bark:** Stay in your light and you'll be alright.
- **Bark:** The Rattlebones aren't bad. They're just lost.
- **Bark:** Every lamp we tie down is one more we keep.
- **Bark:** When you're tired, come back. The bog will wait.
- **Bark:** I heard a bell under the water last night.
- **Bark:** One step at a time. That's how you cross a bog.
- **After the act:** Tolly's home. The lamps are down. You did that. We did that.
- **Quests:** `q_a1_lost_rattlers`, `q_a1_warden_crypt`, `q_a1_bellringer`

### Grandmother Purl — Storyteller (`npc_a1_storyteller`)
*Quirk:* Knits while she talks. The scarf is never finished.

- **Greeting:** Come sit, little light. Pass me that yarn and I'll tell you a tale.
- **Bark:** Knit one, purl one, tell one story.
- **Bark:** This scarf is for everyone in the village. It's a long scarf.
- **Bark:** Once, the sky had a lantern, and nobody thought to thank it.
- **Bark:** The Grey Guest knocked on my door once. I gave him tea.
- **Bark:** My granddaughter sews dolls that talk back. Takes after me.
- **Bark:** Every story is a light you can carry in your head.
- **Bark:** Lost your way? Follow the lamps. They float toward home.
- **After the act:** Tolly used to ring for my tea. He'll ring again now, you'll see.
- **Quests:** `q_a1_purl_yarn`

### Flicker — Waypoint Keeper (`npc_a1_waypoint`)
*Quirk:* A small wisp. Flickers when it fibs.

- **Greeting:** Hi! I'm Flicker! I'm not scared at all! *flicker*
- **Bark:** Touch a waypoint once and you can come back any time!
- **Bark:** Travelling to town is free. The rest costs a little gold.
- **Bark:** I've been to every waypoint. *flicker* Okay, two.
- **Bark:** Wisps like me show the way. Not like the bad wisps. We're nice.
- **Bark:** Tap the map to go places!
- **Bark:** I'm the brightest wisp in Wickmire! *flicker flicker*
- **After the act:** You did it! I wasn't worried. *flicker* I was a bit worried.
- **Quests:** `q_a1_drowned_graves`

### Side quests — Act I — Wickmire

| id | Name | Giver | Type | Target × count |
|---|---|---|---|---|
| `q_a1_lost_rattlers` | Bedtime for Bones | `npc_a1_questgiver` | kill | `rattler` × 10 |
| `q_a1_bone_meal` | Glitter Ingredients | `npc_a1_alchemist` | collect | `bone_meal` × 8 |
| `q_a1_drowned_graves` | Where the Graves Went | `npc_a1_waypoint` | explore | `a1_z1` × 1 |
| `q_a1_magpie` | Pocket Thief | `npc_a1_trader` | kill | `magpie_imp` × 1 |
| `q_a1_candle_mages` | Too Many Candles | `npc_a1_runecarver` | kill | `candle_mage` × 5 |
| `q_a1_purl_yarn` | The Borrowed Yarn | `npc_a1_storyteller` | talk | `npc_a1_jeweler` × 1 |
| `q_a1_warden_crypt` | The Warden Below | `npc_a1_questgiver` | kill | `warden` × 1 |
| `q_a1_bellringer` | The Bell Under the Water | `npc_a1_questgiver` | boss | `sunken_bellringer` × 1 |
| `q_a1_newt_ride` | Newt Test Drive | `npc_a1_stablemaster` | explore | `a1_z2` × 1 |

**Bedtime for Bones** (`q_a1_lost_rattlers`)
- *Offer:* The Rattlers climbed out of their graves and forgot why. Rekindle 10 and send them home to bed.
- *Done:* Ten sleepy Rattlers, back in bed. They even said goodnight!

**Glitter Ingredients** (`q_a1_bone_meal`)
- *Offer:* I need 8 Bone Meal for my potions. Don't ask. Ah— ACHOO! See? Very important. Well, a bit important. Whenever!
- *Done:* Perfect! One potion coming up. Stand back. Glitter incoming.

**Where the Graves Went** (`q_a1_drowned_graves`)
- *Offer:* The old graveyard slid into the bog! Go and find the far end? I'd come too but *flicker*.
- *Done:* You found it! And came back! I knew you would. *no flicker*

**Pocket Thief** (`q_a1_magpie`)
- *Offer:* A Magpie Imp nicked something from pocket nineteen! It's in the Bellcrypt Halls. Catch it!
- *Done:* My thimble! And some extra gold? Keep that. The imp won't miss it. Much.

**Too Many Candles** (`q_a1_candle_mages`)
- *Offer:* Candle Mages keep lighting cold, grey candles. Wrong sort of light. Rekindle 5 of them?
- *Done:* Proper warm light again. I carved you a rune. It says 'ta'.

**The Borrowed Yarn** (`q_a1_purl_yarn`)
- *Offer:* Madame Glimmerwick borrowed my silver yarn for a ring. Could you ask for it back? Nicely.
- *Done:* My silver yarn! The scarf grows another inch. Thank you, little light.

**The Warden Below** (`q_a1_warden_crypt`)
- *Offer:* A Crypt Warden guards the Sunken Nave. It thinks it's still on duty. Relieve it of its shift.
- *Done:* The old Warden's resting at last. So can you, if you like.

**The Bell Under the Water** (`q_a1_bellringer`)
- *Offer:* Every DONG makes someone fall asleep in the bog. Climb the Belfry of the Drowned and stop that bell.
- *Done:* It was Tolly. All this time, calling us home. And now he's home too.

**Newt Test Drive** (`q_a1_newt_ride`)
- *Offer:* Puddle wants to stretch her legs! Ride through the Bellcrypt Halls and back. She says please.
- *Done:* Puddle says that was the best day of her life. She says that every day.

## Act II — Whisperwood · Owlstead (`a2_town`)

### Tamsin Knotwood — Smith (`npc_a2_smith`)
*Quirk:* Apologises to trees before using wood.

- **Greeting:** Sorry, tree. Oh! Hello. Sorry. I talk to trees.
- **Bark:** Sorry, log. This won't hurt a bit.
- **Bark:** Wood remembers where it grew. Be kind to it.
- **Bark:** Axe handles, bow staves, and one very nice spoon.
- **Bark:** Upgrading here is just like Big Bran's. Only woodier.
- **Bark:** The birches told me a secret about you. I didn't listen.
- **Bark:** Every nick in a blade is a story.
- **After the act:** The shadows are home! The trees are finally quiet. Well. Quieter.
- **Quests:** `q_a2_gossip`

### Professor Fennimore Puffcap — Alchemist (`npc_a2_alchemist`)
*Quirk:* Part mushroom. Puffs sparkly spores when surprised.

- **Greeting:** Ah, a student! Welcome to the finest laboratory in any tree. *puff*
- **Bark:** Alchemy: turning 'oops' into 'ooh!'
- **Bark:** Potions, elixirs, transmutes. All the -ions and -irs.
- **Bark:** Don't startle me. *puff* See? Sparkles everywhere.
- **Bark:** Two small things can become one useful thing. That's the trick.
- **Bark:** Mushrooms are excellent listeners. Terrible at maths.
- **Bark:** Let me show you the station. Just one little brew to start.
- **Bark:** Elixirs last a while. Enjoy the glow.
- **After the act:** Mother Bark sent me a thank-you note. Written on bark. Naturally. *puff*
- **Quests:** `q_a2_spores`

### Cress Dewdrop — Jeweler (`npc_a2_jeweler`)
*Quirk:* Collects dewdrops as gems. They keep evaporating.

- **Greeting:** Hello! Careful where you step. That's a jewel. Was a jewel.
- **Bark:** My best gem evaporated this morning. Again.
- **Bark:** Moss Emeralds don't evaporate. That's why I like them.
- **Bark:** Put a gem in a socket and it helps you forever.
- **Bark:** Dew is just tiny water that dreams of being a gem.
- **Bark:** Pretty things are best shared.
- **Bark:** I found a gem in an owl's nest. The owl found me.
- **After the act:** The morning dew is back! My shop is full again!

### Hob Mossbeard — Runecarver (`npc_a2_runecarver`)
*Quirk:* His beard grows moss. Carves runes on acorns.

- **Greeting:** Mm. Welcome. Don't mind the beard. It's thriving.
- **Bark:** A rune on an acorn grows into a rune on a tree.
- **Bark:** Something is living in my beard. We have an agreement.
- **Bark:** Slow carving, quick magic.
- **Bark:** My brother Knurl carves spoons. Spoons. Honestly.
- **Bark:** The forest has its own runes. You just have to read bark.
- **Bark:** Beard's getting long. It's got a mushroom now.
- **After the act:** My beard grew a flower when the shadows came home. Look!

### Mister Quibble — Trader (`npc_a2_trader`)
*Quirk:* An owl-man who haggles in riddles.

- **Greeting:** Whooo's buying? What has pockets but no coat? My shop!
- **Bark:** What's cheaper than cheap? A good deal!
- **Bark:** I sell by day, I sell by night. Well. Mostly night.
- **Bark:** Riddle me this: what's worth more once you use it?
- **Bark:** Everything here is lightly loved.
- **Bark:** Hoo-hoo! Sharp eyes, fair prices.
- **Bark:** The answer to every riddle is 'buy one'. Just kidding.
- **After the act:** Whooo rekindled Mother Bark? You! That's not even a riddle.
- **Quests:** `q_a2_trader_riddle`

### Nutsy — Stash Keeper (`npc_a2_stash`)
*Quirk:* A squirrel who buries your stash. Finds it. Mostly.

- **Greeting:** Stash? STASH! Yes! I buried it! It's… somewhere! Good spot!
- **Bark:** I remember EVERY hiding place! …Most of them!
- **Bark:** Your stash is the same in every town. Magic! Or tunnels.
- **Bark:** I found an acorn from last year! Snack!
- **Bark:** Buried treasure is the best treasure!
- **Bark:** Don't worry. I've never lost anything. Recently.
- **Bark:** Chitter chitter! That means 'safe' in squirrel.
- **After the act:** I buried a present for you! Somewhere! It's a surprise for both of us!
- **Quests:** `q_a2_moss_hounds`

### Ferris Longstride — Stablemaster (`npc_a2_stablemaster`)
*Quirk:* Rents moss-deer. Whistles instead of saying yes.

- **Greeting:** *whistles* That means welcome. Want a deer?
- **Bark:** *whistles* That means yes.
- **Bark:** Moss-deer never trip on roots. Never.
- **Bark:** Get bumped and you'll hop down. Deer don't like fights.
- **Bark:** This one's Fern. That one's also Fern. They like it.
- **Bark:** Faster through the woods, faster through the town.
- **Bark:** *long whistle* That means 'have a good ride'.
- **After the act:** *happy whistle* That means 'thank you', by the way.

### Juniper Fitch — Pet Keeper (`npc_a2_petkeeper`)
*Quirk:* Raises owlets. Answers in hoots when distracted.

- **Greeting:** Hello! Shh. Owlet nap time. Hoo. Sorry. Hello.
- **Bark:** Owlets sleep all day. Best job ever.
- **Bark:** Hoo? Oh, sorry. What did you ask?
- **Bark:** A pet finds shiny things you'd walk right past.
- **Bark:** Level up your pet by adventuring together.
- **Bark:** Wren from Lamplight Hollow writes me pet letters!
- **Bark:** This owlet is called Doughnut. Don't ask why. She knows why.
- **After the act:** The owlets can see their shadows again. They keep jumping at them.
- **Quests:** `q_a2_owlcrows`

### Bramble Hartwell — Innkeeper (`npc_a2_innkeeper`)
*Quirk:* Runs The Hollow Knot. Every bed is a hammock.

- **Greeting:** Welcome to The Hollow Knot! Beds are hammocks. Don't fall out.
- **Bark:** All our beds rock. Literally.
- **Bark:** Bind your Homeward Wick here and you'll always get home.
- **Bark:** Nap in a hammock and the forest sings you to sleep.
- **Bark:** A rest is not a stop. It's a refill.
- **Bark:** Tea? It's acorn tea. It's a bit crunchy.
- **Bark:** Nobody's fallen out of a hammock this week. Big week.
- **After the act:** Whole forest's sleeping better since you came. Me too.

### Ranger Sorrel Vane — Ranger (`npc_a2_questgiver`)
*Quirk:* Jumps at every whisper. Brave anyway.

- **Greeting:** AH! Oh. It's you. Sorry. The trees keep whispering.
- **Bark:** Did you hear that? That was a whisper. Probably about me.
- **Bark:** Brave doesn't mean not scared. I'm very brave.
- **Bark:** The Owlcrows see everything. Even when you sneak.
- **Bark:** The shadows are missing. Look at your feet in the woods.
- **Bark:** Twiglings pretend to be sticks. Poke every stick.
- **Bark:** When it gets too much, take a break. I do. Often.
- **After the act:** The trees whispered 'thank you' today. I only jumped a little.
- **Quests:** `q_a2_twiglings`, `q_a2_mother_bark`

### Old Hoot — Storyteller (`npc_a2_storyteller`)
*Quirk:* Very, very old owl. Answers questions with questions.

- **Greeting:** Who comes to Old Hoot? And why? And who's asking?
- **Bark:** What is a shadow, if not light's best friend?
- **Bark:** Did you know my apprentice pulls stars from the sky? Did I teach her that?
- **Bark:** Why do trees whisper? What would you say, if you were a tree?
- **Bark:** Who blew out the Lantern? Why would anyone?
- **Bark:** Is the dark empty, or just waiting?
- **Bark:** What's heavier: a lantern, or carrying it alone?
- **After the act:** Who rekindled the oldest tree? And who will tell the story? Hm?
- **Quests:** `q_a2_owl_towers`

### Lumen the Glowworm — Waypoint Keeper (`npc_a2_waypoint`)
*Quirk:* A big glowworm. Speaks in rhymes.

- **Greeting:** Hello, hello, a traveller's here! Pick a place, and I'll steer.
- **Bark:** Touch a stone, it's yours to keep. Travel there before you sleep!
- **Bark:** To town is free, the rest a coin. Where would you like to join?
- **Bark:** I glow, I glow, from tail to head. The map is where you go instead.
- **Bark:** Waypoints shine like little stars. Near or far, the path is ours.
- **Bark:** Lost in the wood? Don't make a fuss. Come back here and ride with us.
- **Bark:** A rhyme a day keeps the Hush away!
- **After the act:** The wood is bright, the shadows home. Now pick a place wherever you roam!

### Side quests — Act II — Whisperwood

| id | Name | Giver | Type | Target × count |
|---|---|---|---|---|
| `q_a2_twiglings` | Poke Every Stick | `npc_a2_questgiver` | kill | `twigling` × 12 |
| `q_a2_spores` | A Little Evening | `npc_a2_alchemist` | collect | `dusk_essence` × 3 |
| `q_a2_owl_towers` | The Tower Question | `npc_a2_storyteller` | explore | `a2_z3` × 1 |
| `q_a2_owlcrows` | Hoo's Grumpy | `npc_a2_petkeeper` | kill | `owlcrow` × 8 |
| `q_a2_moss_hounds` | Dig Dog Trouble | `npc_a2_stash` | kill | `moss_hound` × 6 |
| `q_a2_trader_riddle` | A Riddle for Hob | `npc_a2_trader` | talk | `npc_a2_runecarver` × 1 |
| `q_a2_gossip` | Hush, Birches | `npc_a2_smith` | explore | `a2_z1` × 1 |
| `q_a2_mother_bark` | The Shadow Pantry | `npc_a2_questgiver` | boss | `mother_bark` × 1 |

**Poke Every Stick** (`q_a2_twiglings`)
- *Offer:* Twiglings pretend to be sticks, then jump out. Rekindle 12 before I jump out of my boots.
- *Done:* Twelve sticks, twelve thank-yous. Only jumped nine times!

**A Little Evening** (`q_a2_spores`)
- *Offer:* I need 3 Dusk Essence for a new elixir. Bottled evening. Smells like cocoa. *puff*
- *Done:* Marvellous! This elixir will be ever so glowy. *happy puff*

**The Tower Question** (`q_a2_owl_towers`)
- *Offer:* What's at the top of the Owl Towers? Why don't you go and see? And who'll tell me after?
- *Done:* You went. You saw. And now — what will you ask next?

**Hoo's Grumpy** (`q_a2_owlcrows`)
- *Offer:* The Snuffed Owlcrows scare my owlets. Rekindle 8? They'll be nicer after. Promise. Hoo.
- *Done:* The owlets are napping again. Hoo. Thank you. Hoo.

**Dig Dog Trouble** (`q_a2_moss_hounds`)
- *Offer:* Moss Hounds keep digging up my buried stashes! Six of them! Help!
- *Done:* Stashes safe! I buried a snack for you. Somewhere!

**A Riddle for Hob** (`q_a2_trader_riddle`)
- *Offer:* Riddle: what's green, grows on a face, and owes me money? Go ask Hob. Hoo-hoo!
- *Done:* He paid in acorns! Carved acorns! What a fine deal.

**Hush, Birches** (`q_a2_gossip`)
- *Offer:* The Gossiping Birches keep telling rumours about my axe. Walk through and shine your light?
- *Done:* Quiet at last. They only said one mean thing. Sorry, trees.

**The Shadow Pantry** (`q_a2_mother_bark`)
- *Offer:* Nobody in Whisperwood has a shadow. They're all in jars at Mother Bark's Pantry. Go gently.
- *Done:* My shadow came home! It's shy. It's hiding behind me. Thank you.

## Act III — Echo Mines · Clinkerton (`a3_town`)

### Dorra Anvilsong — Smith (`npc_a3_smith`)
*Quirk:* Sings to the anvil. Bellstriker's aunt. Very loud.

- **Greeting:** WELCOME TO THE FORGE! SORRY! IT'S A LOUD FORGE!
- **Bark:** CLANG! That's the chorus.
- **Bark:** My nephew's got a bell for a hammer. Runs in the family!
- **Bark:** SING while you hammer and the metal sits up straight!
- **Bark:** Upgrades never fail here. Loud AND reliable.
- **Bark:** Mines are quiet now. Too quiet. Needs more CLANG.
- **Bark:** If you see my nephew, tell him to wear a scarf.
- **After the act:** THE MOUNTAIN'S SINGING AGAIN! I'M CRYING! IT'S LOUD CRYING!
- **Quests:** `q_a3_crystal_spiders`

### Fizzwick Drabb — Alchemist (`npc_a3_alchemist`)
*Quirk:* Blows things up slightly. Eyebrows always regrowing.

- **Greeting:** Welcome! Don't mind the smoke. Or the eyebrows. They're coming back.
- **Bark:** Pop! That was supposed to happen. Mostly.
- **Bark:** Salt makes everything better. Even potions. Especially potions.
- **Bark:** Professor Puffcap taught me. He still sends me spore letters.
- **Bark:** Safety goggles! I should wear those.
- **Bark:** My eyebrows grow back faster every time. Science!
- **Bark:** This one's a transmute. Tiny stuff into better stuff.
- **After the act:** The Echo sang so loud my potion popped. Worth it.
- **Quests:** `q_a3_salt`

### Opaline Facet — Jeweler (`npc_a3_jeweler`)
*Quirk:* Polishes everything, including you.

- **Greeting:** Oh, you're a bit dusty. Hold still. *polish polish* There.
- **Bark:** Every gem was once a bit of mountain dreaming.
- **Bark:** Sockets, gems, rings, amulets. I do all of it. Shinily.
- **Bark:** Let me show you the station. One gem, one socket, one smile.
- **Bark:** Crystal Spiders are made of gems. Don't polish them.
- **Bark:** Dust is just shine that's shy.
- **Bark:** *polish* Sorry. Habit. Your elbow was dull.
- **After the act:** The whole mountain is sparkling. I don't even need to polish. I will anyway.

### Chisel — Runecarver (`npc_a3_runecarver`)
*Quirk:* A small stone-golem child. Speaks one word at a time.

- **Greeting:** Hello. Rune. Please.
- **Bark:** Carve. Tap. Glow.
- **Bark:** Stone. Friend.
- **Bark:** Rune. Strong.
- **Bark:** Me. Small. Rock. Big.
- **Bark:** Quillon. Ice. Teacher. Far.
- **Bark:** You. Nice.
- **After the act:** Mountain. Song. Happy. Me. Happy.

### Gus Two-Carts — Trader (`npc_a3_trader`)
*Quirk:* One cart sells. The other 'buys back'.

- **Greeting:** Left cart buys, right cart sells. Or the other way. Let's find out!
- **Bark:** Two carts, twice the bargains!
- **Bark:** Found it in the mines! It's basically new. Basically.
- **Bark:** If one cart rolls away, the prices roll with it.
- **Bark:** Sell me what you don't need. I'll find it a good home.
- **Bark:** Best prices under the mountain! Only prices under the mountain!
- **Bark:** Ever seen a cart with teeth? Don't buy that one.
- **After the act:** I'm naming a third cart after you. I just need a third cart.

### Pickett — Stash Keeper (`npc_a3_stash`)
*Quirk:* Keeps stashes in mine carts. One rolls away daily. It comes back.

- **Greeting:** Stash cart's ready! Wait. Where's cart six? Oh, there it goes.
- **Bark:** Don't worry. The carts always come back. The track's a circle.
- **Bark:** Your stash is safe in every town. Even on wheels.
- **Bark:** Cart six is the adventurous one.
- **Bark:** I oil the wheels every morning. Squeak-free stashing!
- **Bark:** Everything you put in, stays in. Rails' honour.
- **Bark:** Here comes cart six! Told you.
- **After the act:** Cart six came back with a crystal in it. I think it's for you.
- **Quests:** `q_a3_cart_mimic`

### Mags Rattlebridle — Stablemaster (`npc_a3_stablemaster`)
*Quirk:* Rents rock-ponies. Knows the shortest way to everything.

- **Greeting:** Need to get somewhere? I know a shortcut. I always know a shortcut.
- **Bark:** Rock-ponies never get tired. They get sleepy. It's different.
- **Bark:** Shortest way to the lift? Left, left, down, whee.
- **Bark:** Get bonked and you're off the pony. Rules of the rocks.
- **Bark:** This is Gravel. That's Pebble. That's Other Gravel.
- **Bark:** Riding's faster. Walking's scenic. Your choice.
- **Bark:** Shortcut to happiness? Pat a pony.
- **After the act:** The shortest way to a hero's heart is a pony ride. Free one, for you.

### Tuppence — Pet Keeper (`npc_a3_petkeeper`)
*Quirk:* Tiny and fearless. Best friends with a glow-mole.

- **Greeting:** This is Dimple. She's a glow-mole. She likes you. I can tell.
- **Bark:** Dimple digs up treasure! Some pets do that!
- **Bark:** I'm not scared of anything. Except baths.
- **Bark:** Pets help find materials. Dimple found a whole sandwich.
- **Bark:** Echo bats make great pets. They copy your giggles.
- **Bark:** Pets get better the more you explore together.
- **Bark:** Dimple says hi. That was the hi. The wiggle.
- **After the act:** Dimple did a happy dig. It's a tunnel. It spells your name. Nearly.
- **Quests:** `q_a3_lamp_ghosts`

### Barnaby Ballast — Innkeeper (`npc_a3_innkeeper`)
*Quirk:* Runs The Deep Breath. Laughs so loud the lift shakes.

- **Greeting:** Welcome to The Deep Breath! HA HA! Sorry. Lift's fine. Probably.
- **Bark:** We pump fresh air all the way down! Breathe deep!
- **Bark:** Bind your Homeward Wick here. HA! Home is where the laugh is!
- **Bark:** Rest up. A tired miner digs holes in the wrong places.
- **Bark:** My laugh broke a crystal once. Now it's two crystals. Bonus!
- **Bark:** Stew's got salt. Everything's got salt. It's a salt mine.
- **Bark:** Stay as long as you like, friend.
- **After the act:** HA HA HA! Sorry, happy laugh. The lift will stop shaking soon.

### Foreman Hilda Pickwell — Foreman (`npc_a3_questgiver`)
*Quirk:* Has a list of why they dig. The list is blank.

- **Greeting:** Wickbearer. Good. I have a list of jobs. And a list of reasons. One's blank.
- **Bark:** Why do we dig? It's on my list. The list is blank.
- **Bark:** Diglings were my crew. They're not bad. They forgot.
- **Bark:** Lamp ghosts wander the tunnels looking for their miners.
- **Bark:** Keep your light up in the shafts. It's dark down there.
- **Bark:** When your pack's full, come up. The mine's not going anywhere.
- **Bark:** There used to be a song. I can almost hear it.
- **After the act:** 'Dig deep, dig bright.' That's it. That's why. I'm writing it down.
- **Quests:** `q_a3_diglings`, `q_a3_great_echo`

### Echo Annie — Storyteller (`npc_a3_storyteller`)
*Quirk:* Repeats the last word of every sentence. Sentence.

- **Greeting:** Sit down, dearie, and I'll tell you a story. Story.
- **Bark:** The mountain used to sing to us. Us.
- **Bark:** Every tunnel holds a memory. Memory.
- **Bark:** When the lamps went out, the song went too. Too.
- **Bark:** The Great Echo copies everything. Everything.
- **Bark:** I've always done this. Nobody knows why. Why.
- **Bark:** A quiet mountain is a lonely mountain. Mountain.
- **After the act:** The song's back, dearie. The song. Song. Oh, I'm so happy. Happy.
- **Quests:** `q_a3_annie_song`

### Lou Lever — Waypoint Keeper (`npc_a3_waypoint`)
*Quirk:* Runs the great lift. Announces every floor, even when there aren't any.

- **Greeting:** Going up! Going down! Going sideways, if you like the map!
- **Bark:** Floor one: waypoints. Floor two: also waypoints.
- **Bark:** Mind the gap. There's no gap. Mind it anyway.
- **Bark:** Town trips are free. Other stops cost a coin.
- **Bark:** Ding! That's my lift bell. Not your nephew, Dorra.
- **Bark:** Next stop: wherever you tap.
- **Bark:** Doors closing! There are no doors.
- **After the act:** Going up! All the way up! Well done, Wickbearer!
- **Quests:** `q_a3_saltwhistle`

### Side quests — Act III — Echo Mines

| id | Name | Giver | Type | Target × count |
|---|---|---|---|---|
| `q_a3_diglings` | The Forgetful Crew | `npc_a3_questgiver` | kill | `digling` × 15 |
| `q_a3_crystal_spiders` | SPIDERS! | `npc_a3_smith` | kill | `crystal_spider` × 8 |
| `q_a3_salt` | Wick Required | `npc_a3_alchemist` | collect | `wickthread` × 5 |
| `q_a3_cart_mimic` | That's Not Cart Six | `npc_a3_stash` | kill | `cart_mimic` × 1 |
| `q_a3_annie_song` | The First Line | `npc_a3_storyteller` | talk | `npc_a3_innkeeper` × 1 |
| `q_a3_saltwhistle` | Floor Unknown | `npc_a3_waypoint` | explore | `a3_z1` × 1 |
| `q_a3_lamp_ghosts` | Lost Lamps | `npc_a3_petkeeper` | kill | `lamp_ghost` × 6 |
| `q_a3_great_echo` | The Mountain's Voice | `npc_a3_questgiver` | boss | `great_echo` × 1 |

**The Forgetful Crew** (`q_a3_diglings`)
- *Offer:* My crew became Diglings. Rekindle 15 and maybe they'll remember why we dig.
- *Done:* They're back! They still don't know why. But they know they're friends.

**SPIDERS!** (`q_a3_crystal_spiders`)
- *Offer:* CRYSTAL SPIDERS IN THE GALLERY! My nephew won't go near them. Rekindle 8? THANK YOU!
- *Done:* No more clinking in the dark! My nephew says thank you from under the bed.

**Wick Required** (`q_a3_salt`)
- *Offer:* I need 5 Wickthread for a fuse. A safe fuse! A mostly safe fuse!
- *Done:* It fizzled perfectly. Eyebrows intact. A good day!

**That's Not Cart Six** (`q_a3_cart_mimic`)
- *Offer:* Cart six came back with TEETH. That's not cart six! Find the real one on the Rattletrack Rails?
- *Done:* The real cart six! And the toothy one ran home. Everyone's happy.

**The First Line** (`q_a3_annie_song`)
- *Offer:* Barnaby used to hum the old song. Ask him if he remembers a line. Line.
- *Done:* 'Dig deep.' Two words. Two whole words! Words.

**Floor Unknown** (`q_a3_saltwhistle`)
- *Offer:* The Saltwhistle Shafts aren't on my lift list. Go explore and I'll add a floor!
- *Done:* New floor! Floor Saltwhistle! Ding! Everybody out!

**Lost Lamps** (`q_a3_lamp_ghosts`)
- *Offer:* Lamp ghosts are looking for their miners. Rekindle 6 so they can find their way home?
- *Done:* Dimple saw them float up the shaft, all glowy. She did a happy wiggle.

**The Mountain's Voice** (`q_a3_great_echo`)
- *Offer:* The Mouth of the Mountain copies everything, backwards. Go and give it something good to repeat.
- *Done:* It's singing. The whole mountain. 'Dig deep, dig bright.' I remember now.

## Act IV — Rimehall · Kettlekeep (`a4_town`)

### Corporal Tinwhistle — Smith (`npc_a4_smith`)
*Quirk:* A retired tin soldier. Salutes everything, including the anvil.

- **Greeting:** Attention! *salute* A visitor! *salute* To the anvil! *salute*
- **Bark:** *salute* That was for the hammer.
- **Bark:** Polished boots, polished blade, polished upgrade!
- **Bark:** I was a soldier once. Now I'm a smith. Still saluting.
- **Bark:** Upgrades succeed on first try. That is an order!
- **Bark:** My old regiment froze in the hall. I'll wait for them.
- **Bark:** Left, right, left, CLANG.
- **After the act:** My regiment thawed! They saluted me! I saluted back! We're still going!
- **Quests:** `q_a4_tin_soldiers`

### Cook Dumplina — Alchemist (`npc_a4_alchemist`)
*Quirk:* The castle cook. All her potions are soups.

- **Greeting:** Hungry? Hurt? Same thing, pet. Have a soup.
- **Bark:** Healing soup. Strength soup. Soup soup.
- **Bark:** Every potion's a soup if you believe.
- **Bark:** Mother Mabble in Wickmire? My cousin! Soup runs in families.
- **Bark:** Don't drink it too hot. Or do. It's a warming soup.
- **Bark:** The frozen guests haven't eaten in a year. I've kept the pot on.
- **Bark:** Carrots help you see in the dark. Very useful now.
- **After the act:** Everyone's thawed and everyone's HUNGRY. Pass the big ladle!
- **Quests:** `q_a4_soup`

### Lady Facetta Frostglass — Jeweler (`npc_a4_jeweler`)
*Quirk:* Keeper of the crown jewels. Extremely proper. Secretly giggly.

- **Greeting:** Good evening. One does jewels here. Properly. *tiny giggle*
- **Bark:** A lady never giggles. *giggle* Oh dear.
- **Bark:** The crown jewels are frozen. I polish them anyway.
- **Bark:** Frost Sapphire. Terribly elegant. Terribly cold.
- **Bark:** Please do not lick the ice. One has seen it happen.
- **Bark:** A ring for the brave, a gem for the kind.
- **Bark:** One's cousin Glimmerwick has too many rings. One has just enough.
- **After the act:** The King said my name! He remembered my name! *giggle giggle*

### Master Quillon Rimecarve — Runecarver (`npc_a4_runecarver`)
*Quirk:* Carves runes in ice. Hates warmth. Lives in a kitchen.

- **Greeting:** Close the door. Warmth is getting in. Ugh. Kitchens.
- **Bark:** Ice holds a rune perfectly. Until it melts. Hence: no kettles.
- **Bark:** Enchant, reroll, refine. Precision is kindness.
- **Bark:** Let me show you the station. One rune. Clean lines.
- **Bark:** Chisel sends me letters. One word each. I treasure them.
- **Bark:** Knurl carves spoons. I carve spoons too. In ice. Better spoons.
- **Bark:** Someone put the kettle on again. *sigh*
- **After the act:** The castle is warm again. I hate it. I'm very happy. Both.

### Crumbsworth — Trader (`npc_a4_trader`)
*Quirk:* A mouse merchant who runs his shop from a teacup.

- **Greeting:** Welcome to Crumbsworth's Teacup Emporium! Mind the handle.
- **Bark:** Small shop. Big deals.
- **Bark:** I accept gold, crumbs, and particularly good cheese.
- **Bark:** Everything here fits in a teacup. Except that sword. Somehow.
- **Bark:** The mirror butlers kept trying to serve my shop.
- **Bark:** Sell anything! I'll squeeze it in. Squeak.
- **Bark:** Crumbsworth's rule: never trade with a cat.
- **After the act:** In honour of the King, cheese is half price! Wait, I sell cheese?

### Mister Ledger — Stash Keeper (`npc_a4_stash`)
*Quirk:* The only butler who didn't freeze. Writes everything down.

- **Greeting:** Good evening. Your belongings are catalogued. Page nine thousand.
- **Bark:** Item received. Item noted. Item cherished.
- **Bark:** I did not freeze because I was busy writing. Recommend it.
- **Bark:** Your stash is shared in every town. I have the records.
- **Bark:** One sock, blue, slightly heroic. Noted.
- **Bark:** The mirror butlers were my colleagues. They serve tea wrongly now.
- **Bark:** Everything in order. As always.
- **After the act:** Entry: the King remembers. Underlined twice.
- **Quests:** `q_a4_mirror_tea`

### Noll Frostmane — Stablemaster (`npc_a4_stablemaster`)
*Quirk:* Rents snow-hares and sleds. Tells you to wrap up warm.

- **Greeting:** Wrap up warm! Then pick a hare. Then wrap up warmer.
- **Bark:** Snow-hares hop over drifts. Boots don't.
- **Bark:** Scarf? Scarf. Put on a scarf.
- **Bark:** Take a bump and you'll tumble off. Hares are gentle souls.
- **Bark:** This one's Flurry. That's Sleet. That's Mister Fluffington.
- **Bark:** Faster in the gardens, faster in the halls.
- **Bark:** Did you wrap up warm? Just checking.
- **After the act:** It's warm now! …Wrap up anyway. Habit.
- **Quests:** `q_a4_gardens`

### Princess Pip — Pet Keeper (`npc_a4_petkeeper`)
*Quirk:* The king's daughter, 8. Bossy, kind, misses her dad.

- **Greeting:** I'm Princess Pip and I'm in charge of the royal pets. Bow. Or wave. Waving's fine.
- **Bark:** The royal corgi-hare is called Sir Wobble. Salute him.
- **Bark:** Pets need love, snacks, and adventures. In that order.
- **Bark:** Kit taught me to climb roofs. Don't tell Nan Kettleby.
- **Bark:** My dad forgot my name. I'll help him remember.
- **Bark:** A pet can find treasure you'd never see.
- **Bark:** I'm not sad. I'm just busy being brave.
- **After the act:** He remembered me first. Before anyone. Before his own crown.
- **Quests:** `q_a4_porcelain`

### Nan Kettleby — Innkeeper (`npc_a4_innkeeper`)
*Quirk:* Keeps the great kettle boiling. Tea solves most things.

- **Greeting:** Kettle's on, dearie. It's always on. Sit by the warm.
- **Bark:** Tea for the cold, tea for the sad, tea for the tired.
- **Bark:** Bind your Homeward Wick here. The kettle will be on.
- **Bark:** A cup and a sit-down. Nothing's so bad after that.
- **Bark:** Rest is how heroes get heroic.
- **Bark:** Master Quillon hates my kettle. I make him tea anyway.
- **Bark:** That child Pip is climbing the roof again, isn't she.
- **After the act:** Kettle's never been so busy. Whole castle wants a cup. Bless you.

### Chancellor Pellinore Snowdrop — Chancellor (`npc_a4_questgiver`)
*Quirk:* Half his moustache is still frozen. Keeps lists of lists.

- **Greeting:** Ah. You're on my list. My list of people who might help. It's short.
- **Bark:** List of lists: item one, this list.
- **Bark:** Half my moustache thawed. The other half is thinking about it.
- **Bark:** His Majesty grows colder the less he remembers.
- **Bark:** Letters of his name are scattered in the halls. Find them.
- **Bark:** Mind the mirrors. Reflections here are running late.
- **Bark:** Do take breaks. It's on my list. Near the top.
- **After the act:** Item one: the King is himself again. Item two: I'm crying. Item three: tissues.
- **Quests:** `q_a4_letters`, `q_a4_the_king`

### Tumblewit the Jester — Storyteller (`npc_a4_storyteller`)
*Quirk:* Tells sad stories funnily and funny stories sadly.

- **Greeting:** A tale, a tale! Shall it be sad? It'll be funny. Or the other way.
- **Bark:** Once there was a king with the warmest hall. …That's the sad part.
- **Bark:** Why did the snowman cry? He was having a meltdown.
- **Bark:** Jingle jingle. My bells are frozen. So they just go 'jin'.
- **Bark:** The toast was never finished. That's the saddest joke I know.
- **Bark:** Laughing keeps you warm. Try it! Ha. See?
- **Bark:** Every king needs a fool. Every fool needs a friend.
- **After the act:** The toast got finished. I laughed so hard I cried. Or the other way.
- **Quests:** `q_a4_jester_joke`

### Tick — Waypoint Keeper (`npc_a4_waypoint`)
*Quirk:* A small clockwork girl. Ticks when she thinks.

- **Greeting:** Hello. Tick. Tick. Where would you like to go?
- **Bark:** Tick. Tick. Calculating route. Tick. Done.
- **Bark:** Waypoints remember you once you've touched them.
- **Bark:** Town is free. Other places: small fee. Tick.
- **Bark:** I was built to keep time. Now I keep places.
- **Bark:** Wind me up if I slow down. Please.
- **Bark:** Tick tock. That's my happy noise.
- **After the act:** Tick. Tick. Tick-tick-tick! That's my VERY happy noise.

### Side quests — Act IV — Rimehall

| id | Name | Giver | Type | Target × count |
|---|---|---|---|---|
| `q_a4_letters` | The King's Letters | `npc_a4_questgiver` | collect | `name_letter` × 4 |
| `q_a4_porcelain` | Who Moved? | `npc_a4_petkeeper` | kill | `porcelain_doll` × 10 |
| `q_a4_mirror_tea` | Tea Served Wrongly | `npc_a4_stash` | kill | `mirror_butler` × 6 |
| `q_a4_soup` | Stoking the Pot | `npc_a4_alchemist` | collect | `soot` × 20 |
| `q_a4_gardens` | Hare Run | `npc_a4_stablemaster` | explore | `a4_z1` × 1 |
| `q_a4_jester_joke` | A Joke for the Corporal | `npc_a4_storyteller` | talk | `npc_a4_smith` × 1 |
| `q_a4_tin_soldiers` | My Old Regiment | `npc_a4_smith` | kill | `tin_soldier` × 12 |
| `q_a4_the_king` | Who Are You? | `npc_a4_questgiver` | boss | `king_who_forgot` × 1 |

**The King's Letters** (`q_a4_letters`)
- *Offer:* The letters of His Majesty's name are scattered in the halls. Please find all 4. It's item one.
- *Done:* Four letters! A, L, D, R… the rest is up to you, I think.

**Who Moved?** (`q_a4_porcelain`)
- *Offer:* The porcelain dolls only move when you don't look. Rekindle 10! That's a royal order. Please.
- *Done:* Nobody moved! Except the right things! Sir Wobble says thank you.

**Tea Served Wrongly** (`q_a4_mirror_tea`)
- *Offer:* My old colleagues, the Mirror Butlers, serve trap tea now. Rekindle 6. Kindly.
- *Done:* Six butlers restored. One offered me proper tea. I wept. Discreetly.

**Stoking the Pot** (`q_a4_soup`)
- *Offer:* The big pot needs stoking. 20 Soot Dust keeps it bubbling for the thawing guests!
- *Done:* Bubbling beautifully! Have the first bowl, pet.

**Hare Run** (`q_a4_gardens`)
- *Offer:* Flurry wants to see the Frosted Gardens. Ride through? Wrap up warm first!
- *Done:* Flurry did twelve happy hops. Did you wrap up warm? Good.

**A Joke for the Corporal** (`q_a4_jester_joke`)
- *Offer:* The Corporal hasn't laughed since the freeze. Tell him my best joke: 'Why did the soldier salute the fridge?'
- *Done:* He laughed! Then saluted the laugh. That counts.

**My Old Regiment** (`q_a4_tin_soldiers`)
- *Offer:* My regiment froze on parade. Rekindle 12 tin soldiers and they'll march again! *salute*
- *Done:* They marched straight into the kitchen for soup. Good lads. *salute*

**Who Are You?** (`q_a4_the_king`)
- *Offer:* His Majesty sits in the Throne of Frost, forgetting. Remind him who he is.
- *Done:* '— and to all of you, who stayed.' He finished the toast. Item one: done.

## Act V — Well of Hush · Lastlight Landing (`a5_town`)

### Mae Coalbright — Smith (`npc_a5_smith`)
*Quirk:* Forged the Guild's lanterns for 70 years. Still 'just learning'.

- **Greeting:** Come in, come in. I'm still just learning, mind. Only seventy years.
- **Bark:** I made your lantern's great-great-grandmother.
- **Bark:** Upgrades never fail. After seventy years, I should hope not.
- **Bark:** Every lantern needs a good cap, a good glass and a good friend.
- **Bark:** Big Bran was my apprentice! He's still scared of moths.
- **Bark:** Out here, the only colour is the one we make.
- **Bark:** A good hammer is a patient hammer.
- **After the act:** The Lantern's lit. I made its cap, you know. Seventy years ago. Still holds.
- **Quests:** `q_a5_faded_knights`

### Mother Simmer — Cauldron Keeper (`npc_a5_alchemist`)
*Quirk:* Tends the Cauldron. Talks to it. It burbles back.

- **Greeting:** Hello, dearie. The Cauldron says hello too. *burble*
- **Bark:** Put anything in. See what comes out. The Cauldron never breaks a thing.
- **Bark:** *burble* She likes you. She only burbles twice for friends.
- **Bark:** Secret recipes are just surprises with instructions.
- **Bark:** Every discovery goes in your journal. Keep it handy.
- **Bark:** Let me show you. One little mix to start.
- **Bark:** Stir left for luck. Stir right for soup.
- **After the act:** The Cauldron burbled a whole song today. She's proud of you.
- **Quests:** `q_a5_essence`

### Twinkle — Jeweler (`npc_a5_jeweler`)
*Quirk:* A fallen star the size of a teacup. Very sensitive about it.

- **Greeting:** I'm a star! A real one! I'm just… compact.
- **Bark:** Don't call me small. Call me concentrated.
- **Bark:** I fell from the sky the night the Lantern went out.
- **Bark:** Gems are just stars that decided to stay.
- **Bark:** I can socket anything. With help. From a stool.
- **Bark:** Stargazers keep trying to throw me. Please don't.
- **Bark:** Big twinkle or small twinkle, still a twinkle.
- **After the act:** I can see the sky again! My family's up there! Hi, everyone!

### Vesper Inkwell — Runecarver (`npc_a5_runecarver`)
*Quirk:* Writes runes in light. They fade if you blink.

- **Greeting:** Don't blink. There. You blinked. Let me write it again.
- **Bark:** A rune of light lasts as long as someone reads it.
- **Bark:** Ink, light, patience.
- **Bark:** Quillon carves ice. I write light. We argue by letter.
- **Bark:** Every rune is a small promise.
- **Bark:** Read slowly. The words like it.
- **Bark:** *writes* *you blink* *sigh* Again.
- **After the act:** I wrote your name in light over the Landing. Nobody's blinked all day.

### Nib — Trader (`npc_a5_trader`)
*Quirk:* A reformed Magpie Imp. 'I don't steal. I borrow permanently.'

- **Greeting:** Shinies! Lovely shinies! All borrowed! Permanently! Legally!
- **Bark:** I used to be a Magpie Imp. Now I'm a magpie businessman.
- **Bark:** You caught my cousin in Wickmire. She says hi. Grumpily.
- **Bark:** Fair prices! Mostly fair! Fairly fair!
- **Bark:** Ooh, is that shiny? Can I— no. No. I'm reformed.
- **Bark:** The Hoard? Never heard of it. What Hoard.
- **Bark:** Sell me your shinies and I'll give them a good home.
- **After the act:** You relit the whole SKY? That's the shiniest thing anyone's ever done!
- **Quests:** `q_a5_leftovers`

### Keeper Stillwater — Stash Keeper (`npc_a5_stash`)
*Quirk:* Perfectly calm. Has never hurried. Not even once.

- **Greeting:** Welcome. Take your time. There is always time.
- **Bark:** Nothing here is in a hurry. Least of all me.
- **Bark:** Your stash is safe. Breathe in. Breathe out.
- **Bark:** Hurrying makes you drop things. So I never hurry.
- **Bark:** Everything you keep, I keep.
- **Bark:** The Hush is quiet. So am I. We're different, though.
- **Bark:** Rest is not wasted time.
- **After the act:** The Lantern's lit. I'm very happy. You can tell by my… calm.

### Captain Loft — Stablemaster (`npc_a5_stablemaster`)
*Quirk:* Rents great moths. Wears goggles indoors.

- **Greeting:** Goggles on! Moths ready! Captain Loft, at your service!
- **Bark:** Great moths fly toward light. That's you. Handy!
- **Bark:** Bump into trouble and you'll hop off. Moths hate fuss.
- **Bark:** Goggles indoors? Can't be too careful.
- **Bark:** This is Dusty. She's very soft and very fast.
- **Bark:** Faster on the islands. Faster through the Landing.
- **Bark:** Big Bran's scared of my moths. Tell him they're friendly!
- **After the act:** Moths everywhere tonight! Must be the brightest night in history!

### Tansy Glow — Pet Keeper (`npc_a5_petkeeper`)
*Quirk:* Keeps fireflies in jars and lets them out every night.

- **Greeting:** Hello! These are my fireflies. They're only visiting.
- **Bark:** Every night I open the jars. Every morning they come back.
- **Bark:** Pets are friends who choose to stay.
- **Bark:** Mystery eggs hatch into all sorts. Carry one around!
- **Bark:** A pet at full level is a proper best friend.
- **Bark:** Juniper sends me owl feathers. I send her fireflies.
- **Bark:** Light is better shared. Even firefly light.
- **After the act:** All my fireflies came back at once and spelled 'THANKS'. Mostly.

### Aunt Lumi — Innkeeper (`npc_a5_innkeeper`)
*Quirk:* Runs The Last Lamp. Leaves a light in every window.

- **Greeting:** Come in from the grey, love. There's a light in every window for you.
- **Bark:** A lit window means someone's waiting for you.
- **Bark:** Bind your Homeward Wick here. There'll always be a light on.
- **Bark:** The Well is cold. The Last Lamp isn't.
- **Bark:** Resting is part of carrying the light. Ada forgets that.
- **Bark:** Sit. Warm up. The Well will still be there.
- **Bark:** Nobody's too tired to be welcome.
- **After the act:** Every window in the world is lit tonight. I cried into the tea.
- **Quests:** `q_a5_ada_talk`

### Ada Brightly — Master Wickwright (`npc_a5_questgiver`)
*Quirk:* The last Guild master. Very old, very kind, very bad at rest.

- **Greeting:** A Wickbearer. At last. Sit, sit. I'll stand. I always stand.
- **Bark:** A light shared is not a light lost. That's the Guild's rule.
- **Bark:** I knew the Grey Guest once. Before he was grey.
- **Bark:** Ninety-nine chairs in our hall. Only one is ever sat in.
- **Bark:** Down is up in the Well. Walk carefully.
- **Bark:** I should rest more. Don't tell Aunt Lumi I said that.
- **Bark:** Carry the light. Share it when you can. Rest when you need to.
- **After the act:** Pell. Oh, Pell. I should have climbed the stair with you. …Thank you, Wickwright.
- **Quests:** `q_a5_hushlings`, `q_a5_grey_guest`

### The Moth Choir — Storyteller (`npc_a5_storyteller`)
*Quirk:* A thousand moths. They sing. You'll have to lean in.

- **Greeting:** *tiny chorus* Hellooo, little light! Lean in, lean in!
- **Bark:** *sing* Once was a spark that wandered alone…
- **Bark:** *sing* The Hush said nothing, and so it shone…
- **Bark:** *hum* Where moths gather, secrets hide.
- **Bark:** *sing* One keeper climbed, and nobody came…
- **Bark:** *giggle* You're very bright. We like bright.
- **Bark:** *sing* Carry the light, and then pass it on…
- **After the act:** *loudest tiny chorus ever* THE LANTERN! THE LANTERN! WE LOVE IT!
- **Quests:** `q_a5_grey_moths`

### Nobody — Waypoint Keeper (`npc_a5_waypoint`)
*Quirk:* A friendly Hushling: just a hat and a polite silence.

- **Greeting:** …  (Nobody tips its hat. The map glows.)
- **Bark:** …  (Nobody points at the map. Politely.)
- **Bark:** …  (Nobody waves. You think it's a wave.)
- **Bark:** …  (A tiny, happy silence.)
- **Bark:** …  (Nobody straightens its hat. It is very proud of the hat.)
- **Bark:** …  (Nobody seems to be saying: town trips are free.)
- **Bark:** …  (Somewhere, very quietly, a hum.)
- **After the act:** …!  (For the first time, Nobody makes a sound. It's a small 'yay'.)
- **Quests:** `q_a5_quiet_stair`

### Side quests — Act V — Well of Hush

| id | Name | Giver | Type | Target × count |
|---|---|---|---|---|
| `q_a5_hushlings` | Soft Shapes | `npc_a5_questgiver` | kill | `hushling` × 15 |
| `q_a5_grey_moths` | Grey Wings | `npc_a5_storyteller` | kill | `grey_moth` × 10 |
| `q_a5_leftovers` | The Shiniest Leftovers | `npc_a5_trader` | explore | `a5_z2` × 1 |
| `q_a5_essence` | Feed the Cauldron | `npc_a5_alchemist` | collect | `dusk_essence` × 6 |
| `q_a5_quiet_stair` | The Quiet Stair | `npc_a5_waypoint` | explore | `a5_z3` × 1 |
| `q_a5_ada_talk` | Make Her Sit | `npc_a5_innkeeper` | talk | `npc_a5_questgiver` × 1 |
| `q_a5_faded_knights` | Old Guild Guards | `npc_a5_smith` | kill | `faded_knight` × 6 |
| `q_a5_grey_guest` | The Lantern Room | `npc_a5_questgiver` | boss | `grey_guest` × 1 |

**Soft Shapes** (`q_a5_hushlings`)
- *Offer:* Hushlings drift over the Upside-Down Stars. Rekindle 15. Give them a bit of sound back.
- *Done:* Fifteen little hums. You can almost hear the Well breathing.

**Grey Wings** (`q_a5_grey_moths`)
- *Offer:* *sing* Some moths forgot their colours… Rekindle 10, little light, and bring them home!
- *Done:* *loud tiny cheer* Ten new voices in the Choir!

**The Shiniest Leftovers** (`q_a5_leftovers`)
- *Offer:* The Drift of Leftovers has bits of everywhere floating about. Go look! Not to borrow. Just look.
- *Done:* You didn't borrow anything? Not even a tiny thing? …Respect.

**Feed the Cauldron** (`q_a5_essence`)
- *Offer:* The Cauldron's peckish. 6 Dusk Essence, dearie? *burble*
- *Done:* *burble burble* That's a very happy burble.

**The Quiet Stair** (`q_a5_quiet_stair`)
- *Offer:* …  (Nobody points down the Quiet Stair. Then at you. Then tips its hat.)
- *Done:* …!  (Nobody does a tiny, silent dance.)

**Make Her Sit** (`q_a5_ada_talk`)
- *Offer:* Ada hasn't sat down in forty years. Go and ask her to sit. Just for a minute.
- *Done:* She sat! For a whole minute! Then stood up. It's a start, love.

**Old Guild Guards** (`q_a5_faded_knights`)
- *Offer:* Faded Knights were Guild guards once. Rekindle 6 and I'll make them new lanterns.
- *Done:* Six new lanterns, six old friends back. Still learning, me.

**The Lantern Room** (`q_a5_grey_guest`)
- *Offer:* He's up there. Down there. In the Lantern Room. Don't fight to win, Wickbearer. Share your light.
- *Done:* He's home. The Lantern's lit. And for once, nobody's carrying it alone.
