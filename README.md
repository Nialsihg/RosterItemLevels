# RosterItemLevels
Mouseover any character lets you see its item level. Also displays the roles, specs and item levels for the whole group in a dedicated window and allows you to report the data.
#### [Screenshots](https://imgur.com/a/pUwof20)
## Features
* Shows the item level in the tooltip when you mouseover a player.
* Shows the item level, specialization and role of each group member.
* Report window with multiple channels (Guild, Whisper, Whisper Target, Raid, Party, Instance).
* Fully configurable in the dedicated options panel.
## Usage
Mouseover any character will display its item level in the tooltip.  
Left-click the minimap icon or type the command "/ilvls" to toggle on/off the roster window.  
Shift-click the miniamp icon or type the command "/ilvls report" to toggle on/off the report window.
## Important note
You must have at least **one Chat Tab with "System Messages" enabled** for the addon to work properly.
## Technical details
RosterItemLevels is built on top of Freakz command ".ilvl". It sends the command and expects a system message in response. This process is transparent for the user because the addon sets a filter on the chat.
