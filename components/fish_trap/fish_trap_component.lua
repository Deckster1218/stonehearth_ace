--[[
   this is a server and client component
   additionally, it's found on the ghost entity for rendering purposes,
   so functionality should be avoided if "stonehearth:ghost_form" component is present

   persistent timer for spawning fish to maybe get trapped

   several different states:
      - normal, waiting for fish to be trapped
      - trap triggered, waiting for trapper to come collect (if something trapped) and reset the trap
      - trap triggered, waiting for trapper to come transform it into a trapped fish entity (if something trapped) and reset the trap
]]

local water_lib = require 'stonehearth_ace.lib.water.water_lib'

local FishTrapComponent = class()

local log = radiant.log.create_logger('fish_trap')

function FishTrapComponent:initialize()
   self._json = radiant.entities.get_json(self)
   self._square_radius = self._json.square_radius or 5

   self._sv._is_capture_enabled = false
end

function FishTrapComponent:create()
   self._is_create = true
end

function FishTrapComponent:post_activate()
   if radiant.is_server then
      self._parent_listener = self._entity:add_component('mob'):trace_parent('fish trap placed')
         :on_changed(function(parent)
            if parent then
               self:_perform_server_setup()
            end
         end)
         :push_object_state()
   end
end

function FishTrapComponent:_perform_server_setup()
   self:_destroy_parent_listener()

   local biome = stonehearth.world_generation:get_biome_alias()
   local settings = radiant.shallow_copy(self._json)
   
   local biome_settings = biome and settings.biomes and (settings.biomes[biome] or settings.biomes['*'])
   if biome_settings then
      settings.biomes = nil
      radiant.util.merge_into_table(settings, biome_settings)
   end
   self._biome_settings = settings
   
   self._season_listener = radiant.events.listen(stonehearth.seasons, 'stonehearth:seasons:changed', function()
         self:_update_settings_for_season()
         self:_recalc_effective_water_volume()
      end)
   self:_update_settings_for_season()
   self:recheck_water_entity(true)

   if not self._entity:get_component('stonehearth:ghost_form') then
      self._transform_listener = radiant.events.listen(self._entity, 'stonehearth_ace:on_transformed', function()
         self:reset_trap()
      end)

      if self._is_create then
         self:reset_trap()
      else
         self:_drop_trap()
         self:_run_trip_effects()
      end
   end
end

function FishTrapComponent:_update_settings_for_season()
   local season = stonehearth.seasons:get_current_season() or {}
   local settings = radiant.shallow_copy(self._biome_settings)
   
   local season_settings = season and season.id and settings.seasons and (settings.seasons[season.id] or settings.seasons['*'])
   if season_settings then
      settings.seasons = nil
      radiant.util.merge_into_table(settings, season_settings)
   end
   self._settings = settings

   self._min_effective_volume = settings.min_effective_water_volume or stonehearth.constants.trapping.fish_traps.MIN_EFFECTIVE_WATER_VOLUME
end

function FishTrapComponent:destroy()
   self:_destroy_listeners()
   self:_destroy_trap_timer()
   self:_destroy_trap_entity()

   if radiant.is_server then
      if self._sv.water_entity and self._sv.water_entity:is_valid() then
         local entity_id = self._entity:get_id()
         local water_id = self._sv.water_entity:get_id()
         stonehearth.trapping:unregister_fish_trap(entity_id, water_id)
         stonehearth_ace.water_signal:unregister_water_change_listener(entity_id, water_id)
      end
   end
end

function FishTrapComponent:_destroy_listeners()
   self:_destroy_parent_listener()
   self:_destroy_season_listener()
   self:_destroy_transform_listener()
end

function FishTrapComponent:_destroy_parent_listener()
   if self._parent_listener then
      self._parent_listener:destroy()
      self._parent_listener = nil
   end
end

function FishTrapComponent:_destroy_season_listener()
   if self._season_listener then
      self._season_listener:destroy()
      self._season_listener = nil
   end
end

function FishTrapComponent:_destroy_transform_listener()
   if self._transform_listener then
      self._transform_listener:destroy()
      self._transform_listener = nil
   end
end

function FishTrapComponent:_destroy_trap_entity()
   if self._sv._trap_entity then
      radiant.entities.destroy_entity(self._sv._trap_entity)
      self._sv._trap_entity = nil
   end
end

function FishTrapComponent:_ensure_trap_timer()
   if not self._sv.trap_tripped and self:_get_effective_volume() > self._min_effective_volume then
      if not self._sv._trap_timer and self._settings.trap_timer then
         self._sv._trap_timer = stonehearth.calendar:set_persistent_timer('fish_trap trip timer', self._settings.trap_timer, radiant.bind(self, '_trip_trap'))
      end
   else
      self:_destroy_trap_timer()
   end
