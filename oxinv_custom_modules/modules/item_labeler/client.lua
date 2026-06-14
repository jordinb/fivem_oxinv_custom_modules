local Config = Config and Config.Modules and Config.Modules.ItemLabeler or {}
if Config.Enabled == false then return end

local isLabelDialogOpen = false
local savedFreezeState = nil
local savedInvBusyState = nil

local function notify(type, description)
    lib.notify({
        type = type or 'inform',
        description = description
    })
end

local function normaliseSlot(slot)
    if type(slot) == 'number' then
        return slot
    end

    if type(slot) == 'table' then
        if type(slot.slot) == 'number' then
            return slot.slot
        end

        if type(slot.slot) == 'string' then
            local parsed = tonumber(slot.slot)
            if parsed then return parsed end
        end
    end

    if type(slot) == 'string' then
        local parsed = tonumber(slot)
        if parsed then return parsed end
    end

    return nil
end

local function setInventoryBusy(state)
    if not Config.SetInventoryBusyDuringDialog then return end

    pcall(function()
        if state then
            savedInvBusyState = LocalPlayer.state.invBusy
            LocalPlayer.state:set('invBusy', true, true)
            return
        end

        LocalPlayer.state:set('invBusy', savedInvBusyState == true, true)
        savedInvBusyState = nil
    end)
end

local function setPlayerFrozen(state)
    if not Config.FreezePlayerDuringDialog then return end

    local ped = PlayerPedId()

    if state then
        savedFreezeState = IsEntityPositionFrozen(ped)
        FreezeEntityPosition(ped, true)
        return
    end

    if savedFreezeState == false then
        FreezeEntityPosition(ped, false)
    end

    savedFreezeState = nil
end

local function disableConfiguredControls()
    if Config.DisableAllControlsDuringDialog then
        DisableAllControlActions(0)
        DisableAllControlActions(1)
        DisableAllControlActions(2)
        return
    end

    for _, control in ipairs(Config.DisabledControls or {}) do
        DisableControlAction(0, control, true)
        DisableControlAction(1, control, true)
        DisableControlAction(2, control, true)
    end
end

local function startDialogLock()
    if isLabelDialogOpen then return false end

    isLabelDialogOpen = true
    setInventoryBusy(true)
    setPlayerFrozen(true)

    CreateThread(function()
        while isLabelDialogOpen do
            if Config.DisableControlsDuringDialog then
                disableConfiguredControls()
            end

            Wait(0)
        end
    end)

    return true
end

local function stopDialogLock()
    if not isLabelDialogOpen then return end

    isLabelDialogOpen = false
    setPlayerFrozen(false)
    setInventoryBusy(false)
end

local function openLabelDialog(slot)
    if not Config.Enabled then return end

    if isLabelDialogOpen then
        notify('error', Config.Notifications.dialogAlreadyOpen)
        return
    end

    local slotId = normaliseSlot(slot)

    if not slotId then
        notify('error', Config.Notifications.invalidSlot)
        return
    end

    if not startDialogLock() then return end

    local input = lib.inputDialog('Label Item', {
        {
            type = 'input',
            label = 'Custom Label',
            description = Config.AllowClear and 'Leave blank to clear the custom label.' or nil,
            required = not Config.AllowClear,
            min = Config.AllowClear and 0 or Config.MinLength,
            max = Config.MaxLength,
        }
    })

    stopDialogLock()

    if not input then return end

    TriggerServerEvent('oxinv_custom_modules:item_labeler:setLabel', slotId, input[1] or '')
end

RegisterNetEvent('oxinv_custom_modules:item_labeler:openLabelDialog', openLabelDialog)

exports('labelItem', function(slot)
    openLabelDialog(slot)
end)


AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    stopDialogLock()
end)
