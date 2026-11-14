# Changelog

Each version's section here becomes its release notes on GitHub.

## 0.5.1 (2026-11-14)

The first published release of the Android version. The game is the same as 0.5.0 (below), whose release stopped before anything was published: the test that updates the Android version on an emulator got stuck behind Android's first-time "Viewing full screen" hint. The test now dismisses that hint the way a player would.

## 0.5.0 (2026-11-13)

**Shelf Life on Android, with touch controls you can rearrange.**

- **Android.** `ShelfLife-android-arm64.apk` runs on phones and tablets with Android 7.0 or newer (`ShelfLife-android-x86_64.apk` is for Chromebooks and emulators). It plays sideways either way up, starts on Low graphics, and stops at 60 frames a second to spare the battery.
- **Touch controls.** A stick on the left that comes to wherever your thumb lands, JUMP, TALK and WHISTLE on the right, and a pause button at the top. Hold JUMP to go higher, as with a key. TALK lights up when someone's close enough to talk to, and the Talk bubble over their head works as a button too. WHISTLE shows up once Dot is with you.
- **Put them where you like.** Settings → Touch controls → Customize: drag any control somewhere else, tap one and set its size, and set how see-through they are. Move with a stick that follows your thumb, a stick that stays put, or two arrow buttons. The short buzz on presses, cracks and deaths can be turned off there too, and "Put them back" restores the layout.
- In a conversation, tap anywhere to read on and hold to fast-forward. A second finger works while your thumb is still on the stick.
- Android's Back button pauses, steps back out of menus, and leaves the game from the title screen. Switching to another app pauses the game.
- The Android version updates itself too. The title screen offers the new version, downloads it, checks it and opens Android's installer. The first time, Android asks you to allow installs from Shelf Life: allow it, then press Update again.
- The touch controls show while you play on a touchscreen and hide when you pick up a gamepad or the keyboard. Settings → Touch controls can keep them on or off instead, on any system.
- With a mouse, a click in the pause menu could go to the conversation behind it instead: the line moved on and the button didn't press. Clicks in the pause menu now stay there.

## 0.4.0 (2026-11-12)

**Dot earns her keep.** Once she's with you, whistle (Q or F, or Y on a gamepad) and she lies down for you.

- On level ground she slides in under your feet. A jump off her back goes about half again as high as a normal one, and holding jump keeps you bouncing.
- At a drop she goes down first and waits below, and shuffles over to get under you as you fall. Landing on her never cracks your shell, from any height.
- Whistle again, walk away or start talking, and she gets up and follows. She won't lie down on a moving belt or a mousetrap, and she's too busy during the run across the Baler.
- Act Two has two places built for it. A Planogram scrap now sits on a step stool in the breakroom that only a boost reaches. The stockroom conveyor now ends on a steel landing with a long drop to the floor; the flour sacks that used to break your fall are stacked out of the way.
- She tells you about it when she joins you in Act One, and again at both of those places.

## 0.3.0 (2026-11-12)

How the game feels, and how fast it runs.

- **Fairer falls.** A jump's own height now counts for only about a third toward a hard landing. Hopping off a crate, a pallet or a basket no longer cracks your shell. Leaping off a table or a tall shelf still does, and walking off a ledge works as before.
- **Shadows at Low quality.** Every character now has a soft shadow on the ground at Low, where real shadows are off. Baker's shadow stays on the ground beneath him while he's in the air, at every quality setting, so you can see where he'll land.
- **Act One runs faster on old graphics cards.** On old Intel graphics the back hall went from about 39 to 59 frames a second, and the dairy case from 51 to 58. It looks the same: lamps no longer spill into the next room, and Low quality lights the dairy case and the bakery with one lamp each instead of two.
- A crack now lands with a flash and a split-second freeze. Both are off when screen shake is off.
- The controls appear along the bottom of the screen the first time you can move.
- Hold the advance button to fast-forward a conversation.
- The cards at the end of an act now appear. Since the first release they were drawn behind the fade to black, so the act just ended on a dark screen. The second card now shows your scraps, cracks, deaths and time.
- At Medium and High quality the picture darkens slightly toward the corners.

## 0.2.4 (2026-11-12)

- A character's speech bubble now sits above the Talk button instead of underneath it.
- Dot no longer offers a chat in the middle of the run across the Baler.
- The stockroom's safety board ("this department has worked 0 days without an accident") was too high on the wall to see. It now hangs behind the mousetraps.

## 0.2.3 (2026-11-12)

- In Act One, three story moments could be jumped clean over: meeting Her Holiness, Beans's warning about the Narc, and the bakery checkpoint. Their zones now cover wherever you can land.
- The game's sounds are ready about twice as fast after launch (2 seconds instead of 4.4 on a four-core machine), so the title music comes in sooner. They are now built on several processor cores at once.
- Music asked for before the sounds were ready used to come in louder than intended. It now starts at the volume it was asked for.

## 0.2.2 (2026-11-12)

Fixes from a closer playtest of Act Two.

- Dangler, the chip bag stuck in the vending machine, can be talked to now. Before, Dot always took the Talk button because she stands closer. Anyone else in reach now gets the button before Dot does.
- Jumping can no longer carry you over a story scene. The zones that start them are now wider than a full jump.
- The last two mousetraps are further apart, so a full jump over one no longer lands you on the next.
- Conveyor belts hold still while you read a Planogram scrap or talk, instead of carrying you off.
- The Baler's small ram only covers the front of the belt, so it no longer slams through the Discontinued's tote. Both rams only kill while they are low enough to touch you.
- Leaping off the end of the conveyor, or off the stop button, now always ends on something soft. Neither can crack your shell any more.
- The back rooms run faster: about 55 to 65 frames a second on old Intel graphics, up from about 43 in the slowest spots.
- The notes on the fridge and the Planogram printout are easier to read, and the Flaps are easier to spot.

## 0.2.1 (2026-11-12)

- The last shot of Act Two now shows Baker and Dot looking out at the store, instead of hiding them behind the dialogue box.

## 0.2.0 (2026-11-12)

**Act Two: Discontinued.** The story carries on behind the Employees Only doors, about 15 minutes of new game. Finish Act One and it starts by itself, or pick it from the title screen once Act One is done.

- Three new rooms: the breakroom floor, the stockroom and Receiving.
- Seven new characters, including a chip bag stuck in the vending machine for six weeks, a lasagna that became a civilization, Colonel Kernel and Pallet Nine, and the Discontinued.
- New things to get past: mousetraps, conveyor belts and the Baler. One sequence is against the clock.
- A new music track for the Back, and six more Planogram scraps.
- The pause menu can now show every Planogram scrap you've found, so you can read them again.
- The title screen can replay either act once you've finished Act One.
- The dialogue box now gets out of the way while something is happening on screen.
- Baker kicks up a little dust when jumping and landing.

## 0.1.0 (2026-11-11)

The first release: **Act One: Unplanned**, playable start to finish in about 20 minutes.

- Four parts of the store: the dairy case, the main aisle, the bakery and the Employees Only doors, with the whole Act One cast and 11 optional conversations.
- Eggs crack: a short drop is fine, a tall one costs you, and three cracks and you're scrambled. Bread and other soft things are safe to land on.
- Sneak past the Narc, the floor-cleaning robot, using the store's hiding spots.
- Six Planogram scraps to find.
- Graphics presets (Low, Medium, High). Older Intel graphics start on Low.
- Plays with a keyboard or a gamepad.
- The game updates itself from GitHub releases. You can turn the check off in Settings.
