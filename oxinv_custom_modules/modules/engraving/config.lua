Config = Config or {}
Config.Modules = Config.Modules or {}

local Module = {}
Config.Modules.Engraving = Module

Module.Enabled = true

-- The usable Ox Inventory item name.
Module.MachineItem = 'engraving_machine'

-- Total durability uses for a full engraving machine.
-- ox_inventory implements this through the item definition's consume value: 1 / MachineUses.
-- The server checks the registered item on startup and warns if ox_inventory/data/items.lua is out of sync.
Module.MachineUses = 10

-- Public tooltip metadata applied to the engraved target item when enabled.
-- These are the fields that can be displayed by ox_inventory:displayMetadata.
Module.MetadataKey = 'engraving'
Module.MetadataLabel = 'Engraving'
Module.EngravedByKey = 'engraved_by'
Module.EngravedByLabel = 'Engraved By'
Module.EngravedAtKey = 'engraved_at'
Module.EngravedAtLabel = 'Engraved At'

-- Internal hidden metadata fields.
-- The engraving and audit data are stored here so they can remain hidden from the player-facing tooltip.
-- Do not register these keys with ox_inventory:displayMetadata.
Module.InternalEngravingKey = '_engraving_text'
Module.InternalAuditKey = '_engraving_audit'

-- Input limits.
Module.MinLength = 1
Module.MaxLength = 64

-- Allows replacing an existing engraving on the same item.
Module.AllowReEngrave = true

-- When true, overwriting an existing engraving requires an ACE permission.
-- Set `Module.ReEngraveAcePermission` to the ACE permission/group used on your server (for example: 'group.admin').
Module.RequireReEngraveAce = true
Module.ReEngraveAcePermission = 'engraving.overwrite'

-- Only players with this ACE permission may engrave entire stacks in place.
-- Non-admins will instead engrave a single item from the stack and move it to a new unique stack.
Module.FullStackEngraveAcePermission = 'engraving.stacks'

-- Prevent specific items from being engraved by adding them to the blacklist below.
-- The engraving machine is blocked by default so players cannot engrave the tool itself.
Module.BlockedItems = {
    [Module.MachineItem] = true,
    money = true,
    black_money = true,
}

-- Audit metadata is always stored internally for backend functionality and Discord logging.
-- The leading ! uses UTC. Remove ! to use server local time.
Module.TimestampFormat = '!%Y-%m-%d %H:%M:%S UTC'

-- Tooltip display options.
-- Data can be stored internally while hidden from the player-facing item tooltip. [Hidden By Default - Only Really Needed For Admin Logs]
Module.Tooltip = {
    ShowEngraving = true,
    ShowEngravedBy = false,
    ShowEngravedAt = false,

    -- Keeps compatibility with ox_inventory builds/forks where displayMetadata does not render reliably.
    -- This writes only the enabled tooltip lines into metadata.description.
    UseDescriptionFallback = true,
    DescriptionSeparator = '\n',

    -- If the target item already has a metadata.description, preserve it above the engraving lines.
    PreserveExistingDescription = true,
}

-- Compatibility cleanup.
-- Removes legacy public audit fields when ShowEngravedBy/ShowEngravedAt are disabled.
-- This prevents older registered displayMetadata fields from leaking hidden audit data into tooltips.
Module.CleanHiddenTooltipFields = true

-- Optional Discord admin logging.
Module.Webhook = {
    Enabled = false,-- Set to true to enable Discord logging. Requires a valid Webhook URL below
    Url = '',
    Username = 'Engraving Machine Logs',
    AvatarUrl = '',
    Color = 16753920,

    -- Include player identifiers in the Discord embed.
    IncludeIdentifiers = true,

    -- Include old engraving value when an item is re-engraved.
    IncludePreviousEngraving = true,
}

-- Server-side pending request timeout, in seconds.
Module.PendingTimeout = 45

-- Cooldown for the engraving debug command, in seconds.
-- Prevents repeated log spam in production.
Module.DebugCooldown = 300

-- Client-side safety timeout in milliseconds.
-- Used only as a fallback for ox_inventory builds/forks that do not call the useItem callback when progress is cancelled.
-- This does not consume durability; it only clears the local interaction lock and server pending request.
Module.ClientUseTimeout = 15000

-- Notifications.
Module.Notify = {
    noTargets = 'You do not have any items that can be engraved.',
    invalidText = 'Enter valid engraving text.',
    invalidMachine = 'Invalid engraving machine.',
    invalidTarget = 'Invalid target item.',
    blockedTarget = 'That item cannot be engraved.',
    alreadyEngraved = 'That item is already engraved.',
    prepared = 'Engraving prepared.',
    cancelled = 'Engraving cancelled.',
    success = 'Item engraved successfully.',
    repaired = 'Engraving metadata display refreshed.',
    failed = 'Engraving failed.',
    commandCooldown = 'Command is on cooldown. Try again in a few minutes.',
    noPermission = 'You do not have permission to overwrite engravings.',
}
