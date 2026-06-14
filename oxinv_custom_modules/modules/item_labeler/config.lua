Config = Config or {}
Config.Modules = Config.Modules or {}

local Module = {}
Config.Modules.ItemLabeler = Module

Module.Enabled = true

-- Players must split stacked items before applying a custom label.
-- Strongly recommended so one stack is not accidentally renamed as a group.
Module.RequireSingleItem = true

-- Label length limits.
Module.MinLength = 1
Module.MaxLength = 32

-- If true, submitting a blank label clears metadata.label and restores the base item name.
Module.AllowClear = true

-- Client-side lock while the ox_lib input dialog is open.
-- This prevents players from walking, attacking, using hotkeys, opening other UI, or interacting while naming an item.
Module.DisableControlsDuringDialog = true
Module.DisableAllControlsDuringDialog = true
Module.SetInventoryBusyDuringDialog = true
Module.FreezePlayerDuringDialog = false

-- Used only when Module.DisableAllControlsDuringDialog is false.
-- These are GTA/FiveM control indexes for movement, combat, vehicle, phone, inventory/hotbar-style keys, and interaction keys.
Module.DisabledControls = {
    1, 2, 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 44, 45, 47, 58,
    59, 60, 63, 64, 71, 72, 73, 75, 76, 140, 141, 142, 143, 157, 158, 159, 160,
    161, 162, 163, 164, 165, 170, 177, 199, 200, 244, 257, 263, 264, 289, 311
}

-- The Label button must still be manually added to every ox_inventory item that should use this resource.
-- This blacklist remains as a server-side safety net for protected items, accidental button placement,
-- or manual event abuse.
Module.Blacklist = {
    money = true,
    black_money = true,
    cash = true,
    bank = true,
}

-- Optional content restrictions for display/UI sanity.
Module.BlockControlCharacters = true
Module.BlockAngleBrackets = true
Module.BlockTildeFormatting = true

-- Optional substring filter. Case-insensitive. Leave empty unless needed.
-- These also protect webhook output from unwanted mass pings.
Module.BlockedSubstrings = {
    '@everyone',
    '@here',
    -- 'admin',
    -- 'owner',
}

-- Optional audit metadata stored on the item slot.
Module.StoreAuditMetadata = true
Module.AuditMetadataKeys = {
    customFlag = 'customLabel',
    labeledBy = 'labeledBy',
    labeledAt = 'labeledAt'
}

-- Optional Discord webhook logging for admin/tracking purposes.
Module.Webhook = {
    Enabled = false,
    Url = '',
    Username = 'OX_Inventory Item Labeler',
    AvatarUrl = '',
    ColorApplied = 65280,
    ColorCleared = 16753920,
    ColorRejected = 16711680,

    LogApplied = true,
    LogCleared = true,
    LogRejected = false,

    IncludeIdentifiers = true
}

Module.Notifications = {
    invalidSlot = 'Invalid item slot.',
    missingItem = 'Item no longer exists.',
    notAllowed = 'This item cannot be labeled.',
    splitStack = 'Split the stack before labeling this item.',
    blankNotAllowed = 'Label cannot be blank.',
    invalidCharacters = 'Label contains invalid characters.',
    blockedText = 'Label contains blocked text.',
    cleared = 'Item label cleared.',
    applied = 'Item labeled: %s',
    dialogAlreadyOpen = 'A label dialog is already open.'
}
