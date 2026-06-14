local Config = Config and Config.Modules and Config.Modules.Engraving or {}
if Config.Enabled == false then return end

local busy = false
local activeUseId = 0
local metadataDisplayRegistered = false

local function notify(description, notifyType)
    lib.notify({
        title = 'Engraving Machine',
        description = description,
        type = notifyType or 'inform'
    })
end

local function shouldShowTooltipField(fieldName)
    Config.Tooltip = Config.Tooltip or {}

    if fieldName == Config.MetadataKey then
        return Config.Tooltip.ShowEngraving ~= false
    end

    if fieldName == Config.EngravedByKey then
        return Config.Tooltip.ShowEngravedBy == true
    end

    if fieldName == Config.EngravedAtKey then
        return Config.Tooltip.ShowEngravedAt == true
    end

    return false
end

local function getMetadataDisplayEntries()
    local entries = {}

    if shouldShowTooltipField(Config.MetadataKey) then
        entries[#entries + 1] = { Config.MetadataKey, Config.MetadataLabel }
    end

    if shouldShowTooltipField(Config.EngravedByKey) then
        entries[#entries + 1] = { Config.EngravedByKey, Config.EngravedByLabel }
    end

    if shouldShowTooltipField(Config.EngravedAtKey) then
        entries[#entries + 1] = { Config.EngravedAtKey, Config.EngravedAtLabel }
    end

    return entries
end

local function registerMetadataDisplay(force)
    if metadataDisplayRegistered and not force then return end

    local entries = getMetadataDisplayEntries()
    if #entries == 0 then return end

    -- Array format is supported by ox_inventory and preserves tooltip display order.
    exports.ox_inventory:displayMetadata(entries)
    metadataDisplayRegistered = true
end

local function getEngravingText(metadata)
    if type(metadata) ~= 'table' then return nil end

    local value = metadata[Config.InternalEngravingKey]
    if value == nil or value == '' then
        value = metadata[Config.MetadataKey]
    end

    if value == nil or value == '' then return nil end
    return tostring(value)
end

local function itemDisplayName(item)
    if item.metadata then
        if type(item.metadata.label) == 'string' and item.metadata.label ~= '' then
            return item.metadata.label
        end

        if type(item.metadata.type) == 'string' and item.metadata.type ~= '' then
            return ('%s (%s)'):format(item.label or item.name, item.metadata.type)
        end
    end

    return item.label or item.name
end

local function getTargetOptions(machineSlot)
    local items = exports.ox_inventory:GetPlayerItems()
    local options = {}

    for _, item in pairs(items or {}) do
        if item and item.name and item.slot and item.count and item.count > 0 then
            local blocked = Config.BlockedItems[item.name]

            if item.slot ~= machineSlot and not blocked then
                local engraving = getEngravingText(item.metadata)
                local label = ('Slot %s - %s'):format(item.slot, itemDisplayName(item))

                if engraving and engraving ~= '' then
                    label = ('%s [%s: %s]'):format(label, Config.MetadataLabel, tostring(engraving))
                end

                options[#options + 1] = {
                    label = label,
                    value = tostring(item.slot)
                }
            end
        end
    end

    table.sort(options, function(a, b)
        return tonumber(a.value) < tonumber(b.value)
    end)

    return options
end

local function getItemBySlot(slot)
    for _, item in pairs(exports.ox_inventory:GetPlayerItems() or {}) do
        if item and item.slot == slot then
            return item
        end
    end

    return nil
end

exports('engraving_machine', function(data, slot)
    if busy then return end

    registerMetadataDisplay()

    local machineSlot = data and data.slot or slot
    if not machineSlot then
        return notify(Config.Notify.invalidMachine, 'error')
    end

    local options = getTargetOptions(machineSlot)
    if #options == 0 then
        return notify(Config.Notify.noTargets, 'error')
    end

    local input = lib.inputDialog('Engraving Machine', {
        {
            type = 'select',
            label = 'Item to Engrave',
            description = 'Choose the inventory slot that receives the engraving metadata.',
            options = options,
            required = true,
            searchable = true,
        },
        {
            type = 'input',
            label = 'Engraving Text',
            description = ('%s-%s characters.'):format(Config.MinLength, Config.MaxLength),
            placeholder = 'Example: Property of Old Joe',
            required = true,
            min = Config.MinLength,
            max = Config.MaxLength,
        }
    })

    if not input then return end

    local targetSlot = tonumber(input[1])
    local engravingText = input[2]

    if not targetSlot or type(engravingText) ~= 'string' then
        return notify(Config.Notify.invalidText, 'error')
    end

    local targetItem = getItemBySlot(targetSlot)
    local targetName = itemDisplayName(targetItem or { label = ('Slot %s'):format(tostring(targetSlot)) })
    local confirmation = lib.inputDialog('Confirm Engraving', {
        {
            type = 'select',
            label = ('Engrave %s?'):format(targetName),
            description = ('Engraving text: %s'):format(engravingText),
            options = {
                { label = 'Yes, start engraving', value = 'yes' },
                { label = 'No, cancel engraving', value = 'no' },
            },
            required = true,
        }
    })

    if not confirmation or confirmation[1] ~= 'yes' then
        return notify(Config.Notify.cancelled, 'error')
    end

    busy = true
    activeUseId = activeUseId + 1
    local useId = activeUseId

    local ok, message = lib.callback.await('oxinv_custom_modules:engraving:prepare', false, machineSlot, targetSlot, engravingText)

    if not ok then
        if activeUseId == useId then
            busy = false
        end
        return notify(message or Config.Notify.failed, 'error')
    end

    -- Safety net for cancelled ox_inventory progressbars on builds/forks that do not call the useItem callback on cancel.
    -- This clears the local busy state and server pending request without consuming durability.
    SetTimeout(Config.ClientUseTimeout or 15000, function()
        if busy and activeUseId == useId then
            busy = false
            TriggerServerEvent('oxinv_custom_modules:engraving:cancel')
            notify(Config.Notify.cancelled, 'error')
        end
    end)

    exports.ox_inventory:useItem(data, function(used)
        if activeUseId ~= useId then return end

        busy = false

        if not used then
            TriggerServerEvent('oxinv_custom_modules:engraving:cancel')
            return notify(Config.Notify.cancelled, 'error')
        end
    end)
end)

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(250)
    end

    Wait(500)
    registerMetadataDisplay()

    -- Cleans legacy public metadata fields from already-engraved items after a resource restart/client load.
    Wait(2000)
    TriggerServerEvent('oxinv_custom_modules:engraving:refreshEngravedItems')
end)