end

function FishTrapComponent:_destroy_trap_timer()
   if self._sv._trap_timer then
      if self._sv._trap_timer.destroy then
         self._sv._trap_timer:destroy()
      end
      self._sv._trap_timer = nil
   end
end

function FishTrapComponent:_trip_trap()
   self:_destroy_trap_timer()

   self._sv.trap_tripped = true
   self.__saved_variables:mark_changed()

   self:_run_trip_effects()
   self:_update_description()
   self:_update_transform_options()
end

function FishTrapComponent:_run_trip_effects()
   if self._sv.trap_tripped then
      self:_stop_trip_effects()
      if self._settings.trip_effect then
         self._trip_effect = radiant.effects.run_effect(self._entity, self._settings.trip_effect)
      end
      if self._settings.trap_tripped_effect then
         self:_ensure_trap_entity()
         self._trap_tripped_effect = radiant.effects.run_effect(self._sv._trap_entity, self._settings.trap_tripped_effect)
      end
   end
end

function FishTrapComponent:_stop_trip_effects()
   if self._trip_effect then
      self._trip_effect:stop()
      self._trip_effect = nil
   end
   if self._trap_tripped_effect then
      self._trap_tripped_effect:stop()
      self._trap_tripped_effect = nil
   end
end

function FishTrapComponent:_run_raise_trap_effects()
   self:_stop_raise_trap_effects()
   if self._settings.raise_trap_effect then
      self._raise_trap_effect = radiant.effects.run_effect(self._entity, self._settings.raise_trap_effect)
   end
   if self._settings.trap_raising_effect then
      self:_ensure_trap_entity()
      self._trap_raising_effect = radiant.effects.run_effect(self._sv._trap_entity, self._settings.trap_raising_effect)
   end
end

function FishTrapComponent:_stop_raise_trap_effects()
   if self._raise_trap_effect then
      self._raise_trap_effect:stop()
      self._raise_trap_effect = nil
   end
   if self._trap_raise_trap_effect then
      self._trap_raise_trap_effect:stop()
      self._trap_raise_trap_effect = nil
   end
end

function FishTrapComponent:_run_open_trap_effects()
   self:_stop_open_trap_effects()
   if self._settings.open_trap_effect then
      self._open_trap_effect = radiant.effects.run_effect(self._entity, self._settings.open_trap_effect)
   end
   if self._settings.trap_opening_effect then
      self:_ensure_trap_entity()
      self._trap_opening_effect = radiant.effects.run_effect(self._sv._trap_entity, self._settings.trap_opening_effect)
   end
end

function FishTrapComponent:_stop_open_trap_effects()
   if self._open_trap_effect then
      self._open_trap_effect:stop()
      self._open_trap_effect = nil
   end
   if self._trap_opening_effect then
      self._trap_opening_effect:stop()
      self._trap_opening_effect = nil
   end
end

function FishTrapComponent:_run_lower_trap_effects()
   self:_stop_lower_trap_effects()
   if self._settings.lower_trap_effect then
      self._lower_trap_effect = radiant.effects.run_effect(self._entity, self._settings.lower_trap_effect)
   end
   if self._settings.trap_lowering_effect then
      self:_ensure_trap_entity()
      self._trap_lowering_effect = radiant.effects.run_effect(self._sv._trap_entity, self._settings.trap_lowering_effect)
   end
end

function FishTrapComponent:_stop_lower_trap_effects()
   if self._lower_trap_effect then
      self._lower_trap_effect:stop()
      self._lower_trap_effect = nil
   end
   if self._trap_lowering_effect then
      self._trap_lowering_effect:stop()
      self._trap_lowering_effect = nil
   end
end

function FishTrapComponent:reset_trap()
   self:_stop_trip_effects()
   self._sv.trap_tripped = false
   self.__saved_variables:mark_changed()

   self:_drop_trap()
   self:_ensure_trap_timer()
   self:_update_description()
end

function FishTrapComponent:_ensure_trap_entity()
   if not self._sv._trap_entity then
      local trap = radiant.entities.create_entity(self._json.trap_uri or 'stonehearth_ace:trapper:fish_trap', {ignore_gravity = true, owner = self._entity})
      radiant.terrain.place_entity_at_exact_location(trap, radiant.entities.get_grid_in_front(self._entity), {force_iconic = false})
      radiant.entities.turn_to(trap, (radiant.entities.get_facing(self._entity) + 180) % 360)

      self._sv._trap_entity = trap
   end
