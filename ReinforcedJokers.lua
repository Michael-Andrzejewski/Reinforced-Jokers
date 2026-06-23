--[[
  Reinforced Jokers
  Author: Soareverix  (commissioned by Bean)

  Two linked behaviours, both on by default:
    1. Showman is always active, so duplicate Jokers can appear.
    2. Picking up a Joker you already own folds it into the copy you
       have, bumping a stack counter instead of taking a new slot. A
       stacked Joker applies its effect once per stack, so a 3x
       Photograph gives X2^3 = X8 and a 2x Chad retriggers 2 x 2 = 4.

  Stacking model: when a stacked Joker scores, we scale the effect table
  it returns by the stack count (additive fields x N, multiplicative
  fields ^ N, repetitions x N). This matches "N copies of the Joker" for
  the large majority of Jokers (mult, chips, x_mult, money, retriggers).

  Known v1 limits (Bean: scope to the common cases):
    * One-time / create-card / self-scaling Jokers run their side effect
      once per pickup, not once per stack.
    * Editions and eternal/perishable/rental of the *incoming* duplicate
      are dropped; the kept copy's stickers/edition win.
    * Combining is by Joker type (center key), ignoring edition.
--]]

----------------------------------------------------------------------
-- Config
----------------------------------------------------------------------

local rj_mod = SMODS.current_mod

local rj_defaults = {
    enabled            = true,
    always_showman     = true,
    combine_and_stack  = true,
}

if rj_mod then
    rj_mod.config = rj_mod.config or {}
    for k, v in pairs(rj_defaults) do
        if rj_mod.config[k] == nil then rj_mod.config[k] = v end
    end
end

local function rj_cfg()
    return (rj_mod and rj_mod.config) or rj_defaults
end

local function rj_enabled()
    return rj_cfg().enabled ~= false
end

local function rj_stack_of(card)
    return (card and card.ability and card.ability.rj_stack) or 1
end

----------------------------------------------------------------------
-- 1. Always-on Showman
----------------------------------------------------------------------

-- SMODS.showman(key) is the single gate the pool generator checks to
-- allow a card to repeat. Force it true so duplicates always appear.
local rj_orig_showman = SMODS.showman
function SMODS.showman(card_key)
    if rj_enabled() and rj_cfg().always_showman then return true end
    return rj_orig_showman(card_key)
end

----------------------------------------------------------------------
-- 2a. Stacking: scale a stacked Joker's effect by its stack count
----------------------------------------------------------------------

-- Fields that represent an additive bonus (N copies -> value x N).
local RJ_ADD_KEYS = {
    'mult', 'h_mult', 'chips', 'h_chips',
    'dollars', 'p_dollars', 'repetitions',
}
-- Fields that represent a multiplier (N copies -> value ^ N).
local RJ_MUL_KEYS = {
    'x_mult', 'Xmult', 'xmult', 'x_chips', 'h_x_mult',
}

local function rj_scale_effect(ret, n)
    if type(ret) ~= 'table' or n <= 1 then return ret end
    for _, k in ipairs(RJ_ADD_KEYS) do
        if type(ret[k]) == 'number' then ret[k] = ret[k] * n end
    end
    for _, k in ipairs(RJ_MUL_KEYS) do
        if type(ret[k]) == 'number' and ret[k] ~= 1 then ret[k] = ret[k] ^ n end
    end
    return ret
end

-- Card:calculate_joker returns the Joker's effect table (o) plus an
-- optional trigger flag (t). We scale o by the stack and pass t through.
local rj_orig_calc_joker = Card.calculate_joker
function Card:calculate_joker(context)
    local o, t = rj_orig_calc_joker(self, context)
    if rj_enabled() and type(o) == 'table' then
        local n = rj_stack_of(self)
        if n > 1 then rj_scale_effect(o, n) end
    end
    return o, t
end

----------------------------------------------------------------------
-- 2b. Combine on pickup
----------------------------------------------------------------------

-- Find an existing Joker of the same type to fold a duplicate into.
local function rj_find_target(card)
    if not (G.jokers and G.jokers.cards and card.config) then return nil end
    local key = card.config.center_key
    if not key then return nil end
    for _, j in ipairs(G.jokers.cards) do
        if j ~= card and j.config and j.config.center_key == key and not j.getting_sliced then
            return j
        end
    end
    return nil
end

-- Fold `card` into an existing copy if one exists.
local function rj_try_merge(card)
    if not rj_enabled() or not rj_cfg().combine_and_stack then return end
    if not (card and card.ability and card.ability.set == 'Joker') then return end
    if card.getting_sliced then return end
    local target = rj_find_target(card)
    if not target then return end

    target.ability.rj_stack = rj_stack_of(target) + rj_stack_of(card)
    if target.juice_up then target:juice_up(0.5, 0.5) end

    -- Remove the incoming duplicate (animated, like a destroyed Joker).
    card.getting_sliced = true
    pcall(function() card:start_dissolve() end)
end

-- Hook add_to_deck so a freshly acquired Joker schedules a merge check
-- AFTER the acquisition flow finishes (avoids touching the card while
-- the buy/open code still references it).
local rj_orig_add_to_deck = Card.add_to_deck
function Card:add_to_deck(from_debuff)
    local res = rj_orig_add_to_deck(self, from_debuff)
    if rj_enabled() and rj_cfg().combine_and_stack
       and self.ability and self.ability.set == 'Joker' then
        local card = self
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.0,
            func = function()
                pcall(function() rj_try_merge(card) end)
                return true
            end,
        }))
    end
    return res
end

----------------------------------------------------------------------
-- 3. Display the stack count on the Joker's tooltip
----------------------------------------------------------------------

local rj_hover_card = nil

local rj_orig_hover = Card.hover
function Card:hover()
    rj_hover_card = self
    return rj_orig_hover(self)
end

local rj_orig_stop_hover = Card.stop_hover
function Card:stop_hover()
    if rj_hover_card == self then rj_hover_card = nil end
    return rj_orig_stop_hover(self)
end

-- generate_card_ui's result.main entries are flat arrays of inline text
-- UIEs (the outer renderer wraps them in rows). Append a "Reinforced xN"
-- line for any stacked Joker.
local rj_orig_gen_card_ui = generate_card_ui
function generate_card_ui(...)
    local args = { ... }
    local card_type = args[4]
    local card = args[9] or rj_hover_card
    local result = rj_orig_gen_card_ui(...)

    if not rj_enabled() or not result or not result.main then return result end
    if card_type ~= 'Joker' then return result end
    if not (card and card.ability and card.ability.set == 'Joker') then return result end

    local n = rj_stack_of(card)
    if n and n > 1 then
        pcall(function()
            table.insert(result.main, {
                { n = G.UIT.T, config = {
                    text = 'Reinforced x' .. tostring(n),
                    scale = 0.34,
                    colour = G.C.RED,
                } },
            })
        end)
    end
    return result
end

----------------------------------------------------------------------
-- Mod config tab
----------------------------------------------------------------------

if rj_mod then
    rj_mod.config_tab = function()
        local cfg = rj_mod.config or rj_defaults
        local function toggle(label, key)
            return { n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
                create_toggle({ label = label, ref_table = cfg, ref_value = key }),
            } }
        end
        return {
            n = G.UIT.ROOT,
            config = { align = 'cm', padding = 0.04, colour = G.C.CLEAR },
            nodes = {
                toggle('Enable Reinforced Jokers', 'enabled'),
                toggle('Always-on Showman', 'always_showman'),
                toggle('Combine + stack duplicate Jokers', 'combine_and_stack'),
            },
        }
    end
end
