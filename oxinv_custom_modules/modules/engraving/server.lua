local Config = Config and Config.Modules and Config.Modules.Engraving or {}
if Config.Enabled == false then return end

local ox_inventory = exports.ox_inventory
local pending = {}
local refreshCooldown = {}
local debugCooldown = {}

local function notify(source, description, notifyType)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Engraving Machine',
        description = description,
        type = notifyType or 'inform'
    })
end

local function cleanText(value)
    if type(value) ~= 'string' then return nil end

    value = value:gsub('[%z\1-\31\127]', '')
    value = value:gsub('[<>`]', '')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    value = value:gsub('%s+', ' ')

    if #value < Config.MinLength then return nil end

    if #value > Config.MaxLength then return nil end

    return value
end

local function isBlockedItem(itemName)
    return itemName and (Config.BlockedItems or {})[itemName] == true
end

local function copyValue(value, seen)
    if type(value) ~= 'table' then return value end

    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy

    for key, child in pairs(value) do
        copy[copyValue(key, seen)] = copyValue(child, seen)
    end

    return copy
end

local function copyMetadata(item)
    if type(item) ~= 'table' or type(item.metadata) ~= 'table' then return {} end
    return copyValue(item.metadata)
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

local function getEngravingText(metadata)
    if type(metadata) ~= 'table' then return nil end

    local value = metadata[Config.InternalEngravingKey]
    if value == nil or value == '' then
        value = metadata[Config.MetadataKey]
    end

    if value == nil or value == '' then return nil end
    return tostring(value)
end

local function getIdentifierMap(source)
    local identifiers = {}
    local rawIdentifiers = GetPlayerIdentifiers(source)

    for i = 1, #rawIdentifiers do
        local identifier = rawIdentifiers[i]
        local separator = identifier:find(':', 1, true)

        if separator then
            identifiers[identifier:sub(1, separator - 1)] = identifier
        end
    end

    return identifiers
end

local function getAudit(metadata)
    if type(metadata) ~= 'table' then return {} end

    local audit = metadata[Config.InternalAuditKey]
    if type(audit) ~= 'table' then
        audit = {}
    end

    -- Migrate old public audit fields into the hidden audit table.
    if (audit.by == nil or audit.by == '') and metadata[Config.EngravedByKey] then
        audit.by = metadata[Config.EngravedByKey]
        audit.playerName = metadata[Config.EngravedByKey]
    end

    if (audit.at == nil or audit.at == '') and metadata[Config.EngravedAtKey] then
        audit.at = metadata[Config.EngravedAtKey]
    end

    return audit
end

local function hasAuditValues(audit)
    return type(audit) == 'table' and next(audit) ~= nil
end

