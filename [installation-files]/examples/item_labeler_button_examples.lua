-- Example full item:

["backpack1"] = {
    label = "Backpack 1",
    weight = 100,
    stack = false,
    close = true,
    client = { image = "backpack1.png" },
    buttons = {
        {
            label = 'Label',
            action = function(slot)
                exports.oxinv_custom_modules:labelItem(slot)
            end
        }
    }
},

-- Add this button to any ox_inventory item that should support custom labels.

buttons = {
    {
        label = 'Label',
        action = function(slot)
            exports.oxinv_custom_modules:labelItem(slot)
        end
    }
},