end

function FishTrapComponent:_drop_trap()
   self:_ensure_trap_entity()

   -- if the trap is already dropped, we don't need to do anything
   local destination = radiant.terrain.get_standable_point(radiant.entities.get_grid_in_front(self._entity))
   if self._sv.water_entity and self._sv.water_entity:is_valid() then
      local comp_data = radiant.entities.get_component_data(self._sv._trap_entity, 'stonehearth_ace:aquatic_object')
      local float_offset = comp_data and comp_data.floating_object and comp_data.floating_object.vertical_offset or 0
      destination.y = math.max(destination.y, self._sv.water_entity:get_component('stonehearth:water'):get_water_level() + float_offset)
   end
   if radiant.entities.get_world_location(self._sv._trap_entity) == destination then
      return
   end

   self:_run_lower_trap_effects()

   self._sv._trap_entity:add_component('stonehearth_ace:entity_mover')
      :set_destinations({destination})
      :set_movement_type(stonehearth.constants.entity_mover.movement_types.DIRECT)
      :set_facing_type(stonehearth.constants.entity_mover.facing_types.NONE)
      :set_speed(5)
      :start_nonpersistent_movement(nil, function()
            self:_stop_lower_trap_effects()
            self._sv._trap_entity:add_component('stonehearth_ace:aquatic_object'):set_float_enabled(true)
         end)
end

function FishTrapComponent:_prep_raise_trap()
   self:_ensure_trap_entity()

   self._sv._trap_entity:add_component('stonehearth_ace:entity_mover')
      :stop_movement()
      :set_destinations({radiant.entities.get_grid_in_front(self._entity)})
      :set_movement_type(stonehearth.constants.entity_mover.movement_types.DIRECT)
      :set_facing_type(stonehearth.constants.entity_mover.facing_types.NONE)
      :set_speed(2)
end

function FishTrapComponent:raise_trap(finish_cb)
   self:_prep_raise_trap()
   self:_run_raise_trap_effects()

   local callback = function()
      self:_stop_raise_trap_effects()
      self:_run_open_trap_effects()
      finish_cb()
   end

   self._sv._trap_entity:add_component('stonehearth_ace:aquatic_object'):set_float_enabled(false)
   self._sv._trap_entity:add_component('stonehearth_ace:entity_mover')
      :start_nonpersistent_movement(nil, callback)
end

function FishTrapComponent:_get_trap_move_time()
   self:_ensure_trap_entity()

   return self._sv._trap_entity:add_component('stonehearth_ace:entity_mover'):get_estimated_direct_time_to_next_destination()
end

function FishTrapComponent:_update_transform_options()
   if self._sv.trap_tripped then
      local overrides = {
         additional_items_filter_script = 'stonehearth_ace:loot_table:filter_scripts:no_items_with_property_value',
         additional_items_filter_args = {
            min_water_volume = { {
               comparator = ">",
               value = self:_get_effective_volume()
            } }
         }
      }
      if self._sv._is_capture_enabled then
         overrides.additional_items = stonehearth.trapping:get_fish_trap_capture_loot_table()
      else
         overrides.additional_items = stonehearth.trapping:get_fish_trap_harvest_loot_table()
      end
      self:_prep_raise_trap()
      overrides.transforming_effect_duration = self:_get_trap_move_time() + (self._settings.harvest_effect_time or 90)
      overrides.start_transforming_script = 'stonehearth_ace:scripts:transform:fish_trap'

      local transform_comp = self._entity:add_component('stonehearth_ace:transform')
      transform_comp:add_option_overrides(overrides)
      transform_comp:request_transform(self._entity:get_player_id(), true) -- true to ignore duplicate requests
   end
end

function FishTrapComponent:recheck_water_entity(is_startup)
   local water, origin = water_lib.get_water_in_front_of_entity(self._entity)
   self:set_water_entity(water, origin, is_startup)
end

function FishTrapComponent:set_water_entity(water, origin, is_startup)
   local water_id = water and water:get_id()
   local prev_water_id = self._sv.water_entity and self._sv.water_entity:is_valid() and self._sv.water_entity:get_id()

   if is_startup or water_id ~= prev_water_id then
      if radiant.is_server then
         local entity_id = self._entity:get_id()
         
         if prev_water_id then
            stonehearth.trapping:unregister_fish_trap(entity_id, prev_water_id)
         end

         if water then
            stonehearth.trapping:register_fish_trap(self._entity, water)
            stonehearth_ace.water_signal:register_water_change_listener(entity_id, water_id, function()
                  self:_update_water_region()
               end)
         else
            stonehearth_ace.water_signal:unregister_water_change_listener(entity_id, water_id)
         end
      end

      self._sv.water_entity = water
      self._sv.origin = origin
      self:_update_water_region()
   elseif origin ~= self._sv.origin then
      self._sv.origin = origin
      self:_update_water_region()
   end
