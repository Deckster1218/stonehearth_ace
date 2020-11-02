local StorageComponent = require 'stonehearth.components.storage.storage_component'
AceStorageComponent = class()

AceStorageComponent._ace_old_create = StorageComponent.create
function AceStorageComponent:create()
   
   self._is_create = true
   self:_ace_old_create()

end

AceStorageComponent._ace_old_activate = StorageComponent.activate
function AceStorageComponent:activate()   
   
   self:_ace_old_activate()
   
   local json = radiant.entities.get_json(self) or {}
   if self._is_create then
      if json.default_filter then
         self:set_filter(json.default_filter)
      end
      self._sv.is_hidden = json.is_hidden or false -- public inventory that's accessible, but hidden from UI
      -- also set the filter to none if it's hidden storage
      -- if self._sv.is_hidden then
      --    self:_set_filter_to_none()
      -- end
   end

   if json.limit_all_filter ~= false then
      local filter = {}
      local data = radiant.resources.load_json(self._sv.filter_list, true, false)
      
      if data and data.stockpile then
         for _, group in pairs(data.stockpile) do
            if group.categories then
               for _, entry in pairs(group.categories) do
                  if entry.filter then
                     table.insert(filter, entry.filter)
                  end
               end
            end
         end
      end

      self._limited_all_filter = filter
   end

   self._ignore_restock = json.ignore_restock

   local bounds = stonehearth.constants.inventory.input_bins
   local priority_range = bounds.MAX_PRIORITY - bounds.MIN_PRIORITY
   local priority = math.min(math.max(json.priority or 1, bounds.MIN_PRIORITY), bounds.MAX_PRIORITY)
   self._is_input_bin_highest_priority = (priority == bounds.MAX_PRIORITY)
   self._input_bin_priority = (priority - bounds.MIN_PRIORITY) / (priority_range + 1)

   -- communicate this setting to the renderer
	self._sv.render_filter_model = json.render_filter_model
	self._sv.render_filter_model_threshold = json.render_filter_model_threshold or 0.5
   self._sv.reposition_items = json.reposition_items
   self.__saved_variables:mark_changed()
end

AceStorageComponent._ace_old__on_contents_changed = StorageComponent._on_contents_changed
function AceStorageComponent:_on_contents_changed()

	self:_ace_old__on_contents_changed()

	if not self:is_empty() and self._sv.filter and self._sv.render_filter_model then
		if (self._sv.num_items / self._sv.capacity) >= self._sv.render_filter_model_threshold then
			self._entity:get_component('render_info'):set_model_variant(tostring(self._cached_filter_key))
		else
			self._entity:get_component('render_info'):set_model_variant('')
		end
	end

end

function AceStorageComponent:get_limited_all_filter()
   return self._limited_all_filter
end

function AceStorageComponent:get_filter()
   return self._sv.filter or self._limited_all_filter
end

function AceStorageComponent:get_filter_key()
   if not self._cached_filter_key then
      self._cached_filter_key = stonehearth.inventory:get_inventory(radiant.entities.get_player_id(self._entity)):filter_to_key(self._sv.filter)
   end

   return self._cached_filter_key
end

function AceStorageComponent:is_input_bin_highest_priority()
   return self._is_input_bin_highest_priority
end

function AceStorageComponent:get_input_bin_priority()
   return self._input_bin_priority
end

function AceStorageComponent:get_ignore_restock()
   return self._ignore_restock
end

return AceStorageComponent