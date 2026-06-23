# Reinforced Jokers

By **Soareverix**.

A Balatro mod that keeps **Showman** permanently active and lets duplicate Jokers **stack** instead of taking a new slot. Pick up a Joker you already own and it folds into the copy you have, bumping a stack counter, so you can run a **3x Photograph** or a **2x Chad**. A stacked Joker applies its effect once per stack.

Built on commission for [Bean](https://www.youtube.com/@BeanBalatro).

## How it works

- **Always-on Showman:** duplicates always show up in the shop and packs.
- **Combine on pickup:** acquiring a Joker you already own removes the new card and increments a stack count on the existing one (with a little juice for feedback).
- **Stacking = effect x stack:** when a stacked Joker scores, its effect is scaled by the stack. Additive fields (mult, chips, money, retriggers) multiply by N; multiplier fields (x_mult, x_chips) raise to the power N. So 3x Photograph is X2^3 = **X8**, and 2x Chad retriggers 2 x 2 = **4** times.
- The stack count shows on the Joker's tooltip as "Reinforced xN".

All three behaviours can be toggled in the mod config.

## Requirements

- [Lovely](https://github.com/ethangreen-dev/lovely-injector) and [Steamodded](https://github.com/Steamodded/smods) (1.0.0-beta or newer).

## Install

```
cd %AppData%\Balatro\Mods
git clone https://github.com/Michael-Andrzejewski/Reinforced-Jokers.git ReinforcedJokers
```

## Known limitations (v1)

Bean's brief was to cover the common cases, and this is scoped to match.

- One-time / create-card / self-scaling Jokers run their side effect once per pickup, not once per stack (only the scored value scales).
- The incoming duplicate's edition and eternal/perishable/rental stickers are dropped; the kept copy wins.
- Combining is by Joker type, ignoring edition.
- You need a free Joker slot to buy a duplicate; the slot frees up the instant it merges.

## Status

- [x] Always-on Showman
- [x] Combine duplicate Jokers on pickup (stack counter + tooltip)
- [x] Stacked Jokers apply their effect per stack
- [x] Config toggles
- [ ] Playtesting + edge-case polish
