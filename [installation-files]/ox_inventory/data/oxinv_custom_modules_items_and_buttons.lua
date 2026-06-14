-- oxinv_custom_modules ox_inventory install snippets
-- Add the item entry below to ox_inventory/data/items.lua.
-- Place engraving_machine.png in ox_inventory/web/images/.

-- Add this entry to ox_inventory/data/items.lua
-- Item name: engraving_machine
-- Inventory icon: engraving_machine.png
-- Place the icon file at: ox_inventory/web/images/engraving_machine.png
-- Restart ox_inventory and oxinv_custom_modules after editing.

['engraving_machine'] = {
    label = 'Engraving Machine',
    description = 'A limited-use machine for engraving custom labels onto items.',
    weight = 2500,
    image = 'engraving_machine.png', -- ox_inventory/web/images/engraving_machine.png
    stack = false,
    close = true,
    consume = 0.10, -- 10 uses from full durability (1 / Config.MachineUses). 0.20 = 5 uses, 0.05 = 20 uses.
    decay = true,
    client = {
        export = 'oxinv_custom_modules.engraving_machine',
        usetime = 4500,
        cancel = true,
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
        disable = { move = true, car = true, combat = true }
    },
    server = {
        export = 'oxinv_custom_modules.engraving_machine'
    }
},


-- Add this button to any existing item that should support custom labels.
-- If an item already has buttons, append this entry instead of replacing its existing buttons table.

buttons = {
    {
        label = 'Label',
        action = function(slot)
            exports.oxinv_custom_modules:labelItem(slot)
        end
    }
}
