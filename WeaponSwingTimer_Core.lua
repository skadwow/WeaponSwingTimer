---@type "WeaponSwingTimer"
local addon_name = select(1, ...)
---@class addon_data
local addon_data = select(2, ...)
local L = addon_data.localization_table

addon_data.core = {}

addon_data.core.core_frame = CreateFrame("Frame", addon_name .. "CoreFrame", UIParent)
addon_data.core.core_frame:RegisterEvent("ADDON_LOADED")

addon_data.core.all_timers = {
    addon_data.player, addon_data.target
}

local version = "2.0.7"

local load_message = L["Thank you for installing WeaponSwingTimer Version"] .. " " .. version .. 
                    " " .. L["by Skad! Use |cFFFFC300/wst|r for more options."]
addon_data.core.default_settings = {
    one_frame = false,
    welcome_message = true
}

addon_data.core.in_combat = false

local swing_reset_spells = {}
swing_reset_spells["DRUID"] = addon_data.spells.GetSpellIDs(L["Maul"])
swing_reset_spells["HUNTER"] = addon_data.spells.GetSpellIDs(L["Raptor Strike"])
swing_reset_spells["MAGE"] = {}
swing_reset_spells["PALADIN"] = {}
swing_reset_spells["PRIEST"] = {}
swing_reset_spells["ROGUE"] = {}
swing_reset_spells["SHAMAN"] = {}
swing_reset_spells["WARLOCK"] = {}
swing_reset_spells["WARRIOR"] = addon_data.spells.GetSpellIDs(L["Heroic Strike"], L["Cleave"], L["Slam"])

local function LoadAllSettings()
    addon_data.core.LoadSettings()
    addon_data.player.LoadSettings()
    addon_data.target.LoadSettings()
    addon_data.warrior.LoadSettings()
    addon_data.hunter.LoadSettings()
    addon_data.castbar.LoadSettings()
end

function addon_data.core.RestoreAllDefaults()
    addon_data.core.RestoreDefaults()
    addon_data.player.RestoreDefaults()
    addon_data.target.RestoreDefaults()
    addon_data.hunter.RestoreDefaults()
    addon_data.castbar.RestoreDefaults()
end

local function InitializeAllVisuals()
    addon_data.player.InitializeVisuals()
    addon_data.target.InitializeVisuals()
    addon_data.warrior.InitializeVisuals()
    addon_data.hunter.InitializeVisuals()
    addon_data.castbar.InitializeVisuals()
    addon_data.config.InitializeVisuals()
end

function addon_data.core.UpdateAllVisualsOnSettingsChange()
    addon_data.player.UpdateVisualsOnSettingsChange()
    addon_data.target.UpdateVisualsOnSettingsChange()
    addon_data.hunter.UpdateVisualsOnSettingsChange()
    addon_data.castbar.UpdateVisualsOnSettingsChange()
end

function addon_data.core.LoadSettings()
    -- If the carried over settings dont exist then make them
    if not character_core_settings then
        character_core_settings = {}
    end
    -- If the carried over settings aren't set then set them to the defaults
    for setting, value in pairs(addon_data.core.default_settings) do
        if character_core_settings[setting] == nil then
            character_core_settings[setting] = value
        end
    end
end

function addon_data.core.RestoreDefaults()
    for setting, value in pairs(addon_data.core.default_settings) do
        character_core_settings[setting] = value
    end
end

local function CoreFrame_OnUpdate(self, elapsed)
    addon_data.player.OnUpdate(elapsed)
    addon_data.target.OnUpdate(elapsed)
    addon_data.warrior.OnUpdate(elapsed)
    addon_data.hunter.OnUpdate(elapsed)
    addon_data.castbar.OnUpdate(elapsed)
end

function addon_data.core.MissHandler(unit, miss_type, is_offhand, is_player)
    if miss_type == "PARRY" then
        if unit == "player" then
            -- parry haste calculations:
            -- if swing is below 20%, do nothing.
            -- if swing is above 20%, reduce by 40% of main_weapon_speed
            -- if new swing is below 20%, set to 20% (parry cannot reduce swing timer below 20%)
            local min_swing_time = addon_data.target.main_weapon_speed * 0.2

            if min_swing_time >= addon_data.target.main_swing_timer then
                -- do nothing
            else
                addon_data.target.main_swing_timer = addon_data.target.main_swing_timer - (addon_data.target.main_weapon_speed * 0.4)

                if addon_data.target.main_swing_timer < min_swing_time then
                    addon_data.target.main_swing_timer = min_swing_time
                end
            end
            if not is_offhand then
            -- resets swing timer if it's not an extra attack, attempt to fix random resets mid-swing
                if (addon_data.player.extra_attacks_flag == false) then
                    addon_data.player.ResetMainSwingTimer()
                end
            addon_data.player.extra_attacks_flag = false
            else
                addon_data.player.ResetOffSwingTimer()
            end
        elseif unit == "target" and is_player then
            -- parry haste calculations:
            -- if swing is below 20%, do nothing.
            -- if swing is above 20%, reduce by 40% of main_weapon_speed
            -- if new swing is below 20%, set to 20% (parry cannot reduce swing timer below 20%)
            local min_swing_time = addon_data.player.main_weapon_speed * 0.2

            if min_swing_time >= addon_data.player.main_swing_timer then
                -- do nothing
            else
                addon_data.player.main_swing_timer = addon_data.player.main_swing_timer - (addon_data.player.main_weapon_speed * 0.4)

                if addon_data.player.main_swing_timer < min_swing_time then
                    addon_data.player.main_swing_timer = min_swing_time
                end
            end
            if not is_offhand then
                addon_data.target.ResetMainSwingTimer()
            else
                addon_data.target.ResetOffSwingTimer()
            end
        elseif unit == "target" then
            -- do nothing
        else
            addon_data.utils.PrintMsg(L["Unexpected Unit Type in MissHandler()."])
        end
    else
        if unit == "player" then
            if not is_offhand then
                if (addon_data.player.extra_attacks_flag == false) then
            addon_data.player.ResetMainSwingTimer()
        end
        addon_data.player.extra_attacks_flag = false
            else
                addon_data.player.ResetOffSwingTimer()
            end
        elseif unit == "target" then
            if not is_offhand then
                addon_data.target.ResetMainSwingTimer()
            else
                addon_data.target.ResetOffSwingTimer()
            end
        else
            addon_data.utils.PrintMsg(L["Unexpected Unit Type in MissHandler()."])
        end
    end
