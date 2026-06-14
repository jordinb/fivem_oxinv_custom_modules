# oxinv_custom_modules

Combined `ox_inventory` addon resource containing the former standalone resources as isolated modules:

- `modules/engraving` - limited-use engraving machine that writes engraving metadata onto target items.
- `modules/item_labeler` - right-click item button flow for setting or clearing `metadata.label`.

## Dependencies

- `ox_lib`
- `ox_inventory`

## Installation

1. Drop the `oxinv_custom_modules` folder into your server resources.
2. Add this after `ox_lib` and `ox_inventory` in `server.cfg`:

```cfg
ensure oxinv_custom_modules
```

3. Install the ox_inventory item/button snippets from:

```txt
install/ox_inventory/data/oxinv_custom_modules_items_and_buttons.lua
```

4. Copy the icon file:

```txt
from: oxinv_custom_modules/install/ox_inventory/web/images/engraving_machine.png
to:   ox_inventory/web/images/engraving_machine.png
```

5. Restart `ox_inventory`, then start/restart `oxinv_custom_modules`.

## Important export changes

Because both systems now run from one resource, ox_inventory item exports must point to `oxinv_custom_modules`.

### Engraving machine item export

```lua
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
```

### Item labeler button export

```lua
buttons = {
    {
        label = 'Label',
        action = function(slot)
            exports.oxinv_custom_modules:labelItem(slot)
        end
    }
}
```

## Configuration

The global config has been namespaced so each module is isolated:

```lua
Config.Modules.Engraving
Config.Modules.ItemLabeler
```

Edit each module directly:

```txt
modules/engraving/config.lua
modules/item_labeler/config.lua
```

Each module has its own `Enabled` toggle:

```lua
Module.Enabled = true
```

## Module: Engraving

The engraving module keeps the previous `oxinv_custom_modules` behavior:

- Uses the `engraving_machine` ox_inventory item.
- Allows choosing a target slot and custom engraving text.
- Stores internal engraving/audit metadata.
- Supports optional tooltip display fields.
- Supports optional description fallback for ox_inventory builds where `displayMetadata` is unreliable.
- Handles final durability use where ox_inventory may consume/delete the machine before the `usedItem` server export fires.
- Cancels cleanly when the progressbar is cancelled, without consuming durability or leaving the player locked.

### ACE permissions

```cfg
add_ace group.admin engraving.overwrite allow
add_ace group.admin engraving.stacks allow
```

## Module: Item Labeler

The item labeler keeps the previous `oxinv_custom_modules` behavior:

- Right-click item button opens an ox_lib input dialog.
- Sets or clears `metadata.label`.
- Requires single-item stacks by default.
- Uses a blacklist safety net instead of a whitelist.
- Locks movement/interactions while the dialog is open.
- Logs applied/cleared/rejected actions to Discord when webhook logging is enabled.
- Displays slot position using the actual ox_inventory slot count where available.

## Webhook setup

Webhook URLs were intentionally left blank in the merged package. Set them inside each module config:

```lua
Module.Webhook = {
    Enabled = true,
    Url = 'https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE'
}
```

## Migration checklist

- Remove/disable the old standalone `oxinv_custom_modules` and `oxinv_custom_modules` resources.
- Replace old item exports:
  - `oxinv_custom_modules.engraving_machine` -> `oxinv_custom_modules.engraving_machine`
  - `exports.oxinv_custom_modules:labelItem(slot)` -> `exports.oxinv_custom_modules:labelItem(slot)`
- Keep only one copy of the item/button snippets in `ox_inventory/data/items.lua`.
- Copy the icon into `ox_inventory/web/images/engraving_machine.png`.
- Restart `ox_inventory` after editing item definitions.

## File layout

```txt
oxinv_custom_modules/
├── fxmanifest.lua
├── config.lua
├── modules/
│   ├── engraving/
│   │   ├── config.lua
│   │   ├── client.lua
│   │   └── server.lua
│   └── item_labeler/
│       ├── config.lua
│       ├── client.lua
│       └── server.lua
└── install/
    ├── ox_inventory/
    │   ├── data/
    │   │   ├── engraving_machine_item.lua
    │   │   └── oxinv_custom_modules_items_and_buttons.lua
    │   └── web/images/engraving_machine.png
    └── examples/
        ├── item_labeler_button_examples.lua
        └── optional_ox_inventory_metadata_display_fallback.lua
```
