local TendHerbalistPlanter = radiant.class()

TendHerbalistPlanter.name = 'tend herbalist planter'
TendHerbalistPlanter.does = 'stonehearth_ace:tend_herbalist_planter'
TendHerbalistPlanter.args = {}
TendHerbalistPlanter.priority = {0, 1}

local function _tend_filter_fn(player_id, level, item)
   if not item or not item:is_valid() then
      return false
   end

   if radiant.entities.get_player_id(item) ~= player_id then
      return false
   end

   local planter = item:get_component('stonehearth_ace:herbalist_planter')
   return planter and planter:is_tendable(level)
end

local function _tend_rating_fn(tend_soft_cooldown, item)
   local rating = 0
   local planter = item:get_component('stonehearth_ace:herbalist_planter')
   if planter then
      local time = stonehearth.calendar:get_elapsed_time() - planter:get_last_tended()
      rating = math.min(1, time / tend_soft_cooldown)
   end
   return rating
end

function TendHerbalistPlanter:start_thinking(ai, entity, args)
   local player_id = radiant.entities.get_work_player_id(entity)
   local tend_soft_cooldown = stonehearth.calendar:parse_duration(stonehearth.constants.herbalist_planters.TEND_SOFT_COOLDOWN)
   local job_level = entity:get_component('stonehearth:job'):get_current_job_level()

   local filter_fn = stonehearth.ai:filter_from_key('stonehearth:tend_herbalist_planter', player_id .. '|' .. job_level, function(item)
         return _tend_filter_fn(player_id, job_level, item)
      end)
      
   local rating_fn = function(item)
         return _tend_rating_fn(tend_soft_cooldown, item)
      end

   -- only abort on level up if we haven't found a planter to tend yet
   -- (we want to abort on level up so we can re-filter all planters that we're now of an appropriate level to tend)
   local should_abort_on_level_up = function()
         return not self._started
      end

   if not ai.CURRENT.carrying then
      ai:set_think_output({
         tend_filter_fn = filter_fn,
         tend_rating_fn = rating_fn,
         owner_player_id = player_id,
         should_abort_on_level_up = should_abort_on_level_up
      })
   end
end

function TendHerbalistPlanter:start(ai, entity, args)
   self._started = true
end

function TendHerbalistPlanter:stop(ai, entity, args)
   self._started = nil
end

function TendHerbalistPlanter:compose_utility(entity, self_utility, child_utilities, current_activity)
   return child_utilities:get('stonehearth:find_best_reachable_entity_by_type')
end

local ai = stonehearth.ai
return ai:create_compound_action(TendHerbalistPlanter)
         :execute('stonehearth:abort_on_event_triggered', {
            source = ai.ENTITY,
            event_name = 'stonehearth:work_order:job:work_player_id_changed',
         })
         :execute('stonehearth:abort_on_event_triggered', {
            source = ai.ENTITY,
            event_name = 'stonehearth:level_up',
            filter_fn = ai.BACK(2).should_abort_on_level_up
         })
         :execute('stonehearth:wait_for_town_inventory_space')
         :execute('stonehearth:find_best_reachable_entity_by_type', {
            filter_fn = ai.BACK(4).tend_filter_fn,
            rating_fn = ai.BACK(4).tend_rating_fn,
            description = 'finding tendable herbalist planters',
            owner_player_id = ai.BACK(4).owner_player_id
         })
         :execute('stonehearth:abort_on_reconsider_rejected', {
            filter_fn = ai.BACK(5).tend_filter_fn,
            item = ai.BACK(1).item
         })
         :execute('stonehearth:reserve_entity', {
            entity = ai.BACK(2).item
         })
         :execute('stonehearth:find_path_to_reachable_entity', {
            destination = ai.BACK(3).item
         })
         :execute('stonehearth:follow_path', {
            path = ai.PREV.path,
            stop_distance = ai.CALL(radiant.entities.get_harvest_range, ai.ENTITY),
         })
         :execute('stonehearth_ace:tend_herbalist_planter_adjacent', {
            planter = ai.BACK(5).item
         })