end

function addon_data.core.SpellHandler(unit, spell_id)
    local _, player_class, _ = UnitClass("player")
    for _, curr_spell_id in ipairs(swing_reset_spells[player_class]) do
        if spell_id == curr_spell_id then
            if unit == "player" then
                addon_data.player.ResetMainSwingTimer()
            elseif unit == "target" then
                addon_data.target.ResetMainSwingTimer()
            else
                addon_data.utils.PrintMsg(L["Unexpected Unit Type in SpellHandler()."])
            end
        end
    end
end

local function OnAddonLoaded(self)
    -- Attach the rest of the events and scripts to the core frame
    addon_data.core.core_frame:SetScript("OnUpdate", CoreFrame_OnUpdate)
    addon_data.core.core_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    addon_data.core.core_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    addon_data.core.core_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    addon_data.core.core_frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    addon_data.core.core_frame:RegisterEvent("START_AUTOREPEAT_SPELL")
    addon_data.core.core_frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
    addon_data.core.core_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    addon_data.core.core_frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    addon_data.core.core_frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    addon_data.core.core_frame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
    addon_data.core.core_frame:RegisterEvent("UNIT_SPELLCAST_SENT")
    addon_data.core.core_frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    -- Load the settings for the core and all timers
    LoadAllSettings()
    InitializeAllVisuals()
    -- Any other misc operations that happen at the start
    addon_data.player.ZeroizeSwingTimers()
    addon_data.target.ZeroizeSwingTimers()

    if character_core_settings.welcome_message then
        addon_data.utils.PrintMsg(load_message)
    end
end

local function CoreFrame_OnEvent(self, event, ...)
    local args = {...}
    if event == "ADDON_LOADED" and args[1] == addon_name then
        OnAddonLoaded()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local combat_info = {CombatLogGetCurrentEventInfo()}
        addon_data.player.OnCombatLogUnfiltered(unpack(combat_info))
        addon_data.target.OnCombatLogUnfiltered(unpack(combat_info))
        addon_data.warrior.OnCombatLogUnfiltered(unpack(combat_info))
        addon_data.hunter.OnCombatLogUnfiltered(unpack(combat_info))
        addon_data.castbar.OnCombatLogUnfiltered(unpack(combat_info))
    elseif event == "PLAYER_REGEN_DISABLED" then
        addon_data.core.in_combat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        addon_data.core.in_combat = false
    elseif event == "PLAYER_TARGET_CHANGED" then
        addon_data.player.OnPlayerTargetChanged()
        addon_data.target.OnPlayerTargetChanged()
        addon_data.warrior.OnPlayerTargetChanged()
    elseif event == "START_AUTOREPEAT_SPELL" then
        addon_data.hunter.OnStartAutorepeatSpell()
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        addon_data.hunter.OnStopAutorepeatSpell()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        addon_data.player.OnInventoryChange()
        addon_data.target.OnInventoryChange()
        addon_data.hunter.OnInventoryChange()
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        addon_data.warrior.OnUnitSpellCastInterrupted(args[1], args[3])
        addon_data.hunter.OnUnitSpellCastInterrupted(args[1], args[3])
        addon_data.castbar.OnUnitSpellCastInterrupted(args[1], args[3])
    elseif event == "UNIT_SPELLCAST_SENT" then
        addon_data.warrior.OnUnitSpellCastSent(args[1], args[4])
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        addon_data.warrior.OnUnitSpellCastSucceeded(args[1], args[3])
        addon_data.hunter.OnUnitSpellCastSucceeded(args[1], args[3])
        addon_data.castbar.OnUnitSpellCastSucceeded(args[1], args[3])
    elseif event == "UNIT_SPELLCAST_FAILED" then
        addon_data.warrior.OnUnitSpellCastFailed(args[1], args[3])
        addon_data.castbar.OnUnitSpellCastFailed(args[1], args[3])
    elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
        addon_data.warrior.OnUnitSpellCastFailedQuiet(args[1], args[3])
        addon_data.hunter.OnUnitSpellCastFailedQuiet(args[1], args[3])
    end
end

-- Add a slash command to bring up the config window
SLASH_WEAPONSWINGTIMER_CONFIG1 = "/WeaponSwingTimer"
SLASH_WEAPONSWINGTIMER_CONFIG2 = "/weaponswingtimer"
SLASH_WEAPONSWINGTIMER_CONFIG3 = "/wst"
SlashCmdList["WEAPONSWINGTIMER_CONFIG"] = function(option)
    Settings.OpenToCategory("WeaponSwingTimer")
end

-- Setup the core of the addon (This is like calling main in C)
addon_data.core.core_frame:SetScript("OnEvent", CoreFrame_OnEvent)
