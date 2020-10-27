local AceSimpleCaravan = class()

function AceSimpleCaravan:_accept_trade()
   --TODO: go through the reserved items and nuke them all
   self:_take_items()

   --Add the new items to the space near the banner
   local town = stonehearth.town:get_town(self._sv.player_id)
   local drop_origin = town:get_landing_location()
   if not drop_origin then
      return
   end

   local uris = {}
   uris[self._sv.trade_data.caravan_has] = self._sv.trade_data.caravan_quantity

   --TODO: attach a brief particle effect to the new stuff
   local town = stonehearth.town:get_town(self._sv.player_id)
   local default_storage = town and town:get_default_storage()
   local items = radiant.entities.output_items(uris, drop_origin, 1, 3, { owner = self._sv.player_id }, nil, default_storage, true).spilled
   
   local inventory = stonehearth.inventory:get_inventory(self._sv.player_id)
   for _, item in pairs(items) do
      inventory:add_item_if_not_full(item)
   end
end

return AceSimpleCaravan
