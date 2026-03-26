--------
-- MUI
-- Setup for various additions and fixes to the hud
-- Kill Counter
-- Trade Delay
-- Fixed Custody Panel
-- Challenge notifications
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
			local custody = managers.hud and managers.hud._hud_player_custody;
			if custody then
				custody:show(false);
			end
		end
	end)

	Hooks:PostHook(TradeManager, "criminal_respawn", "MUI_criminal_respawn", function(self, pos, rotation, respawn_criminal)
		--Make sure the custody panel is hidden when leaving custody as the local player as host
		if respawn_criminal and respawn_criminal.id == managers.criminals:local_character_name() then
			local custody = managers.hud and managers.hud._hud_player_custody;
			if custody then
				custody:hide(false);
			end
		end
	end)
	
	Hooks:PostHook(TradeManager, "sync_set_trade_spawn", "MUI_sync_set_trade_spawn", function(self, criminal_name)
		--Make sure the custody panel is hidden when leaving custody as the local player as client
		if criminal_name == managers.criminals:local_character_name() then
			local custody = managers.hud and managers.hud._hud_player_custody;
			if custody then
				custody:hide(false);
			end
		end
	end)
	
--------------------- SETUP_CHALLENGE_NOTIFICATIONS ------------
elseif RequiredScript == "lib/managers/hud/hudchallengenotification" then
	if not (MUIMenu and MUIMenu:ClassEnabled("MUIPresent")) then return; end

	function HudChallengeNotification:make_fine_text(text)
		local x, y, w, h = text:text_rect();
		text:set_size(w, h);
		text:set_position(math.round(text:x()), math.round(text:y()));
	end

	function HudChallengeNotification:_animate_show(title_panel, text_panel)
		local function fade(from, to, duration)
			local t = duration;

			while t > 0 do
				coroutine.yield();
				local dt = TimerManager:main():delta_time();
				t = t - dt;

				local a = math.lerp(from, to, 1 - (t / duration));
				title_panel:set_alpha(a);
				text_panel:set_alpha(a);
			end

			title_panel:set_alpha(to);
			text_panel:set_alpha(to);
		end

		title_panel:set_alpha(0);
		text_panel:set_alpha(0);

		fade(0, 1, 0.2);
		wait(3);
		fade(1, 0, 0.2);

		self:close();
	end

	function HudChallengeNotification:init(title, text, icon, rewards, queue)
		if not MUIMenu._data.mui_challanges then return; end

		self._ws = managers.gui_data:create_fullscreen_workspace();
		self._muiFont = MUIMenu._data.mui_font_pref or 4;
		self._font = ArmStatic.font_index(self._muiFont);
		self._scale = (MUIMenu._data.mui_pst_size or 20) * 0.04;
		HudChallengeNotification.super.init(self, self._ws:panel());
		self._queue = queue or {};
		self._hud = self._ws:panel();

		local text_panel = self._hud:panel({});
		local font_size = 20 * self._scale;

		local challenge_text = text_panel:text({
			text = utf8.to_lower(text):gsub("^%l", string.upper) or "",
			font = self._font,
			font_size = font_size,
			vertical = "center",
			w = 400 * self._scale,
			wrap = true,
			word_wrap = true
		});

		self:make_fine_text(challenge_text);
		challenge_text:set_h(challenge_text:h() + 6 * self._scale);

		local icon_texture, icon_texture_rect = tweak_data.hud_icons:get_icon_or(icon, nil);
		local total_w = challenge_text:w();

		local row_h = challenge_text:h();

		if icon_texture then
			local icon_h = 50 * self._scale;
			row_h = math.max(challenge_text:h(), icon_h);

			local icon = text_panel:bitmap({
				texture = icon_texture,
				texture_rect = icon_texture_rect,
				w = 50 * self._scale,
				h = 50 * self._scale
			});

			icon:set_left(0);
			icon:set_center_y(row_h / 2);

			challenge_text:set_left(icon:right() + 5);
			challenge_text:set_center_y(row_h / 2);

			total_w = icon:w() + 5 + challenge_text:w();
		else
			challenge_text:set_left(0);
		end


		text_panel:set_h(row_h);
		text_panel:set_w(total_w);
		text_panel:set_center_x(self._hud:w() / 2);

		local box_height = challenge_text:h();

		for i, reward in ipairs(rewards or {}) do
			local reward_panel = text_panel:panel({
				h = 20,
				y = challenge_text:bottom() + (i - 1) * 22
			});

			local icon_size = 20;
			local icon_padding = 2;
			local left_x = 0;

			if reward.texture then
				local reward_icon = reward_panel:bitmap({
					x = left_x,
					w = icon_size,
					h = icon_size,
					texture = reward.texture
				});

				reward_icon:set_center_y(icon_size / 2);
			end

			local text_x = left_x + icon_size + icon_padding;
			
			local reward_text_str = (reward.amount and (reward.amount .. "x ") or "") .. managers.localization:text(reward.name_id);

			local reward_text = reward_panel:text({
				text = reward_text_str,
				font = self._font,
				x = text_x,
				font_size = font_size
			});

			reward_text:set_center_y(icon_size / 2);
			reward_panel:set_w(reward_text:right());
			reward_panel:set_center_x(text_panel:w() / 2);

			box_height = math.max(box_height, reward_panel:bottom() + 8);
		end

		local title_panel = self._hud:panel({});

		local title_text = title_panel:text({
			text = utf8.to_lower(title):gsub("^%l", string.upper) or "Achievement unlocked!",
			font = self._font,
			font_size = font_size
		});

		self:make_fine_text(title_text);

		title_panel:set_size(title_text:right(), title_text:bottom());

		title_panel:set_bottom(self._hud:h() / 1.5);
		title_panel:set_center_x(self._hud:w() / 2);

		text_panel:set_top(title_panel:bottom());
		text_panel:set_center_x(self._hud:w() / 2);

		title_panel:animate(callback(self, self, "_animate_show"), text_panel);
	end
end