local function appendLine(lines, label, value)
    if value == nil or value == '' then return end
    lines[#lines + 1] = ('%s: %s'):format(label, tostring(value))
end

local function escapePattern(value)
    return tostring(value):gsub('([^%w])', '%%%1')
end

local function isGeneratedTooltipLine(line)
    local labels = {
        Config.MetadataLabel,
        Config.EngravedByLabel,
        Config.EngravedAtLabel,
    }

    for i = 1, #labels do
        local label = labels[i]
        if label and line:match('^%s*' .. escapePattern(label) .. '%s*:') then
            return true
        end
    end

    return false
end

local function stripGeneratedTooltipLines(description)
    if type(description) ~= 'string' or description == '' then return description end

    local keep = {}

    for line in (description .. '\n'):gmatch('(.-)\n') do
        if line ~= '' and not isGeneratedTooltipLine(line) then
            keep[#keep + 1] = line
        end
    end

    if #keep == 0 then return nil end
    return table.concat(keep, '\n')
end

local function applyDescriptionFallback(metadata)
    Config.Tooltip = Config.Tooltip or {}

    local audit = getAudit(metadata)
    local engravingText = getEngravingText(metadata)

    if Config.Tooltip.UseDescriptionFallback == false then
        if metadata._engraving_description_managed then
            metadata.description = metadata._engraving_original_description
            metadata._engraving_description_managed = nil
            metadata._engraving_original_description = nil
        else
            metadata.description = stripGeneratedTooltipLines(metadata.description)
        end

        return metadata
    end

    local originalDescription = metadata._engraving_original_description

    if Config.Tooltip.PreserveExistingDescription ~= false then
        if originalDescription == nil and metadata.description and not metadata._engraving_description_managed then
            originalDescription = metadata.description
        end

        originalDescription = stripGeneratedTooltipLines(originalDescription)
        metadata._engraving_original_description = originalDescription
    else
        originalDescription = nil
        metadata._engraving_original_description = nil
    end

    local lines = {}

    if originalDescription and originalDescription ~= '' then
        lines[#lines + 1] = tostring(originalDescription)
    end

    if shouldShowTooltipField(Config.MetadataKey) then
        appendLine(lines, Config.MetadataLabel, engravingText)
    end

    if shouldShowTooltipField(Config.EngravedByKey) then
        appendLine(lines, Config.EngravedByLabel, audit.by or audit.playerName)
    end

    if shouldShowTooltipField(Config.EngravedAtKey) then
        appendLine(lines, Config.EngravedAtLabel, audit.at)
    end

    if #lines > 0 then
        metadata.description = table.concat(lines, Config.Tooltip.DescriptionSeparator or '\n')
        metadata._engraving_description_managed = true
    else
        metadata.description = originalDescription
        metadata._engraving_description_managed = nil
        metadata._engraving_original_description = nil
    end

    return metadata
end

local function createAudit(source)
    local playerName = GetPlayerName(source) or ('ID %s'):format(source)
    local unix = os.time()
    local identifiers = getIdentifierMap(source)

    return {
        by = playerName,
        playerName = playerName,
        source = source,
        identifiers = identifiers,
        license = identifiers.license,
        license2 = identifiers.license2,
        discord = identifiers.discord,
        fivem = identifiers.fivem,
        steam = identifiers.steam,
        at = os.date(Config.TimestampFormat or '!%Y-%m-%d %H:%M:%S UTC', unix),
        iso = os.date('!%Y-%m-%dT%H:%M:%SZ', unix),
        unix = unix,
    }
end

local function syncEngravingMetadata(metadata, source, newText)
    if type(metadata) ~= 'table' then metadata = {} end

    local engravingText = cleanText(newText) or getEngravingText(metadata)

    if engravingText then
        metadata[Config.InternalEngravingKey] = engravingText

        if shouldShowTooltipField(Config.MetadataKey) then
            metadata[Config.MetadataKey] = engravingText
        elseif Config.CleanHiddenTooltipFields ~= false then
            metadata[Config.MetadataKey] = nil
        end
    end

    local audit = getAudit(metadata)

    -- Audit metadata is mandatory internal data used for backend functionality and admin logging.
    if source then
        audit = createAudit(source)
    end

    if hasAuditValues(audit) then
        metadata[Config.InternalAuditKey] = audit
    else
        metadata[Config.InternalAuditKey] = nil
    end

    if shouldShowTooltipField(Config.EngravedByKey) and (audit.by or audit.playerName) then
        metadata[Config.EngravedByKey] = audit.by or audit.playerName
    elseif Config.CleanHiddenTooltipFields ~= false then
        metadata[Config.EngravedByKey] = nil
    end

    if shouldShowTooltipField(Config.EngravedAtKey) and audit.at then
        metadata[Config.EngravedAtKey] = audit.at
    elseif Config.CleanHiddenTooltipFields ~= false then
        metadata[Config.EngravedAtKey] = nil
    end

    applyDescriptionFallback(metadata)

    return metadata
end

local function hasEngravingMetadata(metadata)
    if type(metadata) ~= 'table' then return false end

    return metadata[Config.InternalEngravingKey] ~= nil
        or metadata[Config.MetadataKey] ~= nil
        or metadata[Config.InternalAuditKey] ~= nil
        or metadata[Config.EngravedByKey] ~= nil
        or metadata[Config.EngravedAtKey] ~= nil
        or metadata._engraving_description_managed ~= nil
end

local function validate(source, machineSlot, targetSlot, text, expectedTargetName)
    machineSlot = tonumber(machineSlot)
    targetSlot = tonumber(targetSlot)
    text = cleanText(text)

    if not machineSlot then
        return false, Config.Notify.invalidMachine
    end

    if not targetSlot or machineSlot == targetSlot then
        return false, Config.Notify.invalidTarget
    end

    if not text then
        return false, Config.Notify.invalidText
    end

    local machine = ox_inventory:GetSlot(source, machineSlot)
    if not machine or machine.name ~= Config.MachineItem then
        return false, Config.Notify.invalidMachine
    end

    local target = ox_inventory:GetSlot(source, targetSlot)
    if not target or not target.name or (target.count or 0) < 1 then
        return false, Config.Notify.invalidTarget
    end

    if expectedTargetName and target.name ~= expectedTargetName then
        return false, Config.Notify.invalidTarget
    end

    if isBlockedItem(target.name) then
        return false, Config.Notify.blockedTarget
    end

    local metadata = type(target.metadata) == 'table' and target.metadata or {}
    local existing = getEngravingText(metadata)
    if existing then
        if not Config.AllowReEngrave then
            return false, Config.Notify.alreadyEngraved
        end

        if Config.RequireReEngraveAce and not IsPlayerAceAllowed(source, Config.ReEngraveAcePermission or '') then
            return false, Config.Notify.noPermission
        end
    end

    return true, nil, machine, target, text
end

local function validatePreparedTarget(source, request)
    if type(request) ~= 'table' then
        return false, Config.Notify.failed
    end

    if os.time() > request.expires then
        return false, Config.Notify.failed
    end

    local targetSlot = tonumber(request.targetSlot)
    if not targetSlot then
        return false, Config.Notify.invalidTarget
    end

    local target = ox_inventory:GetSlot(source, targetSlot)
    if not target or not target.name or (target.count or 0) < 1 then
        return false, Config.Notify.invalidTarget
    end

    if request.targetName and target.name ~= request.targetName then
        return false, Config.Notify.invalidTarget
    end

    if isBlockedItem(target.name) then
        return false, Config.Notify.blockedTarget
    end

    local metadata = type(target.metadata) == 'table' and target.metadata or {}
    local existing = getEngravingText(metadata)
    if existing then
        if not Config.AllowReEngrave then
            return false, Config.Notify.alreadyEngraved
        end

        if Config.RequireReEngraveAce and not IsPlayerAceAllowed(source, Config.ReEngraveAcePermission or '') then
            return false, Config.Notify.noPermission
        end
    end

    return true, nil, target, request.text
end

local function hasFullStackEngravePermission(source)
    return IsPlayerAceAllowed(source, Config.FullStackEngraveAcePermission or 'group.admin')
end

local function canCarryItem(source, name, count, metadata)
    local success, result = pcall(function()
        return ox_inventory:CanCarryItem(source, name, count, metadata)
    end)

    return success and result == true
end

local function addInventoryItem(source, name, count, metadata, slot)
    local success, added, response = pcall(function()
        return ox_inventory:AddItem(source, name, count, metadata, slot)
    end)

    if not success then
        print(('^1[oxinv_custom_modules/engraving]^7 AddItem failed: %s'):format(added or 'unknown error'))
        return false, added
    end

    return added == true, response
end

local function removeInventoryItem(source, name, count, metadata, slot)
    local success, removed, response = pcall(function()
        return ox_inventory:RemoveItem(source, name, count, metadata, slot, false, true)
    end)

    if not success then
        print(('^1[oxinv_custom_modules/engraving]^7 RemoveItem failed: %s'):format(removed or 'unknown error'))
        return false, removed
    end

    return removed == true, response
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

local function getIdentifierSummary(source)
    if not Config.Webhook or Config.Webhook.IncludeIdentifiers == false then
        return nil
    end

    local identifiers = getIdentifierMap(source)
    local values = {}
    local orderedKeys = { 'license', 'license2', 'discord', 'fivem', 'steam' }

    for i = 1, #orderedKeys do
        local identifier = identifiers[orderedKeys[i]]
        if identifier then values[#values + 1] = identifier end
    end

    if #values == 0 then return nil end
    return table.concat(values, '\n')
end

local function getItemLabel(item)
    if item.label and item.label ~= '' then
        return item.label
    end

    local ok, itemData = pcall(function()
        return ox_inventory:Items(item.name)
    end)

    if ok and itemData and itemData.label then
        return itemData.label
    end

    return item.name
end

local function sendWebhookLog(source, target, text, previousEngraving, metadata)
    local webhook = Config.Webhook
    if not webhook or webhook.Enabled ~= true or type(webhook.Url) ~= 'string' or webhook.Url == '' then return end

    local audit = getAudit(metadata)
    local playerName = preventMentions(GetPlayerName(source) or ('ID %s'):format(source))
    local itemLabel = getItemLabel(target)
    local fields = {
        { name = 'Player', value = clip(('%s [%s]'):format(playerName, source), 1024), inline = false },
        { name = 'Item', value = clip(('%s (`%s`)'):format(preventMentions(itemLabel), target.name), 1024), inline = true },
        { name = 'Slot', value = tostring(target.slot), inline = true },
        { name = 'Engraving', value = clip(preventMentions(text), 1024), inline = false },
        { name = 'Engraved At', value = tostring(audit.at or 'Unknown'), inline = true },
    }

    if webhook.IncludePreviousEngraving ~= false and previousEngraving and previousEngraving ~= '' then
        fields[#fields + 1] = { name = 'Previous Engraving', value = clip(preventMentions(previousEngraving), 1024), inline = false }
    end

    local identifierSummary = getIdentifierSummary(source)
    if identifierSummary then
        fields[#fields + 1] = { name = 'Identifiers', value = identifierSummary, inline = false }
    end

    local payload = {
        username = webhook.Username or 'Engraving Machine Logs',
        avatar_url = webhook.AvatarUrl ~= '' and webhook.AvatarUrl or nil,
        embeds = {
            {
                title = 'Item Engraved',
                color = tonumber(webhook.Color) or 16753920,
                fields = fields,
                footer = { text = 'oxinv_custom_modules/engraving' },
                timestamp = audit.iso or os.date('!%Y-%m-%dT%H:%M:%SZ')
            }
        }
    }

    PerformHttpRequest(webhook.Url, function(statusCode, responseText)
        statusCode = tonumber(statusCode) or 0

        if statusCode < 200 or statusCode >= 300 then
            print(('^3[oxinv_custom_modules/engraving]^7 Discord webhook returned HTTP %s: %s'):format(statusCode, responseText or ''))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function refreshInventoryMetadata(source, silent)
    local items = ox_inventory:GetInventoryItems(source)
    local changed = 0

    for _, item in pairs(items or {}) do
        local metadata = type(item.metadata) == 'table' and item.metadata or {}

        if hasEngravingMetadata(metadata) then
            local normalized = syncEngravingMetadata(copyMetadata(item), nil, nil)
            ox_inventory:SetMetadata(source, item.slot, normalized)
            changed = changed + 1
        end
    end

    if not silent then
        notify(source, ('%s %s'):format(Config.Notify.repaired, changed > 0 and ('(' .. changed .. ' item(s))') or '(no engraved items found)'), changed > 0 and 'success' or 'inform')
    end

    return changed
end

lib.callback.register('oxinv_custom_modules:engraving:prepare', function(source, machineSlot, targetSlot, engravingText)
    local ok, message, _, target, text = validate(source, machineSlot, targetSlot, engravingText)

    if not ok then
        return false, message
    end

    pending[source] = {
        machineSlot = tonumber(machineSlot),
        targetSlot = tonumber(targetSlot),
        targetName = target.name,
        text = text,
        expires = os.time() + (Config.PendingTimeout or 45),
    }

    return true, Config.Notify.prepared
end)

RegisterNetEvent('oxinv_custom_modules:engraving:cancel', function()
    pending[source] = nil
end)

RegisterNetEvent('oxinv_custom_modules:engraving:refreshEngravedItems', function()
    local src = source
    local now = os.time()

    if refreshCooldown[src] and refreshCooldown[src] > now then return end
    refreshCooldown[src] = now + 10

    refreshInventoryMetadata(src, true)
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
    refreshCooldown[source] = nil
    debugCooldown[source] = nil
end)

exports('engraving_machine', function(event, item, inventory, slot, data)
    local source = inventory and tonumber(inventory.id)
    if not source then return false end

    local request = pending[source]

    if event == 'usingItem' then
        if not request or request.machineSlot ~= slot or os.time() > request.expires then
            pending[source] = nil
            notify(source, Config.Notify.failed, 'error')
            return false
        end

        local ok, message = validate(source, slot, request.targetSlot, request.text, request.targetName)
        if not ok then
            pending[source] = nil
            notify(source, message or Config.Notify.failed, 'error')
            return false
        end

        return
    end

    if event == 'usedItem' then
        if not request then return false end

        -- On the final durability use, ox_inventory may consume/delete the engraving machine
        -- before this callback fires. Do not re-check the machine slot here; it was already
        -- validated in usingItem immediately before the progress/consume step.
        if slot and request.machineSlot ~= slot then
            pending[source] = nil
            notify(source, Config.Notify.failed, 'error')
            return false
        end

        local ok, message, target, text = validatePreparedTarget(source, request)
        pending[source] = nil

        if not ok then
            notify(source, message or Config.Notify.failed, 'error')
            return false
        end

        local metadata = copyMetadata(target)
        local previousEngraving = getEngravingText(metadata)
        local isStack = (target.count or 0) > 1
        local canEngraveStack = hasFullStackEngravePermission(source)

        metadata = syncEngravingMetadata(metadata, source, text)

        if isStack and not canEngraveStack then
            if not canCarryItem(source, target.name, 1, metadata) then
                notify(source, Config.Notify.noSpace or Config.Notify.failed, 'error')
                return false
            end

            local removed = removeInventoryItem(source, target.name, 1, target.metadata, target.slot)
            if not removed then
                notify(source, Config.Notify.failed, 'error')
                return false
            end

            local added = addInventoryItem(source, target.name, 1, metadata)
            if not added then
                -- Best-effort rollback so a failed metadata split does not delete the player's original item.
                addInventoryItem(source, target.name, 1, target.metadata, target.slot)
                notify(source, Config.Notify.failed, 'error')
                return false
            end

            notify(source, Config.Notify.success, 'success')
            sendWebhookLog(source, target, text, previousEngraving, metadata)
            return
        end

        ox_inventory:SetMetadata(source, target.slot, metadata)
        notify(source, Config.Notify.success, 'success')
        sendWebhookLog(source, target, text, previousEngraving, metadata)
        return
    end
end)

RegisterCommand('engravingdebug', function(source)
    if not Config.DebugCommand or Config.DebugCommand.Enabled ~= true then return end

    if source <= 0 then
        return print('^3[oxinv_custom_modules/engraving]^7 /engravingdebug must be run in-game so it can inspect the caller inventory.')
    end

    if not IsPlayerAceAllowed(source, Config.DebugCommand.AcePermission or 'engraving.debug') then
        return notify(source, Config.Notify.noPermission, 'error')
    end

    local now = os.time()
    if debugCooldown[source] and debugCooldown[source] > now then
        return notify(source, Config.Notify.commandCooldown, 'error')
    end

    debugCooldown[source] = now + (tonumber(Config.DebugCooldown) or 300)

    local items = ox_inventory:GetInventoryItems(source)
    local found = false

    for _, item in pairs(items or {}) do
        local metadata = type(item.metadata) == 'table' and item.metadata or {}

        if hasEngravingMetadata(metadata) then
            found = true
            print(('^2[oxinv_custom_modules/engraving]^7 %s slot %s metadata: %s'):format(item.name, item.slot, json.encode(metadata)))
        end
    end

    if not found then
        print(('^3[oxinv_custom_modules/engraving]^7 No engraved items found for player %s.'):format(source))
    end
end, false)

CreateThread(function()
    Wait(1000)

    if GetResourceState('ox_inventory') ~= 'started' then
        print('^1[oxinv_custom_modules/engraving]^7 ox_inventory is not started. Start ox_inventory before this resource.')
        return
    end

    local item = ox_inventory:Items(Config.MachineItem)
    if not item then
        print(('^3[oxinv_custom_modules/engraving]^7 Item "%s" is not registered in ox_inventory/data/items.lua. See install/items.lua.'):format(Config.MachineItem))
        return
    end

    local uses = tonumber(Config.MachineUses) or 10
    if uses < 1 then uses = 10 end

    local expectedConsume = 1 / uses
    local actualConsume = tonumber(item.consume)

    if not actualConsume or math.abs(actualConsume - expectedConsume) > 0.0001 then
        print(('^3[oxinv_custom_modules/engraving]^7 Item "%s" should use consume = %.4f for %s durability uses. Current consume: %s.'):format(Config.MachineItem, expectedConsume, uses, tostring(item.consume)))
    end
end)
