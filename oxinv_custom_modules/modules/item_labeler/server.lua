local Config = Config and Config.Modules and Config.Modules.ItemLabeler or {}
if Config.Enabled == false then return end

local ox_inventory = exports.ox_inventory
local labelCooldown = {}

local function notify(source, type, description)
    TriggerClientEvent('ox_lib:notify', source, {
        type = type or 'inform',
        description = description
    })
end

local function trim(value)
    value = tostring(value or '')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    value = value:gsub('%s+', ' ')
    return value
end

local function copyMetadata(metadata)
    local copy = {}

    if type(metadata) ~= 'table' then
        return copy
    end

    for key, value in pairs(metadata) do
        copy[key] = value
    end

    return copy
end

local function isItemAllowed(itemName)
    if type(itemName) ~= 'string' then
        return false
    end

    return not (Config.Blacklist and Config.Blacklist[itemName] == true)
end

local function hasBlockedSubstring(label)
    local lowered = label:lower()

    for _, value in pairs(Config.BlockedSubstrings or {}) do
        if type(value) == 'string' and value ~= '' and lowered:find(value:lower(), 1, true) then
            return true
        end
    end

    return false
end

local function validateLabel(label)
    label = trim(label)

    if label == '' then
        if Config.AllowClear then
            return true, ''
        end

        return false, Config.Notifications.blankNotAllowed
    end

    if #label < Config.MinLength then
        return false, ('Label must be at least %s character(s).'):format(Config.MinLength)
    end

    if #label > Config.MaxLength then
        return false, ('Label cannot exceed %s character(s).'):format(Config.MaxLength)
    end

    if Config.BlockControlCharacters and label:find('%c') then
        return false, Config.Notifications.invalidCharacters
    end

    if Config.BlockAngleBrackets and label:find('[<>]') then
        return false, Config.Notifications.invalidCharacters
    end

    if Config.BlockTildeFormatting and label:find('~.-~') then
        return false, Config.Notifications.invalidCharacters
    end

    if hasBlockedSubstring(label) then
        return false, Config.Notifications.blockedText
    end

    return true, label
end

local function isRateLimited(source)
    local now = os.time()

    if labelCooldown[source] and now - labelCooldown[source] < 1 then
        return true
    end

    labelCooldown[source] = now
    return false
end

local function preventMentions(value)
    return tostring(value or ''):gsub('@', '@ ')
end

local function clip(value, maxLength)
    value = tostring(value or '')
    maxLength = maxLength or 1024

    if #value <= maxLength then
        return value
    end

    return value:sub(1, maxLength - 3) .. '...'
end

