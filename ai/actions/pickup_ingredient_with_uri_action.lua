local PickupIngredientWithUri = radiant.class()
PickupIngredientWithUri.name = 'pickup entity type ingredient'
PickupIngredientWithUri.does = 'stonehearth:pickup_ingredient'
PickupIngredientWithUri.args = {
   ingredient = 'table',                  -- what to get

   rating_fn = {                       -- a function to rate entities on a 0-1 scale to determine the best.
      type = 'function',
      default = stonehearth.ai.NIL,
   },
}
PickupIngredientWithUri.priority = 0

local GOLD_URI = 'stonehearth:loot:gold'

function PickupIngredientWithUri:start_thinking(ai, entity, args)
   if args.ingredient.uri ~= nil and args.ingredient.uri ~= GOLD_URI then
      ai:set_think_output({
         min_stacks = args.ingredient.min_stacks or 0
      })
   end
end

local ai = stonehearth.ai
return ai:create_compound_action(PickupIngredientWithUri)
               :execute('stonehearth:pickup_item_with_uri', {
                  uri = ai.ARGS.ingredient.uri,
                  min_stacks = ai.PREV.min_stacks,
                  rating_fn = ai.ARGS.rating_fn
               })
