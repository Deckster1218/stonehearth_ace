$(document).ready(function() {
   $(top).off("radiant_open_character_sheet").on("radiant_open_character_sheet", function(_, e) {
      App.stonehearthClient.showCharacterSheet(e.entity);
   });

// for some reason, sometimes App.StonehearthCitizenCharacterSheetView doesn't exist at the time we want to reopen it
// since it isn't getting instantiated immediately, we can wait until document ready
App.StonehearthCitizenCharacterSheetView.reopen({
   ace_components: {
      'stonehearth_ace:titles': {}
   },

   init: function() {
      var self = this;
      stonehearth_ace.mergeInto(self.components, self.ace_components)

      self._super();
   },

   dismiss: function () {
      this.set('uri', null);

      var index = App.stonehearth.modalStack.indexOf(this)
      if (index > -1) {
         App.stonehearth.modalStack.splice(index, 1);
      }

      this.hide();
   },

   show: function () {
      this._super();

      App.stonehearth.modalStack.push(this);
   },

   _updateJobData: function () {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:job'),

   _updateJobDataDetails: function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:job.curr_job_controller'),

   _updateJobDescription: function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:job.curr_job_name'),

   _updateHappiness : function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:happiness'),

   _setFirstJournalEntry: function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:personality'),

   _buildTraitsArray: function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:traits'),

   _setEquipmentData: function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:equipment.equipped_items'),
   
   _setAttributeData: function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:attributes' , 'model.stonehearth:buffs'),
   
   _updateExp: function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:job.curr_job_controller'),
   
   _updateExpendableResource: function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:expendable_resources', 'model.stonehearth:buffs'),

   _updateMorale: function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:score'),

   _updateBackpackItems : function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:storage.item_tracker'),

   _onTeleportEnabled: function() {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:teleportation'),

   _updateItemPreferences: function () {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:appeal', 'model.stonehearth:unit_info'),

   _updateAppealArrows: function () {
      if (this.get('uri')) {
         this._super();
      }
   }.observes('model.stonehearth:appeal'),

   didInsertElement: function() {
      var self = this;
      self._super();
      
      self.$('#name').focus(function() {
         self.$('#name').val(self.get('model.custom_name'))
            .select();
      })
      .blur(function() {
         // if the name didn't change, make sure we add back any title we might have!
         // (if the name did change, this will get taken care of automatically by the _onNameChanged function)
         if (self.$('#name').val() == self.get('model.custom_name')) {
            self.$('#name').val(self.get('model.unit_name'));
         }
      })
      .on('mousedown', function(e) {
         if (e.button == 2) {
            self._showTitleSelectionList();
            e.preventDefault();
         }
      });

      self.$('#lockTitle').click(function() {
         // toggle title lock for this entity
         radiant.call('stonehearth_ace:lock_title', self.get('uri'), !self.get('model.stonehearth:unit_info.title_locked'))
      });

      App.tooltipHelper.createDynamicTooltip(self.$('#lockTitle'), function () {
         var locked = self.get('model.stonehearth:unit_info.title_locked');
         if (locked == null) {
            return;
         }

         var sLocked = locked ? 'unlock' : 'lock';
         return $(App.tooltipHelper.createTooltip(i18n.t(`stonehearth_ace:ui.game.unit_frame.${sLocked}_title.title`),
               i18n.t(`stonehearth_ace:ui.game.unit_frame.${sLocked}_title.description`)));
      });
		
      self.$('#description').off('click').click(function () {
         if (self.get('uri')) {
            if (radiant.isOwnedByAnotherPlayer(self.get('model'), App.stonehearthClient.getPlayerId())) {
               return;
            }
            App.stonehearthClient.showPromotionTree(self.get('uri'), self.get('model.stonehearth:job.job_index'));
         }
      });
   },

   _onNameChanged: function() {
      var self = this;
      var unit_info = self.get('model.stonehearth:unit_info');
      var unit_name = i18n.t(unit_info && unit_info.display_name, {self: self.get('model')});
      var custom_name = unit_info && unit_info.custom_name;
      var title_description = unit_info && unit_info.current_title && unit_info.current_title.description;
      self.set('model.unit_name', unit_name);
      self.set('model.custom_name', custom_name);

      var text = title_description;
      var title;
      if (text) {
         text = i18n.t(text);
         title = unit_name;
      }
      else {
         text = unit_name;
      }

      var titleLockClass = null;
      // first check if titles are even an option for this entity
      if (unit_info && self.get('model.stonehearth_ace:titles')) {
         titleLockClass = unit_info.title_locked ? 'locked' : 'unlocked';
      }
      self.set('titleLockClass', titleLockClass);
      self.notifyPropertyChange('titleLockClass');

      App.guiHelper.addTooltip(self.$('#name'), text, title || "");
   }.observes('model.stonehearth:unit_info'),

   //Go through each job we've had and annotate the perk table accordingly
   _updateJobsAndPerks : function() {
      var self = this;

      //Hide all the job divs before selectively showing the ones for the current
      //character.
      if (!self.$('.jobData')) {
         return; // this can happen if character is destroyed.
      }

      self.$('.jobData').hide();

      //show each class that this person has ever been
      var allJobData = App.jobConstants;
      var jobs = this.get('model.stonehearth:job.job_controllers');
      var workerDivs = [];
      radiant.each(jobs, function(alias, data) {
         var job_alias = data.json_path;
         var isWorker = job_alias == 'stonehearth:jobs:worker';
         var hasPerks = job_alias != 'stonehearth:jobs:worker';
         var jobData = allJobData[job_alias];
         if (jobData) {
            isWorker = jobData.description.is_worker;
            hasPerks = self._hasPerks(jobData.description);
         }
         else {
            job_alias = alias;
            isWorker = job_alias == 'stonehearth:jobs:worker';
            hasPerks = job_alias != 'stonehearth:jobs:worker';
            jobData = allJobData[job_alias];
            if (jobData) {
               isWorker = jobData.description.is_worker;
               hasPerks = self._hasPerks(jobData.description);
            }
         }

         if (hasPerks) {
            var div = self.$("[uri='" + job_alias + "']");

            //For each, figure out which perks should be unlocked
            self._unlockPerksToLevel(div, data.last_gained_lv)

            $(div).show();

            if (isWorker) {
               workerDivs.push(div);
            }
         }
      });

      //Highlight current class, since it needs to be 100% up to date
      self.$('.activeClassNameHeader').removeClass('activeClassNameHeader');
      self.$('.className').addClass('retiredClassNameHeader');
      self.$('.jobData').addClass('retiredEffect');
      var currClassAlias = this.get('model.stonehearth:job.job_json_path');
      var $currClass = self.$("[uri='" + currClassAlias + "']");
      $currClass.prependTo("#citizenCharacterSheet #abilitiesTab");
      $currClass.find('.className').removeClass('retiredClassNameHeader').addClass('activeClassNameHeader');
      $currClass.removeClass('retiredEffect');
      //$currClass.removeClass('retiredClassNameHeader').addClass('activeClassNameHeader');
      self._unlockPerksToLevel($currClass,  this.get('model.stonehearth:job.curr_job_controller.last_gained_lv'))
      $currClass.find('.retiredAt').hide();

      workerDivs.forEach(div => {
         div.find('.retiredAt').hide();
      });

      //Make the job tooltips
      this._updateJobTooltips();
   },

   _hasPerks: function (jobDescription) {
      var hasPerks = false;
      if (jobDescription.levelArray) {
         jobDescription.levelArray.forEach(levelData => {
            if (levelData.perks && levelData.perks.length > 0) {
               hasPerks = true;
            }
         });
      }
      return hasPerks;
   },

   //Given a perk div and target level, change the classes within to reflect the current level
   _unlockPerksToLevel : function (target_div, target_level) {
      $(target_div).find('.levelLabel').addClass('lvLabelLocked');
      $(target_div).find('img').addClass('perkImgLocked');
      for(var i=0; i<=target_level; i++) {
         $(target_div).find("[imgLevel='" + i + "']").removeClass('perkImgLocked').addClass('perkImgUnlocked');
         $(target_div).find("[lbLevel='" + i + "']").removeClass('lvLabelLocked').addClass('lvLabelUnlocked');
         $(target_div).find("[divLevel='" + i + "']").attr('locked', "false");
      }

      //For good measure, throw the level into the class name header or remove if the level is 0
      if (target_level >= 0 && target_level <= 2) {
         $(target_div).find('.lvlTitle').text(target_level + ', ' + i18n.t('stonehearth:ui.game.citizen_character_sheet.apprentice'));
      } else if (target_level >= 3 && target_level <= 4) {
         $(target_div).find('.lvlTitle').text(target_level + ', ' + i18n.t('stonehearth:ui.game.citizen_character_sheet.journeyman'));
      } else if (target_level >= 5) {
         $(target_div).find('.lvlTitle').text(target_level + ', ' + i18n.t('stonehearth:ui.game.citizen_character_sheet.master'));
      }

      //Calculate the height of the jobPerks section based on the number of perkDivs
      //TODO: factor these magic numbers out or change if/when the icons change size
      // var numPerks = $(target_div).find('.perkDiv').length;
      // if (numPerks == 0) {
      //    $(target_div).find('.jobPerks').css('height', '0px');
      // } else {
      //    var num_rows = parseInt(numPerks/8) + 1;
      //    var total_height = num_rows * 90;
      //    $(target_div).find('.jobPerks').css('height', total_height + 'px');
      // }

      $(target_div).find('.retiredAt').show();
   },

   _showTitleSelectionList: function(e) {
      var self = this;

      // make sure they don't have title locked
      if (self.get('model.stonehearth:unit_info.title_locked')) {
         return;
      }

      var result = stonehearth_ace.createTitleSelectionList(self._titles, self.get('model.stonehearth_ace:titles.titles'), self.get('uri'), self.get('model.custom_name'));
      if (result) {
         self.$('#name').after(result.container);
         result.showList();
      }
   },

   _loadAvailableTitles: function() {
      // when the selection changes, load up the appropriate titles json
      var self = this;
      self._titles = {};
      var json = self.get('model.stonehearth_ace:titles.titles_json');
      if (json) {
         stonehearth_ace.loadAvailableTitles(json, function(data){
            self._titles = data;
         });
      }
   }.observes('model.uri'),

   _showAttributeTooltip: function(obj, buffsByAttribute, attributeName) {
      // create tooltip
      var hasTooltip = App.tooltipHelper.hasTooltip(attributeName);
      if (hasTooltip) {
         App.tooltipHelper.createDynamicTooltip($(obj), function () {
            //For each buff and debuff that's associated with this attribute,
            //put it in the tooltip
            if (buffsByAttribute[attributeName] != null) {
               var buffString = '<div class="buffTooltip">';
               for (var i = 0; i < buffsByAttribute[attributeName].length; i++) {
                  var buff = buffsByAttribute[attributeName][i]
                  buffString += `<span class="buffTooltipText"><span class="dataSpan ${buff.class}">${i18n.t(buff.shortDescription)}</span>`
                              + `<img class="buffTooltipImg" src="${buff.icon}"> ${i18n.t(buff.display_name)}</span></br>`;
               }
               buffString = buffString + '</div>';
            }

            return $(App.tooltipHelper.getTooltip(attributeName, buffString, false));
         });
      }
   },

   // base game version didn't take stacks into account
   _sortBuffsByAttribute: function() {
      var allBuffs = this.get('model.stonehearth:buffs.buffs');
      var buffsByAttribute = {};
      if (allBuffs) {
         radiant.each(allBuffs, function(_, buff) {
            //If the buff is private don't add it. Public buffs can be undefined or is_private = false
            if (buff.invisible_to_player == undefined || !buff.invisible_to_player) {
               var modifiers = buff.modifiers;
               for (var mod in modifiers) {
                  var new_buff_data = {}
                  new_buff_data.display_name = buff.display_name;
                  new_buff_data.axis = buff.axis;
                  new_buff_data.icon = buff.icon;
                  new_buff_data.shortDescription = '';
                  if (buff.short_description != undefined) {
                     new_buff_data.shortDescription = buff.short_description;
                  } else {
                     for (var attrib in modifiers[mod]) {
                        if (attrib == 'multiply' || attrib == 'divide') {
                           var number = Math.pow(modifiers[mod][attrib], buff.stacks);
                           if (attrib == 'divide') {
                              number = 1 / number;
                           }
                           var rounded = Math.round( (number - 1) * 1000 ) / 10;
                           new_buff_data.class = rounded >= 0 ? 'buffDataSpan' : 'debuffDataSpan';
                           new_buff_data.shortDescription += (rounded >= 0 ? '+' : '-') + Math.abs(rounded) + '% ';
                        } else if (attrib == 'add') {
                           var number = modifiers[mod][attrib] * buff.stacks;
                           if (number < 0) {
                              new_buff_data.shortDescription += number + ' ';
                              new_buff_data.class = 'debuffDataSpan';
                           } else {
                              new_buff_data.shortDescription += '+' + number + ' ';
                              new_buff_data.class = 'buffDataSpan';
                           }
                        }
                     }
                  }
                  //There are so many ways to modify a buff; let writer pick string
                  if (buffsByAttribute[mod] == null) {
                     buffsByAttribute[mod] = [];
                  }
                  buffsByAttribute[mod].push(new_buff_data);
               }
            }
         });
      }
      return buffsByAttribute;
   },

   _onEntitySelected: function(e) {
      var self = this;
      if (!self.get('uri')) {
         return;
      }

      var entity = e.selected_entity

      if (!entity || App.stonehearthClient.getPlayerId() != e.player_id) {
         self.dismiss();
         return;
      }

      // nuke the old trace
      if (self.selectedEntityTrace) {
         self.selectedEntityTrace.destroy();
      }

      // trace the properties so we can tell if we need to popup the properties window for the object
      self.selectedEntityTrace = new StonehearthDataTrace(entity)
         .progress(function(result) {
            if (self.isDestroyed || self.isDestroying) {
               return;
            }
            self._examineEntity(result);
         })
         .fail(function(e) {
            console.log(e);
         });
   },

   _examineEntity: function(entity) {
      var self = this;

      if (!entity) {
         self.dismiss();
         return;
      }

      var alias = entity.get('uri');
      var catalogData = App.catalog.getCatalogData(alias);

      var materials = "";
      if (catalogData) {
         if ((typeof catalogData.materials) === 'string') {
            materials = catalogData.materials.split(' ');
         } else {
            materials = catalogData.materials;
         }
      }
      if (materials && materials.indexOf('human') >= 0) {
         self.set('uri', entity.__self);
         self._resetVars();
      } else  {
         self.dismiss();
      }
      self._segmentsInitialized = false;
   }
});

});
