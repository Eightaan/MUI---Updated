--------
-- MUI
-- Setup for various additions and fixes to the hud
-- Kill Counter
-- Trade Delay
-- Fixed Custody Panel
--------

--------------------- SETUP_KILL_COUNTER -----------------------
if RequiredScript == "lib/managers/statisticsmanager" then
	local civies ={civilian = true, civilian_female = true, civilian_mariachi = true};

	Hooks:PostHook(StatisticsManager, "killed", "MUI_StatisticsManager_killed", function(self, data, ...)
		if civies[data.name] then
			return
		end
		local bullets = data.variant == "bullet";
		local melee = data.variant == "melee" or data.weapon_id and tweak_data.blackmarket.melee_weapons[data.weapon_id];
		local booms = data.variant == "explosion";
		local other = not (bullets or melee or booms);
		local is_valid_kill = bullets or melee or booms or other;
		if is_valid_kill then
			self:mui_update_kills();
		end
	end)

	function StatisticsManager:mui_update_kills()
		self._total_kills_mui = (self._total_kills_mui or 0) + 1;
	end

	function StatisticsManager:MUITotalKills()
		return self._total_kills_mui or 0;
	end

--------------------- SETUP_TRADE_DELAY ------------------------
elseif RequiredScript == "lib/managers/moneymanager" then
	if not MUIMenu then return; end

	local function GetTimeText(time)
		time = math.max(math.floor(time), 0);
		local minutes = math.floor(time / 60);
		time = time - minutes * 60;
		local seconds = math.round(time);
		local text = "";

		return text .. (minutes < 10 and "0" .. minutes or minutes) .. ":" .. (seconds < 10 and "0" .. seconds or seconds);
	end

	function MoneyManager:civilian_killed()
		local deduct_amount = self:get_civilian_deduction();
		if deduct_amount == 0 then return; end
		
		self.civs_killed = (self.civs_killed or 0) + 1;

		local text = managers.localization:text("hud_civilian_killed_message", {AMOUNT = managers.experience:cash_string(deduct_amount)});
		local title = managers.localization:text("hud_civilian_killed_title");
		
		if MUIMenu._data.mui_trade_delay then
			title = title .. " " .. utf8.to_upper(managers.localization:text("hud_trade_delay", {TIME = tostring(GetTimeText(5 + (self.civs_killed * 30)))}));
		end

		managers.hud:present_mid_text({
			time = 4,
			text = text,
			title = title
		});
		self:_deduct_from_total(deduct_amount);
	end

	function MoneyManager:ResetCivKills()
		self.civs_killed = 0;
	end

--------------------- SETUP_CUSTODY_PANEL ----------------------
elseif RequiredScript == "lib/managers/trademanager" then
	Hooks:PostHook(TradeManager, 'on_player_criminal_death', "MUI_on_player_criminal_death", function(self, criminal_name, ...)
		if criminal_name == managers.criminals:local_character_name() then
			--Resets the trade delay time for the trade delay notification, unrelated to the custody panel	
			managers.money:ResetCivKills();
			--Make sure the custody panel is visible when entering custody
			local custody = managers.hud and managers.hud._hud_player_custody
			if custody then
				custody:show(false);
			end
		end
	end)

	Hooks:PostHook(TradeManager, "criminal_respawn", "MUI_criminal_respawn", function(self, pos, rotation, respawn_criminal)
		--Make sure the custody panel is hidden when leaving custody as the local player when host
		if respawn_criminal and respawn_criminal.id == managers.criminals:local_character_name() then
			local custody = managers.hud and managers.hud._hud_player_custody
			if custody then
				custody:hide(false)
			end
		end
	end)
	
	Hooks:PostHook(TradeManager, "sync_set_trade_spawn", "MUI_sync_set_trade_spawn", function(self, criminal_name)
		--Make sure the custody panel is hidden when leaving custody as the local player when client
		if criminal_name == managers.criminals:local_character_name() then
			local custody = managers.hud and managers.hud._hud_player_custody
			if custody then
				custody:hide(false)
			end
		end
	end)
end