local function getPlayerIdentifiersForLog(source)
    if not Config.Webhook.IncludeIdentifiers then
        return 'Disabled'
    end

    local identifiers = {}
    local count = GetNumPlayerIdentifiers(source) or 0

    for i = 0, count - 1 do
        local identifier = GetPlayerIdentifier(source, i)

        if identifier then
            identifiers[#identifiers + 1] = identifier
        end
    end

    if #identifiers == 0 then
        return 'None found'
    end

    return table.concat(identifiers, '\n')
end

local function getInventorySlotCount(source)
    local inventory

    local success = pcall(function()
        inventory = ox_inventory:GetInventory(source)
    end)

    if not success or type(inventory) ~= 'table' then
        success = pcall(function()
            inventory = ox_inventory:GetInventory(source, false)
        end)
    end

    if success and type(inventory) == 'table' then
        local slots = tonumber(inventory.slots or inventory.maxSlots or inventory.slotCount)

        if slots and slots > 0 then
            return math.floor(slots)
        end
    end

    return nil
end

local function formatSlotPosition(source, slot)
    local totalSlots = getInventorySlotCount(source)

    if totalSlots then
        return ('%s / %s'):format(slot or 'unknown', totalSlots)
    end

    return ('%s / Unknown'):format(slot or 'unknown')
end

local function sendWebhookLog(action, source, item, oldLabel, newLabel, reason)
    local webhook = Config.Webhook or {}

    if not webhook.Enabled or webhook.Url == '' then
        return
    end

    if action == 'applied' and not webhook.LogApplied then return end
    if action == 'cleared' and not webhook.LogCleared then return end
    if action == 'rejected' and not webhook.LogRejected then return end

    local color = webhook.ColorApplied or 65280
    local title = 'Item Label Applied'

    if action == 'cleared' then
        color = webhook.ColorCleared or 16753920
        title = 'Item Label Cleared'
    elseif action == 'rejected' then
        color = webhook.ColorRejected or 16711680
        title = 'Item Label Rejected'
    end

    local playerName = GetPlayerName(source) or ('ID %s'):format(source)
    local itemLabel = item and item.label or 'Unknown'
    local itemName = item and item.name or 'unknown'
    local slot = item and item.slot or 'unknown'
    local count = item and item.count or 'unknown'
    local slotPosition = formatSlotPosition(source, slot)

    local fields = {
        {
            name = 'Player',
            value = clip(('%s (Server ID: %s)'):format(preventMentions(playerName), source), 1024),
            inline = false
        },
        {
            name = 'Item',
            value = clip(('%s `%s`'):format(preventMentions(itemLabel), itemName), 1024),
            inline = false
        },
        {
            name = 'Slot Position',
            value = slotPosition,
            inline = true
        },
        {
            name = 'Item Count',
            value = tostring(count),
            inline = true
        },
        {
            name = 'Previous Label',
            value = clip(preventMentions(oldLabel ~= nil and oldLabel ~= '' and oldLabel or 'None'), 1024),
            inline = false
        }
    }

    if action == 'rejected' then
        fields[#fields + 1] = {
            name = 'Reason',
            value = clip(preventMentions(reason or 'Rejected by validation'), 1024),
            inline = false
        }
    else
        fields[#fields + 1] = {
            name = action == 'cleared' and 'New Label' or 'Applied Label',
            value = clip(preventMentions(newLabel ~= nil and newLabel ~= '' and newLabel or 'Cleared'), 1024),
            inline = false
        }
    end

    fields[#fields + 1] = {
        name = 'Identifiers',
        value = clip(('```%s```'):format(getPlayerIdentifiersForLog(source)), 1024),
        inline = false
    }

    local payload = {
        username = webhook.Username or 'IDS Item Labeler',
        avatar_url = webhook.AvatarUrl ~= '' and webhook.AvatarUrl or nil,
        embeds = {
            {
                title = title,
                color = color,
                fields = fields,
                footer = {
                    text = 'oxinv_custom_modules/item_labeler'
                },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
            }
        }
    }

    PerformHttpRequest(webhook.Url, function(statusCode, responseText)
        if statusCode < 200 or statusCode >= 300 then
            print(('[oxinv_custom_modules/item_labeler] Webhook failed with status %s: %s'):format(statusCode, responseText or ''))
        end
    end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end

RegisterNetEvent('oxinv_custom_modules:item_labeler:setLabel', function(slot, label)
    local source = source

    if not Config.Enabled then return end
    if isRateLimited(source) then return end

    slot = tonumber(slot)

    if not slot then
        notify(source, 'error', Config.Notifications.invalidSlot)
        sendWebhookLog('rejected', source, nil, nil, nil, Config.Notifications.invalidSlot)
        return
    end

    local item = ox_inventory:GetSlot(source, slot)

    if not item then
        notify(source, 'error', Config.Notifications.missingItem)
        sendWebhookLog('rejected', source, nil, nil, nil, Config.Notifications.missingItem)
        return
    end

    if not isItemAllowed(item.name) then
        notify(source, 'error', Config.Notifications.notAllowed)
        sendWebhookLog('rejected', source, item, item.metadata and item.metadata.label or nil, label, Config.Notifications.notAllowed)
        return
    end

    if Config.RequireSingleItem and item.count and item.count > 1 then
        notify(source, 'error', Config.Notifications.splitStack)
        sendWebhookLog('rejected', source, item, item.metadata and item.metadata.label or nil, label, Config.Notifications.splitStack)
        return
    end

    local valid, result = validateLabel(label)

    if not valid then
        notify(source, 'error', result)
        sendWebhookLog('rejected', source, item, item.metadata and item.metadata.label or nil, label, result)
        return
    end

    local metadata = copyMetadata(item.metadata)
    local previousLabel = metadata.label

    if result == '' then
        metadata.label = nil

        if Config.StoreAuditMetadata then
            metadata[Config.AuditMetadataKeys.customFlag] = nil
            metadata[Config.AuditMetadataKeys.labeledBy] = nil
            metadata[Config.AuditMetadataKeys.labeledAt] = nil
        end

        ox_inventory:SetMetadata(source, slot, metadata)
        notify(source, 'success', Config.Notifications.cleared)
        sendWebhookLog('cleared', source, item, previousLabel, nil, nil)
        return
    end

    metadata.label = result

    if Config.StoreAuditMetadata then
        metadata[Config.AuditMetadataKeys.customFlag] = true
        metadata[Config.AuditMetadataKeys.labeledBy] = GetPlayerName(source) or ('ID %s'):format(source)
        metadata[Config.AuditMetadataKeys.labeledAt] = os.time()
    end

    ox_inventory:SetMetadata(source, slot, metadata)
    notify(source, 'success', Config.Notifications.applied:format(result))
    sendWebhookLog('applied', source, item, previousLabel, result, nil)
end)

AddEventHandler('playerDropped', function()
    labelCooldown[source] = nil
end)