end

function FishTrapComponent:get_water_region()
   return self._sv.water_region
end

function FishTrapComponent:_update_water_region()
   if self._sv.water_entity then
      if not self._sv.water_entity:is_valid() then
         self._sv.water_entity = nil
         self:recheck_water_entity()
         return
      end
      self._sv.water_region = water_lib.get_contiguous_water_subregion(self._sv.water_entity, self._sv.origin, self._square_radius)
   else
      self._sv.water_region = nil
   end
   self.__saved_variables:mark_changed()

   if radiant.is_server then
      -- if there's no more water here, just destroy the trap?
      if not self._sv.water_region or self._sv.water_region:empty() then
         radiant.entities.destroy_entity(self._entity)
      else
         self:_recalc_effective_water_volume()
      end
   end
end

-- called by trapping service when traps may have been added or removed from this water region
function FishTrapComponent:recheck_effective_water_volume()
   self:_recalc_effective_water_volume()
end

function FishTrapComponent:_get_effective_volume()
   return self._effective_water_volume
end

function FishTrapComponent:_recalc_effective_water_volume()
   if self._sv.water_region then
      local volume = self._sv.water_region:get_area()

      -- determine how many traps have their region intersect with this one
      local traps = stonehearth.trapping:get_fish_traps_in_water(self._sv.water_entity:get_id())
      local num_intersect = 1   -- of course there should always be at least 1: this one!
      local entity_id = self._entity:get_id()
      
      for id, trap in pairs(traps) do
         if id ~= entity_id and not trap:get_component('stonehearth:ghost_form') then
            local region = trap:get_component('stonehearth_ace:fish_trap'):get_water_region()
            if region and region:intersects_region(self._sv.water_region) then
               num_intersect = num_intersect + 1
            end
         end
      end

      self._effective_water_volume = volume / num_intersect
      self._conflicting_traps = num_intersect - 1
   else
      self._effective_water_volume = 0
      self._conflicting_traps = 0
   end

   self:_ensure_trap_timer()
   self:_update_description()
end

function FishTrapComponent:_update_description()
   -- update description based on status, volume, and conflicting traps
   local description
   if self._sv.trap_tripped then
      description = self._settings.trap_tripped_description or 'i18n(stonehearth_ace:jobs.trapper.fish_trap.trap_tripped_description)'
   elseif self._conflicting_traps > 0 then
      description = self._settings.conflicting_traps_description or 'i18n(stonehearth_ace:jobs.trapper.fish_trap.conflicting_traps_description)'
   elseif self._settings.low_water_volume and self._settings.low_water_volume > self._effective_water_volume then
      description = self._settings.low_water_description or 'i18n(stonehearth_ace:jobs.trapper.fish_trap.low_water_description)'
   elseif self._settings.high_water_volume and self._settings.high_water_volume <= self._effective_water_volume then
      description = self._settings.high_water_description or 'i18n(stonehearth_ace:jobs.trapper.fish_trap.high_water_description)'
   else
      local catalog_data = stonehearth.catalog:get_catalog_data(self._entity:get_uri())
      description = catalog_data and catalog_data.description or 'i18n(stonehearth_ace:jobs.trapper.fish_trap.description)'
   end

   radiant.entities.set_description(self._entity, description)
end

function FishTrapComponent:trace(reason)
   return self.__saved_variables:trace(reason)
end

function FishTrapComponent:is_capture_enabled()
   return self._sv._is_capture_enabled
end

function FishTrapComponent:set_capture_enabled(enabled)
   if self._sv._is_capture_enabled ~= enabled then
      self._sv._is_capture_enabled = enabled

      local commands = self._entity:add_component('stonehearth:commands')
      if enabled then
         commands:remove_command('stonehearth_ace:commands:trapper:toggle_fish_trap_capture')
         commands:add_command('stonehearth_ace:commands:trapper:toggle_fish_trap_harvest')
      else
         commands:remove_command('stonehearth_ace:commands:trapper:toggle_fish_trap_harvest')
         commands:add_command('stonehearth_ace:commands:trapper:toggle_fish_trap_capture')
      end

      self:_update_transform_options()
   end
end



return FishTrapComponent