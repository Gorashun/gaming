# MAIN QUEST — Carry the Light

> Owner: game-writer. Data: `game/content/base/main_quest_text.json` (generated from the same source; the JSON wins if they drift).
> GDD v2.5 §31. Chapter ids `mq_a<act>_<nn>`; the Deepdark epilogue uses `mq_dd_<nn>`. Objective types: reach, rekindle, collect, escort, talk, solve, boss.
> Rewards (skill points etc.) are owned by systems design. Replays on higher tiers reuse the same text.

## The spine in one breath
A Wickbearer follows the Grey Guest's trail through five places he passed on his way home. At each one, someone *almost* helped him: Tolly was too busy, Mother Bark had no shadow to catch, the Echo only copied him, and King Aldric invited him in. In the Well of Hush, Ada confesses she never climbed the stair. The finale isn't a victory. It's an act of sharing. You light his lantern from yours, and every light you rekindled on the way shines up to relight the World-Lantern.

## Recurring threads
- **The grey figure** is glimpsed in every act (Glim's sighting, Tolly's story, the empty jar, the Echo's copy of his voice, the empty seat at the toast).
- **Pell's name** arrives in five journal scraps (`jr_pell_1..5`). The last one is collected in `mq_a5_04`.
- **The Answering Mailbox / the reflection that moves first** (`mq_a4_04`) pays off in `mq_dd_06`.
- **Every rekindled boss returns** in `mq_a5_06` to lend you its light, and again in the ending.
- **Rule three (rest when you need to)**: Ada can't sit, Mae can't stop, and Pell burned out. The ending gives everyone a chair.

## Twists (in order)
- `mq_a1_03`: First glimpse of the Grey Guest.
- `mq_a1_05`: The sleeping curse comes from the bell. The bell is worried, not wicked.
- `mq_a1_06`: The boss is someone the village loved.
- `mq_a1_08`: The Grey Guest wasn't attacking. He was asking for help.
- `mq_a2_01`: Your own shadow is gone the moment you enter Whisperwood.
- `mq_a2_03`: Mother Bark is protecting the shadows, not stealing them.
- `mq_a2_07`: The Grey Guest's own light is completely out — he is Snuffed too.
- `mq_a3_03`: Barnaby the innkeeper was a miner. He remembers a line.
- `mq_a3_04`: The monster was protecting someone smaller.
- `mq_a3_07`: The Grey Guest was the Lantern's keeper.
- `mq_a4_04`: Your reflection in the third mirror acts before you do — a hint of the Answering Mailbox mystery.
- `mq_a4_05`: The King was the only person who ever welcomed the Grey Guest.
- `mq_a5_02`: Not every Hushling is lost. Nobody wants to help.
- `mq_a5_04`: The Grey Guest is Pell, the last Lantern keeper. Ada could have helped him.
- `mq_a5_07`: You don't win by striking. The last prompt is 'Share your light.'
- `mq_a5_08`: The player is named Wickwright. Night returns — with a morning at the end of it.
- `mq_dd_06`: You lit your own wick, from another turn of the story.

## Act I — Wickmire

### 1. A Light in the Bog (`mq_a1_01`)
*You drift into Lamplight Hollow on a raft, your little lantern still burning.*

**Objectives**
- reach `a1_town`: Reach Lamplight Hollow
- talk `npc_a1_questgiver`: Talk to Warden Hollis

**Intro**
> **Warden Hollis:** A light! On a raft! Are you real?  
> **You:** I think so. Where am I?  
> **Warden Hollis:** Lamplight Hollow. What's left of it. Come in, quick — well, not quick. Come in.  

**Outro**
> **Warden Hollis:** Your wick is still burning. Nobody's is, any more.  
> **Warden Hollis:** You're a Wickbearer. We've been waiting for one.  
> **You:** What do I do?  
> **Warden Hollis:** Carry the light. Share it when you can. We'll start small.  

### 2. Bedtime for Bones (`mq_a1_02`)
*The Rattlebones have climbed out of the Drowned Graves. Send them home.*

**Objectives**
- reach `a1_z1`: Enter the Drowned Graves
- rekindle `rattler` ×8: Rekindle Rattlers
- collect `qi_floating_lamp` ×5: Catch floating lamps

**Intro**
> **Warden Hollis:** The graveyard slid into the bog. The bones woke up.  
> **Warden Hollis:** They're not wicked. Just lost. Your light will remind them.  
> **You:** And the floating lamps?  
> **Warden Hollis:** Grab any you see. We tie them down with string.  

**Outro**
> **Warden Hollis:** Five lamps! Mother Mabble will cry into the soup.  
> **Warden Hollis:** And the Rattlers went home to bed. Did you hear them say thank you?  
> **You:** Very quietly. Yes.  

### 3. Flicker's Cousin (`mq_a1_03`)
*A tiny wisp is lost in the graves. Bring her home safely.*

**Objectives**
- talk `npc_a1_waypoint`: Talk to Flicker
- escort `escort_wisp_glim`: Guide Glim the wisp home
- reach `a1_z2`: Reach Bellcrypt Halls

**Intro**
> **Flicker:** My cousin Glim went into the graves. I'm not worried! *flicker*  
> **Flicker:** Okay, I'm very worried.  
> **You:** I'll find her.  

**Outro**
> **Glim:** Thank you! It was so dark I forgot which way was up.  
> **Flicker:** You brought her back! I'll open the waypoint to the crypts for you.  
> **Flicker:** Oh, and— Glim said she saw a grey man in a grey hat. Just standing. Watching the bell tower.  

**Twist:** First glimpse of the Grey Guest.

### 4. Pocket Nineteen (`mq_a1_04`)
*A Magpie Imp stole the crypt key from Pocket Polly. Catch it!*

**Objectives**
- rekindle `magpie_imp`: Catch the Magpie Imp
- collect `qi_crypt_key`: Get the crypt key back

**Intro**
> **Pocket Polly:** Pocket nineteen! It had the crypt key! A Magpie Imp took it!  
> **Pocket Polly:** It's somewhere in Bellcrypt Halls. Giggling. They always giggle.  
> **You:** How do I catch it?  
> **Pocket Polly:** Be faster than it. Or smarter. Faster's easier.  

**Outro**
> **Pocket Polly:** The key! And a pile of gold! That imp was busy.  
> **Pocket Polly:** Keep the gold. The imp won't miss it. Much.  
> **Pocket Polly:** The key opens the Sunken Nave. That's where the bell sound comes from.  

### 5. The Yawning Nave (`mq_a1_05`)
*Villagers are asleep in the Sunken Nave. Wake them with the little bells.*

**Objectives**
- reach `a1_z3`: Enter the Sunken Nave
- solve `puzzle_a1_bell_ropes`: Ring the three hand-bells in order
- rekindle `warden`: Rekindle the Crypt Warden

**Intro**
> **Sleepy villager:** Zzz… come home… zzz…  
> **You:** They're all asleep. Standing up.  
> **Grandmother Purl:** (from far away) Little light! Ring the small bells: low, middle, high. That's the waking song.  

**Outro**
> **Sleepy villager:** Huh? Where's my hat? Where's my HOUSE?  
> **You:** Home is that way. Follow the lamps.  
> **Sleepy villager:** The big bell kept ringing. It sounded… so worried.  

**Twist:** The sleeping curse comes from the bell. The bell is worried, not wicked.

### 6. Who Rings the Bell? (`mq_a1_06`)
*Grandmother Purl knows that bell. She knows who rang it.*

**Objectives**
- talk `npc_a1_storyteller`: Ask Grandmother Purl
- collect `jr_bell_log`: Find Tolly's bell log
- talk `npc_a1_smith`: Get the belfry gate opened by Big Bran

**Intro**
> **Grandmother Purl:** That bell belongs to Tolly Clapperton. Sixty years he rang it.  
> **Grandmother Purl:** 'Come home, come home, the dark is coming.'  
> **You:** Where is he now?  
> **Grandmother Purl:** Nobody's seen him since the Lantern went out. Nobody's looked.  

**Outro**
> **Big Bran:** The belfry gate's rusted shut. Hammer Gerald can fix that.  
> **Big Bran:** CLANG. There. Oh no. Was that a moth?  
> **Grandmother Purl:** Be gentle with him, little light. He was only trying to call us home.  

**Twist:** The boss is someone the village loved.

### 7. Belfry of the Drowned (`mq_a1_07`)
*Climb the sunken tower. Stop the bell. Bring Tolly home.*

**Objectives**
- reach `a1_boss`: Climb the Belfry of the Drowned
- boss `sunken_bellringer`: Rekindle the Sunken Bellringer

**Intro**
> **The Sunken Bellringer:** DONG. Come home… come home…  
> **You:** Tolly! Everyone's home! You can stop!  
> **The Sunken Bellringer:** The dark is coming… DONG…  

**Outro**
> **Tolly:** Oh. Did everyone get home?  
> **You:** They did. You can rest now.  
> **Tolly:** Then one more ring. The good one.  
> **Tolly:** DING! Morning bell!  

### 8. The Morning Bell (`mq_a1_08`)
*The lamps drift down. Tolly has something to tell you.*

**Objectives**
- reach `a1_town`: Return to Lamplight Hollow
- talk `npc_a1_questgiver`: Talk to Warden Hollis

**Intro**
> **Warden Hollis:** The lamps came down on their own! Every one!  
> **Tolly:** And I'm ringing the town bell now. When you come home. Only then.  
> **You:** Tolly, what happened that night?  

**Outro**
> **Tolly:** A grey man knocked on my door. He asked to sit down. Just for a minute.  
> **Tolly:** I said I was busy. I had a bell to ring.  
> **Tolly:** He looked so tired. Then he walked into the woods.  
> **Warden Hollis:** Whisperwood. You'll follow him?  
> **You:** I'll follow him.  

**Twist:** The Grey Guest wasn't attacking. He was asking for help.

## Act II — Whisperwood

### 1. Rope Bridges (`mq_a2_01`)
*Owlstead hangs in the trees. Someone up there jumps at every whisper.*

**Objectives**
- reach `a2_town`: Reach Owlstead
- talk `npc_a2_questgiver`: Talk to Ranger Sorrel

**Intro**
> **Ranger Sorrel:** AH! Oh. A person. Sorry. The trees keep whispering.  
> **You:** What are they saying?  
> **Ranger Sorrel:** Rumours. About you, now. Something about your boots.  

**Outro**
> **Ranger Sorrel:** A grey man? Yes. He walked through a while ago.  
> **Ranger Sorrel:** He didn't have a shadow. Nobody here does, any more.  
> **You:** Look — neither do I.  

**Twist:** Your own shadow is gone the moment you enter Whisperwood.

### 2. What the Birches Say (`mq_a2_02`)
*The Gossiping Birches know where the shadows went. Only one of them tells the truth.*

**Objectives**
- reach `a2_z1`: Enter the Gossiping Birches
- rekindle `twigling` ×12: Rekindle Twiglings
- solve `puzzle_a2_honest_birch`: Find the honest birch

**Intro**
> **Birch:** Psst. The shadows went north.  
> **Other birch:** Don't listen. They went south.  
> **Third birch:** I'm the only one who never lies. Also, I love your boots.  

**Outro**
> **Honest birch:** Fine. Fine! Mother Bark took them. For safekeeping, she says.  
> **Honest birch:** And your boots are… okay.  
> **You:** Thanks. I think.  

### 3. Old Hoot's Questions (`mq_a2_03`)
*The oldest owl answers everything with a question. Somehow, that helps.*

**Objectives**
- talk `npc_a2_storyteller`: Visit Old Hoot
- collect `qi_shadow_moth` ×3: Catch shadow-moths for Old Hoot

**Intro**
> **Old Hoot:** Why would a tree take shadows? What is a shadow without light?  
> **You:** Nothing?  
> **Old Hoot:** Then what happens to shadows when the light goes out?  
> **You:** …They fade away. Oh.  

**Outro**
> **Old Hoot:** So is Mother Bark stealing? Or saving?  
> **You:** Saving. She's saving them.  
> **Old Hoot:** Who taught you to think like that? Was it me? Hoo.  

**Twist:** Mother Bark is protecting the shadows, not stealing them.

### 4. Doughnut Is Missing (`mq_a2_04`)
*Juniper's owlet flew into Puffcap Hollow. Owlets and spores do not mix.*

**Objectives**
- reach `a2_z2`: Enter Puffcap Hollow
- escort `escort_owlet_doughnut`: Guide Doughnut home
- talk `npc_a2_alchemist`: Ask Professor Puffcap about the spores

**Intro**
> **Juniper:** Doughnut flew off! Hoo! Sorry. She's only small.  
> **Juniper:** She'll follow a light. Please be her light.  

**Outro**
> **Juniper:** DOUGHNUT! Hoo hoo hoo! Sorry. Happy hoots.  
> **Professor Puffcap:** You walked through my Hollow and didn't sneeze once? Impressive. *puff*  
> **Professor Puffcap:** Come by the lab. I'll show you some alchemy. It helps with the Owl Towers.  

### 5. The Owl Towers (`mq_a2_05`)
*Owlcrows guard the way to the Pantry. They'll let you pass — if you answer their riddle.*

**Objectives**
- reach `a2_z3`: Climb the Owl Towers
- rekindle `owlcrow` ×10: Rekindle Owlcrows
- solve `puzzle_a2_owlcrow_riddle`: Answer the Owlcrow's riddle

**Intro**
> **Owlcrow:** Riddle! What gets bigger the more you take away?  
> **You:** Um.  
> **Owlcrow:** Take your time. We turn our heads all the way round while we wait.  

**Outro**
> **You:** A hole! The answer is a hole.  
> **Owlcrow:** Correct! You may pass. Also, we will be watching. We are always watching.  
> **Owlcrow:** (kindly) Go gently with the old tree.  

### 6. The Shadow Pantry (`mq_a2_06`)
*Thousands of jars. Thousands of shadows. One very old tree.*

**Objectives**
- reach `a2_boss`: Enter Mother Bark's Pantry
- boss `mother_bark`: Rekindle Mother Bark

**Intro**
> **Mother Bark:** Thief! Shadow-snatcher! You'll not have my little darks!  
> **You:** I don't want to take them. I want to take them home.  
> **Mother Bark:** Home? There IS no home for them! No light, no shadow!  

**Outro**
> **Mother Bark:** …Is that MY shadow? On the ground?  
> **You:** My light made it.  
> **Mother Bark:** Ha! Haha! Oh, it's been a year!  
> **Mother Bark:** Open the jars, little darks. Go home.  

### 7. The Empty Jar (`mq_a2_07`)
*Every jar is open. All but one — and that one was always empty.*

**Objectives**
- talk `mother_bark`: Talk to Mother Bark
- collect `qi_empty_jar`: Take the empty jar
- talk `npc_a2_questgiver`: Show Ranger Sorrel

**Intro**
> **Mother Bark:** There's one jar I never filled. See the label?  
> **You:** 'Shadow of a tall grey stranger.' It's empty.  
> **Mother Bark:** He had no shadow to catch. His light was all the way out. Inside.  

**Outro**
> **Mother Bark:** Here. An acorn, too. Plant it someday. Somebody in there needs a long nap.  
> **Ranger Sorrel:** He went under the mountain, the birds say. To the Echo Mines.  
> **Ranger Sorrel:** Wickbearer? Your shadow's back. It's following you. It likes you.  

**Twist:** The Grey Guest's own light is completely out — he is Snuffed too.

## Act III — Echo Mines

### 1. Going Down (`mq_a3_01`)
*Clinkerton sits on a giant lift. It creaks. Everything creaks.*

**Objectives**
- reach `a3_town`: Ride down to Clinkerton
- talk `npc_a3_waypoint`: Talk to Lou Lever
- talk `npc_a3_questgiver`: Report to Foreman Hilda

**Intro**
> **Lou Lever:** Going down! Floor one: Clinkerton! Floor two: also Clinkerton!  
> **Foreman Hilda:** A Wickbearer. Good. I have a list.  
> **You:** A list of what?  

**Outro**
> **Foreman Hilda:** Why we dig. It's blank. We forgot.  
> **Foreman Hilda:** My crew became Diglings. They dig and dig and don't know why.  
> **Foreman Hilda:** And the mountain… copies us. Wrong way round.  

### 2. Scraps of a Song (`mq_a3_02`)
*The Saltwhistle Shafts whistle a tune. Pieces of it are written on old helmets.*

**Objectives**
- reach `a3_z1`: Enter Saltwhistle Shafts
- rekindle `digling` ×15: Rekindle Diglings
- collect `qi_song_scrap` ×3: Find song scraps

**Intro**
> **Foreman Hilda:** There used to be a song. Every crew had it on their helmets.  
> **Foreman Hilda:** Find the helmets. Find the words.  

**Outro**
> **You:** 'Dig deep.' 'Bring the shine.' 'The mountain sings.'  
> **Foreman Hilda:** That's it! Some of it. It's in the wrong order, though.  
> **Echo Annie:** Order. Order.  

### 3. Lenny's Lamp (`mq_a3_03`)
*A lamp ghost floats through the Glittering Gallery, calling for his miner.*

**Objectives**
- reach `a3_z2`: Enter the Glittering Gallery
- rekindle `crystal_spider` ×10: Rekindle Crystal Spiders
- escort `escort_lamp_lenny`: Guide Lenny the lamp ghost

**Intro**
> **Lenny:** Have you seen my miner? Big boots. Bad jokes. I was his lamp.  
> **You:** We'll find him together.  
> **Lenny:** Mind the spiders. If the clinking stops, look up.  

**Outro**
> **Lenny:** BARNABY! It's me! Your lamp!  
> **Barnaby:** LENNY! HA HA HA! Sorry! Lift's fine!  
> **Barnaby:** I remember now. I used to sing while you glowed. Something about… digging bright?  

**Twist:** Barnaby the innkeeper was a miner. He remembers a line.

### 4. The Cart With Teeth (`mq_a3_04`)
*Something with teeth rattles on the Rattletrack Rails. It's guarding something.*

**Objectives**
- reach `a3_z3`: Enter Rattletrack Rails
- rekindle `cart_mimic`: Rekindle the toothy cart
- talk `npc_a3_stash`: Return cart six to Pickett

**Intro**
> **Pickett:** Cart six never came back. There's a cart with TEETH out there instead.  
> **You:** Maybe it ate cart six.  
> **Pickett:** Don't say that. Cart six is adventurous, not edible.  

**Outro**
> **You:** The toothy cart was guarding a little Digling. Asleep in cart six.  
> **Pickett:** Keeping him safe? Aw. Even the teeth were kind.  
> **Pickett:** Cart six, you hero.  

**Twist:** The monster was protecting someone smaller.

### 5. Dig Deep, Dig Bright (`mq_a3_05`)
*Put the song back together. The mountain is listening.*

**Objectives**
- talk `npc_a3_storyteller`: Ask Echo Annie
- solve `puzzle_a3_song_order`: Put the song lines in order
- talk `npc_a3_smith`: Let Dorra sing it

**Intro**
> **Echo Annie:** The song goes in a circle, dearie. Circle.  
> **Echo Annie:** Start deep. End singing. Singing.  

**Outro**
> **Dorra:** DIG DEEP, DIG BRIGHT, BRING THE SHINE TO LIGHT!  
> **Dorra:** DIG SLOW, DIG TRUE, THE MOUNTAIN SINGS FOR YOU!  
> **The mountain:** …THGIL OT ENIHS…  
> **You:** It's singing back. Backwards. It wants more.  

### 6. The Mouth of the Mountain (`mq_a3_06`)
*A cave so big it has weather. It copies everything. Give it something good to copy.*

**Objectives**
- reach `a3_boss`: Enter the Mouth of the Mountain
- boss `great_echo`: Rekindle the Great Echo

**Intro**
> **The Great Echo:** …OLLEH? OLLEH?  
> **You:** Hello!  
> **The Great Echo:** !OLLEH! !OLLEH!  

**Outro**
> **The miners:** Dig deep, dig bright…  
> **The Great Echo:** …BRING THE SHINE TO LIGHT.  
> **The Great Echo:** (softly) Thank you. It was so quiet. I copied anything.  
> **The Great Echo:** I even copied him. The grey one.  

### 7. What the Echo Heard (`mq_a3_07`)
*The mountain remembers everything it ever heard. Including the Grey Guest.*

**Objectives**
- talk `great_echo`: Listen to the Echo
- talk `npc_a3_jeweler`: Get the Echo Crystal set by Opaline

**Intro**
> **The Great Echo:** He walked through. He said one thing. I kept it.  
> **The Great Echo:** (in a grey, tired voice) 'I'm so tired. Nobody ever asks who keeps it lit.'  

**Outro**
> **Opaline:** The Echo gave you a crystal? Hold still. *polish* Now it'll keep his words safe.  
> **Foreman Hilda:** Keeps it lit? Keeps WHAT lit?  
> **You:** The Lantern. I think he was its keeper.  
> **Foreman Hilda:** The birds say he went to Rimehall. The frozen castle.  

**Twist:** The Grey Guest was the Lantern's keeper.

## Act IV — Rimehall

### 1. The Warm Kitchens (`mq_a4_01`)
*Rimehall is frozen. Only the kitchens are warm. Everyone who stayed lives there.*

**Objectives**
- reach `a4_town`: Reach Kettlekeep
- talk `npc_a4_innkeeper`: Warm up with Nan Kettleby
- talk `npc_a4_questgiver`: Meet Chancellor Snowdrop

**Intro**
> **Nan Kettleby:** In, in, in! Kettle's on. You're blue at the edges.  
> **Chancellor Snowdrop:** Ah. You're on my list. My list of people who might help. It's short.  

**Outro**
> **Chancellor Snowdrop:** His Majesty froze mid-toast. Then he forgot his name.  
> **Chancellor Snowdrop:** The less he remembers, the colder the castle gets.  
> **You:** Then we help him remember.  

### 2. A Princess With a Plan (`mq_a4_02`)
*The king's daughter has a plan. It involves a hare, a garden, and you.*

**Objectives**
- talk `npc_a4_petkeeper`: Talk to Princess Pip
- escort `escort_sir_wobble`: Guide Sir Wobble through the gardens

**Intro**
> **Princess Pip:** I'm Princess Pip. My dad is the king. He forgot my name.  
> **Princess Pip:** Sir Wobble can sniff out Dad's things. Take him to the gardens.  
> **Princess Pip:** That's a royal order. Please.  

**Outro**
> **Princess Pip:** Sir Wobble found something! A frozen letter. It says 'A'.  
> **Princess Pip:** It's from Dad's name. His name is on everything, and the frost broke it into bits.  
> **You:** Then we find all the bits.  

### 3. The Frosted Gardens (`mq_a4_03`)
*The hedges are shaped like animals. Some of them are animals.*

**Objectives**
- reach `a4_z1`: Enter the Frosted Gardens
- rekindle `snow_hound` ×10: Rekindle Snow Hounds
- collect `qi_name_letter_a`: Find the letter A

**Intro**
> **Chancellor Snowdrop:** The gardens were His Majesty's favourite. He named every hedge.  
> **You:** Did the hedges have names?  
> **Chancellor Snowdrop:** All of them were called 'Hedge'. He was very tired that day.  

**Outro**
> **Princess Pip:** A! Now we need the rest.  
> **Chancellor Snowdrop:** Mind the Looking-Glass Gallery next. The reflections run late.  

### 4. Mind the Third Mirror (`mq_a4_04`)
*A hall of mirrors. Your reflection is late. Except in one.*

**Objectives**
- reach `a4_z2`: Enter the Looking-Glass Gallery
- solve `puzzle_a4_third_mirror`: Find the mirror that's early
- rekindle `mirror_butler` ×6: Rekindle Mirror Butlers
- collect `qi_name_letter_l`: Find the letter L

**Intro**
> **Mirror Butler:** Tea, sir? Madam? Hero? The tea is a trap. I am so sorry.  
> **You:** Then why serve it?  
> **Mirror Butler:** I forgot how to stop.  

**Outro**
> **You:** In the third mirror, my reflection moved first. It pointed at the letter.  
> **You:** …It had a little lantern drawn on its hand.  
> **Mister Ledger:** Curious. Noted. Underlined.  

**Twist:** Your reflection in the third mirror acts before you do — a hint of the Answering Mailbox mystery.

### 5. The Everlasting Toast (`mq_a4_05`)
*Hundreds of frozen guests, cups raised. One chair is empty. It has a name card.*

**Objectives**
- reach `a4_z3`: Enter the Everlasting Toast
- rekindle `tin_soldier` ×12: Rekindle Tin Soldiers
- collect `qi_name_letter_d`: Find the letter D
- collect `qi_name_letter_r`: Find the letter R

**Intro**
> **Tumblewit:** Welcome to the longest party in history. Nobody's had cake in a year.  
> **Tumblewit:** That's the sad part. The funny part is also that.  

**Outro**
> **You:** There's an empty seat at the king's right hand.  
> **You:** The card says: 'Our Grey Guest.'  
> **Tumblewit:** He invited him in. The only one who ever did.  
> **Tumblewit:** …That's not a joke. I don't have a joke for that.  

**Twist:** The King was the only person who ever welcomed the Grey Guest.

### 6. Who Are You? (`mq_a4_06`)
*The Throne of Frost. A king who has forgotten everything, even himself.*

**Objectives**
- reach `a4_boss`: Enter the Throne of Frost
- boss `king_who_forgot`: Remind the King who he is

**Intro**
> **The King Who Forgot:** Who are you?  
> **You:** A Wickbearer. And you're—  
> **The King Who Forgot:** Who am I? No matter. Everyone must stay. Stay FROZEN.  

**Outro**
> **You:** A-L-D-R-I-C. Your name is Aldric.  
> **King Aldric:** Aldric. …Aldric Warmhearth.  
> **King Aldric:** (raising his cup) — and to all of you, who stayed!  
> **Princess Pip:** DAD!  
> **King Aldric:** Pip. Pip! I remember you first.  

### 7. To All of You, Who Stayed (`mq_a4_07`)
*The castle thaws. The king remembers his last guest.*

**Objectives**
- talk `king_who_forgot`: Talk to King Aldric
- talk `npc_a4_runecarver`: Have Master Quillon carve the Well-key

**Intro**
> **King Aldric:** He sat at my table, the grey fellow. Said, 'Thank you for asking me in.'  
> **King Aldric:** He said his name was… no. He wouldn't say it.  
> **King Aldric:** Then he said he was going home. Down. To the Well of Hush.  

**Outro**
> **Master Quillon:** A key for the Well. Carved in ice. Don't let it near the kettle.  
> **King Aldric:** If you find him, tell him there's still a seat. Always.  
> **You:** I'll tell him.  

## Act V — The Well of Hush

### 1. Lastlight Landing (`mq_a5_01`)
*A lighthouse on the rim of the world. The last hall of the Wickwright Guild.*

**Objectives**
- reach `a5_town`: Reach Lastlight Landing
- talk `npc_a5_innkeeper`: Warm up with Aunt Lumi
- talk `npc_a5_questgiver`: Meet Ada Brightly

**Intro**
> **Aunt Lumi:** Come in from the grey, love. There's a light in every window for you.  
> **Ada Brightly:** A Wickbearer. At last. Sit, sit. I'll stand. I always stand.  

**Outro**
> **Ada Brightly:** The Well of Hush is below us. Down there, down is up.  
> **Ada Brightly:** At the bottom is the sky. And the Lantern.  
> **You:** And the Grey Guest?  
> **Ada Brightly:** (quietly) Yes. Him too.  

### 2. Nobody Helps (`mq_a5_02`)
*The Upside-Down Stars. The Hushlings drift. One of them wears a hat.*

**Objectives**
- reach `a5_z1`: Walk the Upside-Down Stars
- rekindle `hushling` ×15: Rekindle Hushlings
- escort `escort_nobody`: Follow Nobody to the fallen lanterns

**Intro**
> **Nobody:** …  (A Hushling in a hat tips it at you.)  
> **You:** You're… not attacking?  
> **Nobody:** …  (It points. It wants you to follow.)  

**Outro**
> **Nobody:** …  (It shows you a pile of fallen lanterns. Dozens. All dark.)  
> **Ada Brightly:** (on the wind) The Guild's lanterns. Every keeper who gave up.  
> **Nobody:** …  (It picks one up. It gives it to you. It seems to be saying: not all of us are gone.)  

**Twist:** Not every Hushling is lost. Nobody wants to help.

### 3. The Drift of Leftovers (`mq_a5_03`)
*Islands made of everything the Hush took. Including colours.*

**Objectives**
- reach `a5_z2`: Cross the Drift of Leftovers
- collect `qi_lost_colour` ×5: Gather the lost colours
- rekindle `faded_knight` ×6: Rekindle Faded Knights

**Intro**
> **You:** A bog stair. A birch. A mine cart. A ballroom door.  
> **You:** It's all the places I've been. Grey.  
> **Nib:** (from the Landing, by glow-mail) Shinies! Colours are the best shinies! Bring them back!  

**Outro**
> **You:** Bog-green. Birch-violet. Crystal-white. Frost-blue. Lantern-gold.  
> **Mother Simmer:** Pop them in the Cauldron, dearie. *burble* She'll mix them into something warm.  
> **Mother Simmer:** There. A little lantern-oil. You'll need it at the top. Or the bottom.  

### 4. Ada's Confession (`mq_a5_04`)
*The Moth Choir sings a song the Guild never wanted sung.*

**Objectives**
- talk `npc_a5_storyteller`: Listen to the Moth Choir
- collect `jr_pell_5`: Find the last scrap of a name
- talk `npc_a5_questgiver`: Ask Ada the truth

**Intro**
> **The Moth Choir:** *sing* One keeper climbed, and nobody came…  
> **The Moth Choir:** *sing* Night after night, and always the same…  
> **The Moth Choir:** *sing* His name was Pell, and he trimmed the flame…  

**Outro**
> **Ada Brightly:** Pell and I were apprentices. Together.  
> **Ada Brightly:** When the others left, I said: I'll climb up and help you tomorrow.  
> **Ada Brightly:** For forty years, I said tomorrow.  
> **You:** He's not a monster, is he?  
> **Ada Brightly:** No. He's my friend. And he was so, so tired.  

**Twist:** The Grey Guest is Pell, the last Lantern keeper. Ada could have helped him.

### 5. The Quiet Stair (`mq_a5_05`)
*A spiral stair down to the sky. No sound at all. Your footsteps glow instead.*

**Objectives**
- reach `a5_z3`: Descend the Quiet Stair
- rekindle `sound_eater` ×8: Rekindle Sound Eaters
- solve `puzzle_a5_silent_steps`: Follow your glowing footsteps

**Intro**
> **You:** …  
> **You:** (Nothing. Not even your own voice.)  
> **You:** (But each step leaves a little light behind.)  

**Outro**
> **You:** (At the bottom, a sound: a small, tired breath.)  
> **You:** (Somebody is up there. Down there. Waiting.)  

### 6. Every Light You Lit (`mq_a5_06`)
*Before the last door, the friends you rekindled send you their light.*

**Objectives**
- talk `sunken_bellringer`: Hear Tolly's bell
- talk `mother_bark`: Take Mother Bark's shadow-lantern
- talk `great_echo`: Hear the mountain's song
- talk `king_who_forgot`: Accept King Aldric's toast

**Intro**
> **Tolly:** (a bell, from very far away) DING! Come home, Wickbearer. When you're done.  
> **Mother Bark:** Take a shadow with you, little light. Shadows mean there's light.  
> **The Great Echo:** DIG DEEP. DIG BRIGHT.  
> **King Aldric:** To you, Wickbearer. And to him. There's still a seat.  

**Outro**
> **You:** Four small lights. Bell, bark, song, toast.  
> **Ada Brightly:** (on the wind) A light shared is not a light lost, Wickbearer.  
> **You:** I know. I think I finally know.  

### 7. The Lantern Room (`mq_a5_07`)
*Inside the dark World-Lantern. A small grey figure sits by the cold wick.*

**Objectives**
- reach `a5_boss`: Enter the Lantern Room
- boss `grey_guest`: Share your light with the Grey Guest

**Intro**
> **The Grey Guest:** You came all this way.  
> **The Grey Guest:** Please. Just let it stay dark.  
> **The Grey Guest:** Then nobody has to carry it.  
> **You:** Nobody has to carry it alone.  

**Outro**
> **You:** (You hold out your lantern. He holds out his. Small. Old. Cold.)  
> **You:** (The flame jumps across.)  
> **Pell:** …Oh. It's warm.  
> **Pell:** You carried it. I thought no one would.  
> **You:** Pell. Your name is Pell.  

**Twist:** You don't win by striking. The last prompt is 'Share your light.'

### 8. Carry the Light (`mq_a5_08`)
*The World-Lantern is lit — by every light you rekindled, shining up together.*

**Objectives**
- talk `grey_guest`: Sit with Pell
- reach `a5_town`: Return to Lastlight Landing
- talk `npc_a5_questgiver`: Talk to Ada

**Intro**
> **Pell:** Look. Down there. Up there. All those little lights.  
> **Pell:** Tolly's bell. The shadows. The miners. Aldric's hall.  
> **Pell:** They're all shining up. At the Lantern. Together.  
> **You:** It's lit.  

**Outro**
> **Ada Brightly:** Pell.  
> **Pell:** Ada. You came up the stair.  
> **Ada Brightly:** I'm forty years late.  
> **Pell:** You're here. That's what counts.  
> **Ada Brightly:** (to you) Kneel? No, don't. Just stand there. Wickwright.  
> **Aunt Lumi:** And then everyone rests. That's an order. Kettle's on.  

**Twist:** The player is named Wickwright. Night returns — with a morning at the end of it.

## Epilogue — The Deepdark

### 1. Where the Hush Went (`mq_dd_01`)
*The Lantern is lit. But the Hush didn't vanish. It sank under everything.*

**Objectives**
- talk `npc_a5_pell`: Talk to Pell at the Landing
- reach `deepdark`: Step into the Deepdark

**Intro**
> **Pell:** I trim the lighthouse wick once a week now. Because it's nice. Not because I must.  
> **Pell:** But the Hush went down. Under everything. Like night under morning.  
> **Pell:** It's not bad. It just needs tidying.  

**Outro**
> **You:** It's all the places I've been. Upside down. Greyer.  
> **Pell:** (on the wind) Take your time. The Deepdark has had a long night. So have you.  

### 2. The First Lightwell (`mq_dd_02`)
*Every town's Lightwell drained into the Deepdark. Dive in and bring some light back up.*

**Objectives**
- talk `npc_a1_questgiver`: Ask Warden Hollis about the old well
- reach `lightwell`: Dive into a Lightwell

**Intro**
> **Warden Hollis:** Our Lightwell was full of light once. For a dark day.  
> **Warden Hollis:** Well. It's been a dark year. Want to fetch some?  

**Outro**
> **Warden Hollis:** Look at that! Proper old light!  
> **Warden Hollis:** Stop halfway next time and you'll still keep what you found. No rush. Ever.  

### 3. Lantern Maps (`mq_dd_03`)
*Mae Coalbright draws maps into the Deepdark. Each one is a little different.*

**Objectives**
- talk `npc_a5_smith`: Talk to Mae Coalbright
- reach `deepdark` ×3: Finish three Deepdark runs

**Intro**
> **Mae Coalbright:** I've been making Lantern Maps. Still just learning.  
> **Mae Coalbright:** Foggy ones. Echoing ones. One's upside-down. Well. More upside-down.  

**Outro**
> **Mae Coalbright:** Three runs! You're better at this than me, and I've had seventy years.  
> **Mae Coalbright:** Keep going deeper, if you like. The Snuffed down there are stubborn, but they come round.  

### 4. The Long Shadow (`mq_dd_04`)
*Every shadow Mother Bark couldn't save gathered into one. It's very big. And very lonely.*

**Objectives**
- talk `mother_bark`: Hear Mother Bark's worry
- boss `long_shadow`: Rekindle the Long Shadow

**Intro**
> **Mother Bark:** Some little darks were too far gone for my jars. They found each other down there.  
> **Mother Bark:** Now it's one big dark. It just wants to be near a light.  
> **The Long Shadow:** …  

**Outro**
> **The Long Shadow:** (It shrinks. And splits. Into hundreds of small, happy shadows.)  
> **Mother Bark:** There they go! Home, every one!  
> **Mother Bark:** It'll gather again, I expect. Shadows are sociable. Visit it whenever you like.  

### 5. The Ninety-Ninth Chair (`mq_dd_05`)
*The Guild hall has ninety-nine chairs. Somebody has been carving.*

**Objectives**
- reach `a5_town`: Return to Lastlight Landing
- talk `npc_a5_questgiver`: Talk to Ada
- solve `puzzle_dd_chair`: Find your chair

**Intro**
> **Ada Brightly:** Ninety-nine chairs. For years, only mine was ever sat in.  
> **Ada Brightly:** Pell's been busy with a little knife. Go and look.  

**Outro**
> **You:** One chair has my name on it.  
> **Pell:** And one has mine. Next to yours. If that's alright.  
> **Ada Brightly:** Sit. Both of you. Rule three.  

### 6. The Last Letter (`mq_dd_06`)
*At the very brightest, the Answering Mailbox has one more letter.*

**Objectives**
- reach `brightness` ×200: Reach Brightness 200
- collect `sc_mailbox_last`: Open the last letter

**Intro**
> **Pell:** You're as bright as the Lantern ever was. Brighter, maybe.  
> **Pell:** There's a letter for you. It's been there a long time. It's in your handwriting.  

**Outro**
> **You:** 'Dear you. Your light never went out, because I lit it. From the other side.'  
> **You:** 'Carry it well. — You.'  
> **Pell:** So that's why you kept glowing. You were never alone either.  
> **Pell:** Kettle's on. Come and rest.  

**Twist:** You lit your own wick, from another turn of the story.

## Target ids used by objectives

`a1_boss`, `a1_town`, `a1_z1`, `a1_z2`, `a1_z3`, `a2_boss`, `a2_town`, `a2_z1`, `a2_z2`, `a2_z3`, `a3_boss`, `a3_town`, `a3_z1`, `a3_z2`, `a3_z3`, `a4_boss`, `a4_town`, `a4_z1`, `a4_z2`, `a4_z3`, `a5_boss`, `a5_town`, `a5_z1`, `a5_z2`, `a5_z3`, `brightness`, `cart_mimic`, `crystal_spider`, `deepdark`, `digling`, `escort_lamp_lenny`, `escort_nobody`, `escort_owlet_doughnut`, `escort_sir_wobble`, `escort_wisp_glim`, `faded_knight`, `great_echo`, `grey_guest`, `hushling`, `jr_bell_log`, `jr_pell_5`, `king_who_forgot`, `lightwell`, `long_shadow`, `magpie_imp`, `mirror_butler`, `mother_bark`, `npc_a1_questgiver`, `npc_a1_smith`, `npc_a1_storyteller`, `npc_a1_waypoint`, `npc_a2_alchemist`, `npc_a2_questgiver`, `npc_a2_storyteller`, `npc_a3_jeweler`, `npc_a3_questgiver`, `npc_a3_smith`, `npc_a3_stash`, `npc_a3_storyteller`, `npc_a3_waypoint`, `npc_a4_innkeeper`, `npc_a4_petkeeper`, `npc_a4_questgiver`, `npc_a4_runecarver`, `npc_a5_innkeeper`, `npc_a5_pell`, `npc_a5_questgiver`, `npc_a5_smith`, `npc_a5_storyteller`, `owlcrow`, `puzzle_a1_bell_ropes`, `puzzle_a2_honest_birch`, `puzzle_a2_owlcrow_riddle`, `puzzle_a3_song_order`, `puzzle_a4_third_mirror`, `puzzle_a5_silent_steps`, `puzzle_dd_chair`, `qi_crypt_key`, `qi_empty_jar`, `qi_floating_lamp`, `qi_lost_colour`, `qi_name_letter_a`, `qi_name_letter_d`, `qi_name_letter_l`, `qi_name_letter_r`, `qi_shadow_moth`, `qi_song_scrap`, `rattler`, `sc_mailbox_last`, `snow_hound`, `sound_eater`, `sunken_bellringer`, `tin_soldier`, `twigling`, `warden`
