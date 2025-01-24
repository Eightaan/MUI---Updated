--------
-- MUI <https://paydaymods.com/mods/44/arm_mui>
-- Copyright (C) 2015 Armithaig
-- License GPLv3 <https://www.gnu.org/licenses/>
-- Inquiries should be submitted by email to <mui@amaranth.red>.
--------
_G.MUITeammate = _G.MUITeammate or class(HUDTeammate);
ArmStatic.void(MUITeammate, {
	"recreate_weapon_firemode","_create_primary_weapon_firemode",
	"_create_secondary_weapon_firemode", "set_weapon_firemode",
	"_set_weapon_selected", "layout_special_equipments", "set_stored_health_max",
	"_animate_update_absorb", "animate_update_absorb_active", "_animate_timer", "_animate_timer_flash"
});

--- /// Bunch of helper functions to alter MUI health display - Freyah /// 

local function MUISetNewHealthValue(self)
	if not MUIMenu._data.mui_enable_health_numbers then return; end
	local size = self._main_player and self._muiSizeL or self._muiSizeS;
	if self._health_numbers then
		local data = self._health_data;
		local Value = math.clamp(data.current / data.total, 0, 1);
		local real_value = math.round((data.total * 10) * Value);
		self._health_numbers:set_text(real_value);
		self._health_numbers:set_font_size((size/3) + 12);
		if real_value > 35 then
			self._health_numbers:set_color(Color(71/255, 255/255, 120/255), Color.black:with_alpha(0.5))
		elseif real_value < 35 then
			self._health_numbers:set_color(Color.red:with_alpha(0.8))
		end
	end
end

local function MUISetNewArmorValue(self)
    if not MUIMenu._data.mui_enable_health_numbers then return; end
    if self._armor_numbers then
        local data = self._armor_data;
        local Value = math.clamp(data.current / data.total, 0, 1);
        if Value ~= Value then self._armor_numbers:hide() return end
        local real_value = math.round((data.total * 10) * Value);
        self._armor_numbers:set_text(real_value);
        self._armor_numbers:set_color(Color(48/255, 141/255, 255/255), Color.black:with_alpha(0.5))
        self._armor_numbers:set_font_size(self._health_numbers:font_size());
        if real_value <= 0 then
            self._armor_numbers:hide()
        else
            self._armor_numbers:show()
        end
    end
end

local function MUIResized(self,size)
	if not self._radial_health_panel then return; end
	if not MUIMenu._data.mui_enable_health_numbers then
		self._radial_health_panel:child("radial_health"):show()
		self._radial_health_panel:child("radial_shield"):show()
		if self._health_numbers then self._health_numbers:hide() end
		if self._armor_numbers then self._armor_numbers:hide() end
		return;
	end

	self._radial_health_panel:child("radial_health"):hide()
	self._radial_health_panel:child("radial_shield"):hide()

	DelayedCalls:Add("DelayedUpdateFontSize", 0.1, function()
		self._health_numbers:set_font_size((size/3) + 12);
		self._armor_numbers:set_font_size(self._health_numbers:font_size());
	end)

	if not self._health_numbers then
		local health_numbers = self._radial_health_panel:text({
			name = "health_numbers",
			text = "",
			font = self._font,
			font_size = 18,
			color = Color.white,
			align = "center",
			vertical = "top",
			layer = 3,
			visible = true
		});
		self._health_numbers = health_numbers
	end

	if not self._armor_numbers then
		local armor_numbers = self._radial_health_panel:text({
			name = "armor_numbers",
			text = "",
			font = self._font,
			font_size = 18,
			color = Color.white,
			align = "center",
			vertical = "bottom",
			layer = 3,
			visible = true
		});
		self._armor_numbers = armor_numbers
	end
end

--- /// Bunch of helper functions to alter MUI health display - Freyah /// 

MUITeammate._mui_base = {};
MUITeammate._mui_path = ModPath;
local tunnel = ArmStatic.tunnel;
local tunnel_c = ArmStatic.tunnel_child;
local flip_tex_h = ArmStatic.flip_texture_h;
local set_pam = ArmStatic.set_padded_amount;
local set_icon_data = ArmStatic.set_icon_data;
local fade, fade_c, rotate = ArmStatic.fade_animate, ArmStatic.fade_c_animate, ArmStatic.rotate_animate;
local floor, ceil, format, abs, max, fmod = math.floor, math.ceil, string.format, math.abs, math.max, math.fmod;

function MUITeammate:init(i, team)
	self.load_options();
	self._id = i;
	self._main_player = i == HUDManager.PLAYER_PANEL;
	self._parent = team;
	self._font = ArmStatic.font_index(self._muiFont);

	self:defaults();
	self:create_panel(team);
	self:resize();
end

function MUITeammate:defaults()
	--self._revives = 4;
	self._max_stamina = 1;
	self._stamina = 0;
	self._timer_paused = 0;
	self._absorb_active_amount, self._absorb_old = 0, 0;
	self._delayed_damage, self._delayed_old = 0, 0;

	self._custardy = false;
	--self._crimedad = false;
	--self._down = false;
	self._waiting = false;

	self._fade_threads = {};
	self._rot_threads = {};
	self._special_equipment = {};
	self._health_data = { current = 0, total = 0 };
	self._armor_data = { current = 0, total = 0 };
	self._ammo_data = {
		{ clip = 0, clip_m = 0, total = 0, total_m = 0 },
		{ clip = 0, clip_m = 0, total = 0, total_m = 0 }
	};

	local colors = tweak_data.chat_colors;
	self._prime_color = colors[#colors - self._id];
end

function MUITeammate:create_panel(parent)
	local panel = parent:panel({
		visible = false,
		name = "" .. self._id
	});
	self._panel = panel;
	self._name = panel:text({
		name = "name",
		text = "#".. self._id,
		layer = 5,
		visible = true,
		color = Color.black,
		vertical = "bottom",
		font = self._font
	});
	self._name_bg = panel:panel({name = "name_bg", w = 0, h = 0, visible = false}); -- Poco comp
	self._special_list = AnimatedList:new(panel, {name = "special_equipment", align = 2});

	self:create_player_panel(panel);
	self:create_condition_panel(panel);
	self:create_info_list(panel);
	self:create_waiting_panel(panel);
end

function MUITeammate:create_player_panel(parent)
	local panel = parent:panel({name = "player"});
	self._player_panel = panel;

	self:create_radial_panel(panel);
	self:create_interact_panel(panel);
	self:create_weapons_panel(panel);
	self:create_carry_panel(panel);
	self:create_equipment_list(panel);
end

function MUITeammate:create_condition_panel(parent)
	self._condition_icon = parent:bitmap({
		name = "condition_icon",
		layer = 4,
		visible = false,
		color = Color.white
	});
	self._condition_timer = parent:text({
		name = "condition_timer",
		visible = false,
		text = "00",
		layer = 5,
		color = Color.black,
		align = "center",
		vertical = "center",
		font = self._font
	});
end

function MUITeammate:create_interact_panel(parent)
	local panel = parent:panel({
		name = "interact_panel",
		visible = true,
		layer = 3
	});
	self._interact_panel = panel;
	self._interact_progress = panel:bitmap({
		name = "progress",
		texture = "guis/textures/pd2/hud_progress_active",
		blend_mode = "add",
		visible = false,
		color = Color.black,
		render_template = "VertexColorTexturedRadial",
		layer = 0
	});
	self._interact_success = panel:bitmap({
		name = "success",
		texture = "guis/textures/pd2/hud_progress_active",
		blend_mode = "normal",
		visible = false,
		color = Color.black,
		layer = 1
	});
end

function MUITeammate:create_carry_panel(parent)
	local panel = parent:panel({
		name = "carry_panel",
		visible = false,
		layer = 1
	});
	self._carry_panel = panel;
	self._carry_icon = panel:bitmap({
		name = "bag",
		texture = "guis/textures/pd2/hud_bag",
		layer = 0,
		color = self._prime_color
	});
end

function MUITeammate:create_info_list(parent)
	local panel = AnimatedList:new(parent, {
		name = "info_list",
		align = 1,
		direction = 1,
		aspd = 0.5
	});
	self._info_list = panel;

	self._revives_icon = panel:bitmap({
		name = "revives_icon",
		visible = false,
		texture = "guis/textures/pd2/skilltree/icons_atlas",
		texture_rect = {
			330,
			460,
			42,
			42
		},
		layer = 1,
		color = Color.red
	});
	self._stamina_icon = panel:bitmap({
		name = "stamina_icon",
		visible = false,
		texture = "guis/textures/pd2/hud_radial_rim",
		render_template = "VertexColorTexturedRadial",
		layer = 2,
		color = Color.white
	});
	self._talk_icon = panel:bitmap({
		name = "talk_icon",
		visible = false,
		texture = "guis/textures/hud_icons",
		texture_rect = {
			36,
			276,
			32,
			32
		},
		layer = 2,
		color = Color.white
	});
end

function MUITeammate:create_radial_panel(parent)
	local panel = parent:panel({
		name = "radial_health_panel",
		layer = 1
	});
	self._radial_health_panel = panel;

	local radial_health = panel:bitmap({
		name = "radial_health",
		color = Color.black,
		texture = "guis/textures/pd2/hud_health",
		render_template = "VertexColorTexturedRadial",
		blend_mode = "add",
		layer = 2
	});
	self._radial_health = radial_health;

	if self._muiColor and not MUIMenu._data.mui_enable_health_numbers then
		radial_health:set_blend_mode("sub");
		panel:bitmap({
			name = "radial_health_fill",
			color = self._prime_color,
			texture = "guis/textures/pd2/hud_health",
			blend_mode = "add",
			layer = 1
		});
	else
		flip_tex_h(radial_health);
	end

	local radial_shield = panel:bitmap({
		name = "radial_shield",
		color = Color.black,
		texture = "guis/textures/pd2/hud_shield",
		render_template = "VertexColorTexturedRadial",
		blend_mode = "add",
		layer = 1,
	});
	flip_tex_h(radial_shield);
	self._radial_shield = radial_shield;

	self._damage_indicator = panel:bitmap({
		name = "damage_indicator",
		color = Color(1, 1, 1, 1),
		texture = "guis/textures/pd2/hud_radial_rim",
		blend_mode = "add",
		alpha = 0,
		layer = 1
	});

	self._radial_custom = panel:bitmap({
		name = "radial_custom",
		visible = false,
		color = Color.black,
		texture = "guis/textures/pd2/hud_swansong",
		render_template = "VertexColorTexturedRadial",
		blend_mode = "add",
		layer = 2
	});

	local ability = panel:panel({ name = "radial_ability" });
	self._radial_ability = ability;
	self._ability_meter = ability:bitmap({
		name = "ability_meter",
		color = Color.black,
		texture = "guis/textures/pd2/hud_fearless",
		render_template = "VertexColorTexturedRadial",
		blend_mode = "add",
		layer = 5
	});
	self._ability_icon = ability:bitmap({
		blend_mode = "add",
		name = "ability_icon",
		visible = false,
		layer = 5
	});

	local delayed = panel:panel({name = "radial_delayed_damage"})
	self._delayed_health = delayed:bitmap({
		texture = "guis/textures/pd2/hud_dot",
		name = "radial_delayed_damage_health",
		color = Color.black,
		render_template = "VertexColorTexturedRadialFlex",
		layer = 5
	});
	self._delayed_shield = delayed:bitmap({
		texture = "guis/textures/pd2/hud_dot_shield",
		name = "radial_delayed_damage_armor",
		color = Color.black,
		render_template = "VertexColorTexturedRadialFlex",
		layer = 5
	});
	self._absorb_health = panel:bitmap({
		name = "radial_absorb_health_active",
		color = Color.black,
		texture = "guis/dlcs/coco/textures/pd2/hud_absorb_health",
		render_template = "VertexColorTexturedRadialFlex",
		blend_mode = "normal",
		layer = 5
	});
	self._absorb_shield = panel:bitmap({
		name = "radial_absorb_shield_active",
		color = Color.black,
		texture = "guis/dlcs/coco/textures/pd2/hud_absorb_shield",
		render_template = "VertexColorTexturedRadialFlex",
		blend_mode = "normal",
		layer = 5
	});
	self._info_meter = panel:bitmap({
		name = "radial_info_meter",
		visible = false,
		color = Color.black,
		texture = "guis/dlcs/coco/textures/pd2/hud_absorb_stack_fg",
		render_template = "VertexColorTexturedRadial",
		blend_mode = "add",
		layer = 5
	});
	self._info_meter = panel:bitmap({
		name = "radial_info_meter",
		visible = false,
		color = Color.black,
		texture = "guis/dlcs/coco/textures/pd2/hud_absorb_stack_fg",
		render_template = "VertexColorTexturedRadial",
		blend_mode = "add",
		layer = 5
	});

	if not MUIMenu._data.mui_disable_leech_support then
		self.copr_overlay_panel = panel:panel({
			name = "copr_overlay_panel",
			layer = 3,
			w = panel:w(),
			h = panel:h()
		});
	end

	if self._main_player then
		local rip = panel:bitmap({
			name = "radial_rip",
			texture = "guis/textures/pd2/hud_rip",
			render_template = "VertexColorTexturedRadial",
			blend_mode = "add",
			color = Color.black,
			visible = false,
			layer = 3
		});
		flip_tex_h(rip);
		self._radial_rip = rip;
	end
	if self._main_player then
		self.radial_rip_bg = panel:bitmap({
			texture = "guis/textures/pd2/hud_rip_bg",
			name = "radial_rip_bg",
			layer = 1,
			visible = false,
			render_template = "VertexColorTexturedRadial",
			texture_rect = {
				128,
				0,
				-128,
				128
			},
			color = Color(1, 0, 0, 0),
			w = panel:w(),
			h = panel:h()
		});
	end
end

function MUITeammate:create_equipment_list(parent)
	local panel = AnimatedList:new(parent, { align = 2, faux = true });
	self._equipment_list = panel;

	local texture, rect = tweak_data.hud_icons:get_icon_data(tweak_data.equipments.ammo_bag.icon);
	local deployable = panel:panel({
		name = "deployable_equipment_panel",
		layer = 1
	});
	self._deployable_equipment_panel = deployable;
	self._deployable_equipment_icon = deployable:bitmap({
		name = "equipment",
		texture = texture,
		texture_rect = rect,
		layer = 1,
		color = Color.white,
		visible = false
	});
	self._deployable_equipment_text = deployable:text({
		name = "amount",
		text = "01",
		font = self._font,
		color = Color.white,
		align = "right",
		vertical = "center",
		layer = 2,
		visible = false
	});

	texture, rect = tweak_data.hud_icons:get_icon_data(tweak_data.equipments.specials.cable_tie.icon);
	local ties = panel:panel({
		name = "cable_ties_panel",
		layer = 1
	});
	self._cable_ties_panel = ties;
	ties:bitmap({
		name = "cable_ties",
		texture = texture,
		texture_rect = rect,
		layer = 1,
		color = Color.white
	});
	ties:text({
		name = "amount",
		text = "02",
		font = self._font,
		color = Color.white,
		align = "right",
		vertical = "center",
		layer = 2
	});

	self:create_grenades_panel(panel);
end

function MUITeammate:create_grenades_panel(parent)
	if not PlayerBase.USE_GRENADES then return; end -- Is there a point to this anymore?

	local texture, rect = tweak_data.hud_icons:get_icon_data("frag_grenade");
	local panel = parent:panel({
		name = "grenades_panel",
		layer = 1
	});
	self._grenades_panel = panel;
	self._grenades_icon = panel:bitmap({
		name = "grenades_icon",
		texture = texture,
		texture_rect = rect,
		layer = 2,
		color = Color.white
	});
	panel:text({
		name = "amount",
		text = "00",
		font = self._font,
		color = Color.white,
		align = "right",
		vertical = "center",
		layer = 2
	});
	panel:bitmap({
		texture = "guis/textures/pd2/hud_cooldown_timer",
		name = "grenades_radial",
		render_template = "VertexColorTexturedRadial",
		layer = 1,
		color = Color(0.5, 0, 1, 1)
	});
	panel:bitmap({
		texture = "guis/textures/pd2/hud_cooldown_timer",
		name = "grenades_radial_ghost",
		visible = false,
		rotation = 360,
		layer = 1
	});
	self._grenades_icon_ghost = panel:bitmap({
		name = "grenades_icon_ghost",
		rotation = 360,
		visible = false,
		texture = texture,
		texture_rect = rect,
		layer = 2,
		color = Color.white
	});
end

function MUITeammate:create_weapons_panel(parent)
	local panel = parent:panel({
		name = "weapons_panel",
		visible = true,
		layer = 0
	});
	self._weapons_panel = panel;

	local primary = panel:panel({
		name = "primary_weapon_panel",
		visible = true,
		layer = 1
	});
	self._primary_weapon_panel = primary;
	self._primary_ammo_clip = primary:text({
		name = "ammo_clip",
		visible = self._main_player,
		text = "000",
		color = Color.white,
		blend_mode = "normal",
		layer = 1,
		vertical = "top",
		align = "center",
		font = self._font
	});
	self._primary_ammo_total = primary:text({
		name = "ammo_total",
		visible = true,
		text = "000",
		color = Color.white,
		blend_mode = "normal",
		layer = 1,
		vertical = "top",
		align = "center",
		font = self._font
	});

	local secondary = panel:panel({
		name = "secondary_weapon_panel",
		visible = true,
		layer = 1
	});
	self._secondary_weapon_panel = secondary;
	self._secondary_ammo_clip = secondary:text({
		name = "ammo_clip",
		visible = self._main_player,
		text = "000",
		color = Color.white,
		blend_mode = "normal",
		layer = 1,
		vertical = "bottom",
		align = "center",
		font = self._font
	});
	self._secondary_ammo_total = secondary:text({
		name = "ammo_total",
		visible = true,
		text = "000",
		color = Color.white,
		blend_mode = "normal",
		layer = 1,
		align = "center",
		vertical = "bottom",
		font = self._font
	});
end

function MUITeammate:create_waiting_panel(parent)
	local panel = parent:panel({
		visible = false,
		name = "wait"
	});
	panel:text({
		name = "name",
		w = 0, h = 0,
		visible = false,
		font = self._font
	});
	local detection = panel:panel({
		name = "detection"
	});
	detection:bitmap({
		name = "detection_left_bg",
		texture = "guis/textures/pd2/mission_briefing/inv_detection_meter",
		alpha = 0.2,
		blend_mode = "add"
	});
	local drr_bg = detection:bitmap({
		name = "detection_right_bg",
		texture = "guis/textures/pd2/mission_briefing/inv_detection_meter",
		alpha = 0.2,
		blend_mode = "add"
	});
	flip_tex_h(drr_bg);
	detection:bitmap({
		name = "detection_left",
		texture = "guis/textures/pd2/mission_briefing/inv_detection_meter",
		render_template = "VertexColorTexturedRadial",
		blend_mode = "add",
		layer = 1
	});
	local drr = detection:bitmap({
		name = "detection_right",
		texture = "guis/textures/pd2/mission_briefing/inv_detection_meter",
		render_template = "VertexColorTexturedRadial",
		blend_mode = "add",
		layer = 1
	});
	flip_tex_h(drr);
	panel:text({
		name = "detection_value",
		font = self._font,
		align = "center",
		vertical = "center"
	});

	self:_create_equipment(panel, "deploy");
	self:_create_equipment(panel, "throw");
	self:_create_equipment(panel, "perk");
	self._wait_panel = panel;
end

function MUITeammate:_create_equipment(parent, name)
	local panel = parent:panel({ name = name });
	panel:bitmap({
		name = "icon",
		layer = 1,
		visible = true,
		color = Color.white
	});
	panel:text({
		name = "amount",
		text = "00",
		font = self._font,
		color = Color.white,
		align = "center",
		vertical = "center",
		layer = 2
	});
end

function MUITeammate:is_waiting() return self._waiting; end
function MUITeammate:set_waiting(waiting, peer)
	if self._waiting == waiting then return; end
	self._waiting = waiting;

	local my_peer = managers.network:session():peer(self._peer_id);
	local wp = self._wait_panel;
	peer = peer or my_peer;

	if peer and waiting then
		local wped = wp:child("deploy");
		local wpet = wp:child("throw");
		local wpep = wp:child("perk");
		local wpd = wp:child("detection");
		local wpdl = wpd:child("detection_left");
		local wpdr = wpd:child("detection_right");
		local wpdv = wp:child("detection_value");

		local name = peer:name();
		local profile = peer:profile();
		local grenade = peer:grenade_id();
		local outfit = profile.outfit or managers.blackmarket:unpack_outfit_from_string(profile.outfit_string) or {};

		local current, reached = managers.blackmarket:get_suspicion_offset_of_peer(peer, tweak_data.player.SUSPICION_OFFSET_LERP or 0.75);
		wpdl:set_color(Color(0.5 + current * 0.5, 1, 1));
		wpdr:set_color(Color(0.5 + current * 0.5, 1, 1));
		wpdv:set_color(reached and Color(255,255,42,0) / 255 or tweak_data.screen_colors.text);

		local has_deployable = outfit.deployable and outfit.deployable ~= "nil";

		set_pam(wped:child("amount"), has_deployable and outfit.deployable_amount or 0);
		set_pam(wpet:child("amount"), managers.player:get_max_grenades(grenade));
		set_pam(wpep:child("amount"), tonumber(outfit.skills.specializations[2]));

		set_icon_data(wped:child("icon"), has_deployable and tweak_data.equipments[outfit.deployable].icon);
		set_icon_data(wpet:child("icon"), outfit.grenade and tweak_data.blackmarket.projectiles[outfit.grenade].icon);
		set_icon_data(wpep:child("icon"), tweak_data.skilltree:get_specialization_icon_data(tonumber(outfit.skills.specializations[1])));
		self:set_callsign(peer:id());
		self:set_name(name);
	elseif not waiting then
		self:set_callsign(5);
		self:restore_name();
	end
	self:set_gear_visible(not waiting and (my_peer and my_peer:unit()));
	self:redisplay_panel();
	fade(wp, waiting and 1 or 0, 1);
end

function MUITeammate:add_panel()
	self._taken = true;
	self:redisplay_panel();
	self._special_list:reposition();
end

local shape_main = false;
local function shape_ammo(fgr, p, s)
	local w, h = p:w(), p:h();
	if shape_main then w = w / 2; end
	fgr:shape(w, h):lead():attach(shape_main and s, 2);
end
local function shape_material(fgr, p, s)
	local w, h = p:w()/2, p:h();
	local x = fgr:get("text_rect") and w or 0;
	fgr:shape(p:w()/2, p:h()):move(x):lead();
end
local function shape_equipment(fgr, p, s)
	fgr:shape(p:w(), p:h() /3):progeny(shape_material);
end

function MUITeammate:resize()
	local main = self._main_player;
	local size = main and self._muiSizeL or self._muiSizeS;
	local alpha = main and self._muiAlphaL or self._muiAlphaS;
	local s33, s66 = size/3, size/1.5;
	local sTimer = main and s33 or s66
	local sAmmo = size * (main and 1.5 or 0.75);
	local dock = main and self._muiSpcLD or self._muiSpcSD;
	local jtfy = main and self._muiSpcLJ or self._muiSpcSJ;
	local row = main and self._muiSpcLR or self._muiSpcSR;
	local vert = dock % 2 == 0;
	local flip = (dock == 1 or dock == 4) and 2 or 1;
	local total = s33 * row;
	self._mui_size = size;

	MUIResized(self, size);

	local panel = self._panel;
	local name = self._name;
	local condition = self._condition_icon;
	local timer = self._condition_timer;
	local info = self._info_list;
	local stamina = self._stamina_icon;
	local special = self._special_list;

	local player = self._player_panel;
	local health = self._radial_health_panel;
	local ability = self._ability_icon;
	local weapons = self._weapons_panel;
	local primary = self._primary_weapon_panel;
	local secondary = self._secondary_weapon_panel;
	local equipment = self._equipment_list;
	local carry = self._carry_panel;
	local interact = self._interact_panel;

	shape_main = main;
	Figure(carry):shape(s33):spank();
	Figure({health,interact}):shape(size):attach(carry, 3):recur():spank();
	Figure(ability):shape(s33):align(2);
	Figure(weapons):shape(sAmmo, size):attach(health, 2);
	Figure(primary):shape(sAmmo, size/2):progeny(shape_ammo);
	Figure(secondary):shape(sAmmo, size/2):attach(primary, 3):progeny(shape_ammo);

	Figure(equipment):shape(s66, size):attach(weapons, 2):progeny(shape_equipment);
	equipment:reposition();

	Figure(player):adapt():move(dock == 4 and total or 0, dock == 1 and total or 0);
	Figure(special):shape(vert and total or player:w(), vert and player:h() or total):attach(player, dock):recur():spank(s33, s33, s33/2);
	special:set_direction(vert and 2 or 1);
	special:set_align(jtfy);
	special:set_flip(flip);
	special:reposition();

	Figure(name):shape(player:w() - s33, s33):leech(player):attach(carry:visible() and carry, 2);
	Figure(condition):shape(size):leech(player):attach(carry, 3);
	Figure(timer):shape(sTimer):leech(condition):align(2);

	if MUIMenu._data.mui_enable_center_team_revives and not MUIMenu._data.mui_enable_health_numbers and not self._main_player then
		Figure(info):shape(size/3):leech(condition):align(2):spank(s33);
	else
		Figure(info):shape(s66, s33):leech(player):align(3, 1):spank(s33);
	end

	if not self._muiStam and stamina:visible() then info:set_visible_panel(stamina, false); end
	info:reposition();

	self:resize_wait();
	Figure(panel):adapt();
	self._parent:set_alpha_panel(panel, alpha);
	ArmStatic.align_corners(panel);

	self:redisplay_name();
	self:redisplay_panel();
	self:redisplay_ammo(1);
	self:redisplay_ammo(2);
	self:update_absorb(true);
end

function MUITeammate:resize_wait()
	local size = self._main_player and self._muiSizeL or self._muiSizeS;
	local s33, s66 = size/3, size/1.5;

	local player = self._player_panel;
	local carry = self._carry_panel;
	local wait = self._wait_panel;
	local detect = wait:child("detection");
	local value = wait:child("detection_value");
	local deploy = wait:child("deploy");
	local throw = wait:child("throw");
	local perk = wait:child("perk");

	--Figure(detect):shape(size):spank();
	Figure(detect):shape(size):leech(player):attach(carry, 3):spank();
	Figure(value):rect(s33):leech(detect):align(2);
	Figure(deploy):shape(s66, s33):attach(detect, 2):progeny(shape_material);
	Figure(throw):shape(s66, s33):attach(deploy, 3):progeny(shape_material);
	Figure(perk):shape(s66, s33):attach(throw, 3):progeny(shape_material);
	Figure(wait):adapt():attach(carry, 3);
end

function MUITeammate:add_special_equipment(data)
	local spcSize = self._mui_size/3;
	local panel = self._special_list:panel({ name = data.id, h = spcSize, w = spcSize });

	local icon, texture_rect = tweak_data.hud_icons:get_icon_data(data.icon);
	local bitmap = panel:bitmap({
		name = "bitmap",
		texture = icon,
		color = Color.white,
		h = spcSize,
		w = spcSize,
		layer = 1,
		texture_rect = texture_rect,
		visible = true
	});
	if data.amount then
		local amount = panel:child("amount") or panel:text({
			name = "amount",
			text = tostring(data.amount),
			font = "fonts/font_medium_noshadow_mf",
			font_size = spcSize/2,
			color = (Color.black):with_alpha(1),
			h = spcSize,
			w = spcSize,
			align = "center",
			vertical = "center",
			layer = 4
		});
		amount:set_visible(1 < data.amount);
		local amount_bg = panel:child("amount_bg") or panel:bitmap({
			name = "amount_bg",
			texture = "guis/textures/pd2/equip_count",
			color = Color.white,
			h = spcSize,
			w = spcSize,
			layer = 3
		});
		amount_bg:set_visible(1 < data.amount);
	end

	ArmStatic.flash_c_animate(bitmap, self._prime_color, 2, 4, 0.5);
end

function MUITeammate:remove_special_equipment(id)
	self._special_list:set_state_id(id, 0);
end

function MUITeammate:set_special_equipment_amount(id, no)
	local equipment = self._special_list:child(id);
	if not equipment then return; end
	local amount, bg = equipment:child("amount"), equipment:child("amount_bg");
	if amount and bg then
		amount:set_text(tostring(no));
		amount:set_visible(no > 1);
		bg:set_visible(no > 1);
	end
end

function MUITeammate:set_weapon_selected(id, hud_icon)
	local scdry = id == 1;
	self._primary_weapon_panel:set_alpha(scdry and 0.5 or 1);
	self._secondary_weapon_panel:set_alpha(scdry and 1 or 0.5);
end

function MUITeammate:set_ammo_amount_by_type(index, max_clip, current_clip, current_left, max_left)
	if index > 2 then index = (index - 1) % 2 + 1 end
	local data = self._ammo_data[index];

	data.clip = current_clip;
	data.clip_m = max_clip;
	data.total = current_left;
	data.total_m = max_left or max(data.total_m, current_left);
	self:redisplay_ammo(index);
end

local ooa, loa = Color(1, 0.9, 0.3, 0.3), Color(1, 0.9, 0.9, 0.3);
function MUITeammate:redisplay_ammo(index)
	local data = self._ammo_data[index];
	local col_c, col_t = Color.white, Color.white;
	local clip, clip_m, total, total_m = data.clip, data.clip_m, data.total, data.total_m;
	local wac, wat;
	if index == 1 then
		wac, wat = self._secondary_ammo_clip, self._secondary_ammo_total;
	else
		wac, wat = self._primary_ammo_clip, self._primary_ammo_total;
	end

	if  self._main_player and self._muiAmmo > 1 and total >= clip then
			total = total - clip;
			total_m = total_m - clip_m;

		if self._main_player and self._muiAmmo == 3 and clip_m > 0 then
			total = ceil(total / clip_m);
			total_m = ceil(total_m / clip_m);
		end
	end

	if clip <= 0 then
		col_c = ooa;
	elseif clip <= clip_m /2 then
		col_c = loa;
	end
	if total <= 0 then
		col_t = ooa;
	elseif total <= total_m /2 then
		col_t = loa;
	end

	wac:set_text(format("%03d", clip));
	wac:set_color(col_c);
	wat:set_text(format("%03d", total));
	wat:set_color(col_t);
end

function MUITeammate:set_callsign(id)
	local color = tweak_data.chat_colors[id]:with_alpha(1);
	self._prime_color = color;
	self._name:set_color(color);
	self._carry_icon:set_color(color);
	self._interact_success:set_color(color);

	--local comp_color = self._muiColor and ArmStatic.complement(color):with_alpha(1) or Color.black;
	self._comp_color = self._prime_color;
	self._condition_timer:set_color(self._prime_color);

	if self._muiColor then
		local rhf = tunnel_c(self._player_panel, "radial_health_panel", "radial_health_fill");
		if rhf then rhf:set_color(color); end
	end
end

function MUITeammate:set_equipment_amount(panel, amount, alt)
	local text = panel:child("amount");
	alt = self._main_player and alt or 0; amount = amount or 0;

	self._equipment_list:set_visible_panel(panel, amount + alt > 0);
	set_pam(text, amount, alt);
end

function MUITeammate:set_cable_ties_amount(amount)
	self:set_equipment_amount(self._cable_ties_panel, amount);
end

function MUITeammate:set_cable_tie(data)
	-- Lest we get some kinnae dimeritium cable ties for sorceress civs, ain't no need to set the ruddy cable tie icon every time.
	self:set_cable_ties_amount(data.amount);
end

function MUITeammate:set_deployable_equipment(data)
	local icon, texture_rect = tweak_data.hud_icons:get_icon_data(data.icon);
	self._deployable_equipment_icon:set_image(icon, unpack(texture_rect));
	self._deployable_equipment_icon:set_visible(true);
	self._deployable_equipment_text:set_visible(true);
	self:set_deployable_equipment_amount(1, data);
end
function MUITeammate:set_deployable_equipment_from_string(data)
	data.alt = data.amount[2] or 0;
	data.amount = data.amount[1] or 0;
	self:set_deployable_equipment(data);
end
function MUITeammate:set_deployable_equipment_amount(index, data)
	self:set_equipment_amount(self._deployable_equipment_panel, data.amount, data.alt);
end
function MUITeammate:set_deployable_equipment_amount_from_string(index, data)
	data.alt = data.amount[2] or 0;
	data.amount = data.amount[1] or 0;
	self:set_deployable_equipment_amount(index, data);
end

function MUITeammate:set_grenades(data)
	if not PlayerBase.USE_GRENADES then return; end

	local icon, texture_rect = tweak_data.hud_icons:get_icon_data(data.icon, { 0, 0, 32, 32 });
	self._grenades_icon:set_image(icon, unpack(texture_rect));
	self._grenades_icon_ghost:set_image(icon, unpack(texture_rect));
	self:set_grenades_amount(data);
end

function MUITeammate:set_grenades_amount(data)
	if not PlayerBase.USE_GRENADES then return; end

	self._grenades_icon:set_color(data.amount == 0 and Color(0.5, 1, 1, 1) or Color.white);
	self:set_equipment_amount(self._grenades_panel, data.amount, 0);
end


MUITeammate._mui_base.set_grenade_cooldown = MUITeammate.set_grenade_cooldown;
function MUITeammate:set_grenade_cooldown(data)
	if not PlayerBase.USE_GRENADES then return; end

	if data and data.duration and data.end_time then
		self._equipment_list:set_persistent_panel(self._grenades_panel, true);
	end
	return self._mui_base.set_grenade_cooldown(self, data);
end

function MUITeammate:set_ai(ai)
	self._ai = ai;
	self:redisplay_panel();
end

-- Prevent this function from rearranging the name panels, they're fine where they are
function MUITeammate:set_state(state)
	local is_player = state == "player";
	self:set_gear_visible(is_player);
end

function MUITeammate.align_panels()
	local mates = managers.hud._teammate_panels;
	local gap = MUITeammate._muiGap;
	local hPos = MUITeammate._muiHPos;
	local vPos = MUITeammate._muiVPos;
	local hMarg = MUITeammate._muiHMarg;
	local vMarg = MUITeammate._muiVMarg;
	local order = MUITeammate._muiOrder;
	local jtfy = MUITeammate._muiJustify;
	local dir = MUITeammate._muiDir;
	local team = managers.hud._mui_team;

	local players = HUDManager.PLAYER_PANEL;
	local wMax = 0;
	local hMax = 0;
	local wSum = gap * (players - 1);
	local hSum = wSum;
	local vert = dir == 2;

	for i = players, 1, -1 do
		local w, h = mates[i]._panel:size();
		wMax = max(wMax, w);
		hMax = max(hMax, h);
		wSum = wSum + w;
		hSum = hSum + h;
	end

	Figure(team):shape(vert and wMax or wSum, vert and hSum or hMax):align(hPos, vPos, hMarg, vMarg);
	team:set_direction(dir);
	team:set_order(order);
	team:set_align(vert and vPos or hPos);
	team:set_justify(jtfy > 0 and jtfy or (vert and hPos or vPos));
	team:set_margin(gap);
	team:reposition();
	ArmStatic.align_corners(team);
end

--------------------- POCO_COMP ------------------------
function MUITeammate.ph_align()
	--The main PocoHUD3 class name appears to have changed to this at some point.
	--And might as well check if PocoHud3Class exists as well while we're at it.
	if not TPocoHud3 or not PocoHud3Class then return end

	local team = managers.hud._mui_team;
	local mates = managers.hud._teammate_panels;
	local players = HUDManager.PLAYER_PANEL;
	local xOff, yOff = 0, 0;

	local pho = PocoHud3Class.O;
	if pho then
		local bottom = pho:get("playerBottom");
		xOff, yOff = bottom.offsetX or 0, bottom.offset or 0;
	end

	for i = players, 1, -1 do
		local mate = mates[i];
		local ph = mate:ph_panel();
		if ph then
			local panel = mate._panel;
			local x, y = panel:world_position();
			local w, h = panel:size();
			ph:set_world_position(x + (w - ph:w()) * 0.5 + xOff, y + h + yOff);
		end
	end
end

function MUITeammate:ph_panel()
	if not self._ph and not self._ai and TPocoHud3 then
		local peer_id = self._peer_id or (self._main_player and ArmStatic.tunnel(managers, "network", "session", "local_peer", "id"));
		self._ph = peer_id and TPocoHud3["pnl_" .. peer_id];
	end
	return self._ph;
end
------------------------------------------------------


function MUITeammate:set_name(teammate_name)
	if self._base_name == teammate_name then return; end

	self._old_name = self._base_name;
	self._base_name = teammate_name;
	self:redisplay_name(true);
end

function MUITeammate:restore_name()
	if not self._old_name then return; end

	self._base_name = self._old_name;
	self._old_name = nil;
	self:redisplay_name(true);
end

function MUITeammate:redisplay_name(force)
	local name = self._base_name;
	local waiting = self._waiting;
	local size = self._muiSizeS;
	local upper = self._muiUpper;
	local clean = (self._main_player and self._muiCleanL) or self._muiCleanS or 0;
	local nameOpt = clean + (upper and 1 or 0);

	if (not name or self._nameOpt == nameOpt) and not force then return; end
	self._nameOpt = nameOpt;

	if not waiting and clean == 5 then
		name = "";
	elseif not waiting and clean == 4 and self:criminal() then
		name = managers.localization:text("menu_" .. self:criminal().name);
	elseif (clean == 3) or (clean == 2 and name:len() > 19) then
		name = ArmStatic.clean_name(name);
		name = name:len() > 0 and name or managers.localization:text("menu_" .. self:criminal().name);
		if not self._main_player then
			local name_len = name:len();
			local name_font = size / math.min(math.max(3, name_len / 6), 5); -- Dynamic scaling of font size

			self._name:set_font_size(name_font);
		end
	else
		if not self._main_player then
			self._name:set_font_size(size/3);
		end
	end

	if upper then name = utf8.to_upper(name); end
	self._name:set_text(name);
end

function MUITeammate:redisplay_panel()
	local visible = false;
	if self._waiting then
		visible = true;
	elseif self._ai then
		visible = self._muiAI;
	else
		visible = self._taken;
	end

	if visible == self._visible then return; end
	self._visible = visible;
	self._parent:set_visible_panel(self._panel, visible);
end


function MUITeammate.load_options(force_load)
	if MUITeammate._options and not force_load then return; end

	local data = MUIMenu._data;
	MUITeammate._muiSizeL = data.mui_player_size or 42;
	MUITeammate._muiSizeS = data.mui_team_size or 30;
	MUITeammate._muiAlphaL = (data.mui_player_alpha or 100)*0.01;
	MUITeammate._muiAlphaS = (data.mui_team_alpha or 75)*0.01;
	MUITeammate._muiCleanL = data.mui_player_clean or 2;
	MUITeammate._muiCleanS = data.mui_team_clean or 2;
	MUITeammate._muiRevL = data.mui_player_revives ~= false;
	MUITeammate._muiRevS = data.mui_team_revives ~= false;
	MUITeammate._muiAbsL = data.mui_player_absorb ~= false;
	MUITeammate._muiAbsS = data.mui_team_absorb ~= false;
	MUITeammate._muiAI = data.mui_team_ai ~= false;
	MUITeammate._muiStam = data.mui_player_stamina == true;
	MUITeammate._muiDmg = data.mui_player_damage == true;
	MUITeammate._muiDir = data.mui_direction or 1;
	MUITeammate._muiSpcLD = data.mui_player_sp_dock or 3;
	MUITeammate._muiSpcLJ = data.mui_player_sp_jtfy or 2;
	MUITeammate._muiSpcLR = data.mui_player_sp_row or 1;
	MUITeammate._muiSpcSD = data.mui_team_sp_dock or 3;
	MUITeammate._muiSpcSJ = data.mui_team_sp_jtfy or 2;
	MUITeammate._muiSpcSR = data.mui_team_sp_row or 1;
	MUITeammate._muiHPos = data.mui_gen_h_position or 3;
	MUITeammate._muiVPos = data.mui_gen_v_position or 3;
	MUITeammate._muiHMarg = data.mui_gen_h_margin or 0;
	MUITeammate._muiVMarg = data.mui_gen_v_margin or 0;
	MUITeammate._muiHPASPD = (data.mui_gen_hp_aspd or 500)*0.001;
	MUITeammate._muiSHASPD = (data.mui_gen_sh_aspd or 300)*0.001;
	MUITeammate._muiOrder = data.mui_order or 1;
	MUITeammate._muiUpper = data.mui_name_upper ~= false;
	MUITeammate._muiGap = data.mui_gap_size or 4;
	MUITeammate._muiJustify = (data.mui_gen_jtfy or 1)-1;
	MUITeammate._muiSHide = data.mui_begin_hidden ~= false;
	MUITeammate._muiFont = data.mui_font_pref or 4;
	MUITeammate._muiAmmo = data.mui_ammo or 1;
	if MUITeammate._muiColor == nil then
		MUITeammate._muiColor = MUIMenu:Assets() and data.mui_hp_color ~= false or data.mui_hp_color == true;
	end
	MUITeammate._options = true;
end

function MUITeammate.resize_all()
	MUITeammate.load_options(true);
	for _, ch in ipairs(managers.hud._teammate_panels) do
		ch:resize();
	end
	MUITeammate:align_panels();
	MUILegend.resize_all();
end

function MUITeammate.toggle_layer(force_state)
	local team = managers.hud._mui_team;
	if not team then return; end

	local panel = team._panel;
	local mates = team:children();

	if panel:layer() <= 0 or force_state then
		panel:set_layer(1200);
		ArmStatic.create_corners(panel);
		for i=1, #mates do
			ArmStatic.create_corners(mates[i], Color.green);
		end
	else
		panel:set_layer(0);
		ArmStatic.remove_corners(panel);
		for i=1, #mates do
			ArmStatic.remove_corners(mates[i]);
		end
	end
end

function MUITeammate:set_gear_visible(state)
	-- Animations on player panel are stopped on second yield, unsure why.
	-- Oh yeah, the equipment list's a faux panel. That'd do it.
	-- Workaround: Placing animation on 'is bugger who's never had a useful day in his life.
	local bg = self._name_bg;
	bg:stop();
	bg:animate(callback(self._player_panel, ArmStatic, "fade", {state and 1 or 0, 1}));
end

function MUITeammate:set_talking(state)
	self._info_list:set_visible_panel(self._talk_icon, state);
end


function MUITeammate:set_max_stamina(val)
	self._max_stamina = val;
end
function MUITeammate:set_stamina(val)
	if self._muiStam and val ~= self._stamina then
		local si, new_r = self._stamina_icon, val / self._max_stamina;
		self._stamina = val;

		si:set_color(Color(new_r, 1, 1));
		if not si:visible() and new_r < 0.5 then
			self._info_list:set_visible_panel(si, true);
		elseif si:visible() and new_r > 0.9 then
			self._info_list:set_visible_panel(si, false);
		end
	end
end

-- Set local revives variable and display warning if last life.
function MUITeammate:set_revives(revives)
--	revives = revives or self._revives-1;
	local player = self._main_player and self._muiRevL
	local team = self._muiRevS and not self._main_player
	local visible = team or player
	self._info_list:set_visible_panel(visible and self._revives_icon, revives == 1);
--	self._down = false;
	self._revives = revives;
end

-- Find and/or return criminal for panel
function MUITeammate:criminal()
	if not self._criminal then
		local criminals = managers.criminals:characters();
		local peer_id = self._peer_id or (self._main_player and ArmStatic.tunnel(managers, "network", "session", "local_peer", "id"));
		for i=1, #criminals do
			local criminal = criminals[i];
			if (criminal.peer_id ~= nil and criminal.peer_id == peer_id) or (criminal.data and criminal.data.panel_id == self._id) then
				self._criminal = criminal;
			end
		end
	end
	return self._criminal;
end

function MUITeammate:remove_panel()
	self._special_list:clear();

	self:set_condition("mugshot_normal");
	self._carry_panel:set_visible(false);
	self._absorb_health:set_color(Color.black);
	self._absorb_shield:set_color(Color.black);
	self._delayed_health:set_color(Color.black);
	self._delayed_shield:set_color(Color.black);
	self._info_list:set_visible_panel(self._muiRevS and not self._main_player and self._revives_icon, false);
	if self._radial_rip then self._radial_rip:hide(); end
	self:set_cheater(false);
	self:set_info_meter({
		current = 0,
		total = 0,
		max = 1
	});

	self:stop_timer();
	self:defaults();
	self:teammate_progress(false, false, false, false);
	self._peer_id = nil;
	self._ai = nil;
	self._ph = nil;
	self._criminal = nil;
	self._taken = nil;
	self:redisplay_panel();
end

function MUITeammate:position_name()
	local player = self._player_panel;
	local carry = self._carry_panel;
	Figure(self._name):leech(player):attach(carry:visible() and carry, 2);
end

function MUITeammate:set_carry_info()
	self._carry_panel:set_visible(true);
	self:position_name();
end
function MUITeammate:remove_carry_info()
	self._carry_panel:set_visible(false);
	self:position_name();
end

function MUITeammate:set_health(data)
	self._health_data = data;
	MUISetNewHealthValue(self);
	-- local dt, dc, dr = data.total, data.current, data.revives;
	local dt, dc = data.total, data.current;
	local hp, rip = self._radial_health, self._radial_rip;
	local radial_rip_bg = self.radial_rip_bg;
	local red = data.current / data.total;
	-- This will attempt to wean out whether a team member was downed.
	-- It does not account for joining mid-game as I'm trying to keep it simple, and babysitting other players is not really your job anyway.
	-- if MUITeammate._muiRevL and dr and dr ~= self._revives then
		-- self:set_revives(dr);
		--if MUITeammate._muiRevS and not self._main_player then
		if not self._custardy and dc <= 0 then
			-- if data.no_hint then
			self._custardy = true;
			-- self:set_revives(4);
			self._info_list:set_visible_panel(self._muiRevS and not self._main_player and self._revives_icon, false);
			self._info_list:set_visible_panel(self._muiStam and self._main_player and self._revives and self._revives < 2 and self._stamina_icon:visible() and self._stamina_icon, false);
		-- else
			-- self._crimedad = true;
		-- end
		end
		if dc > 0 then
			-- self._custardy, self._crimedad = false, false;
			self._custardy = false;
			-- if self._down then
			-- self:set_revives();
		-- end
		end
	--end

	if managers.player:has_activate_temporary_upgrade("temporary", "copr_ability") and self._id == HUDManager.PLAYER_PANEL and not MUIMenu._data.mui_disable_leech_support then
		local static_damage_ratio = managers.player:upgrade_value_nil("player", "copr_static_damage_ratio");
		hp:stop();

		if static_damage_ratio then
			red = math.floor((red + 0.01) / static_damage_ratio) * static_damage_ratio;
		end

		local copr_overlay_panel = self.copr_overlay_panel;

		if alive(copr_overlay_panel) then
			for _, notch in ipairs(copr_overlay_panel:children()) do
				notch:set_visible(notch:script().red <= red + 0.01);
			end
		end

		if red < hp:color().red then
			self:_damage_taken();
			hp:set_color(Color(1, red, 1, 1));
		else
			hp:animate(function (o)
				local s = hp:color().r;
				local e = red;
				local health_ratio = nil;

				over(0.2, function (p)
					health_ratio = math.lerp(s, e, p);

					hp:set_color(Color(1, health_ratio, 1, 1));

					if alive(copr_overlay_panel) then
						for _, notch in ipairs(copr_overlay_panel:children()) do
							notch:set_visible(notch:script().red <= health_ratio + 0.01);
						end
					end
				end)
			end)
		end
	end

	if self._main_player and rip:visible() then
		self:rot_radial(rip, dc, dt, self._muiHPASPD);
	end

	self:set_radial(hp, (self._muiColor and dt - dc or dc), dt, self._muiHPASPD);
	self:update_delayed_damage();
	self:update_absorb();
end

function MUITeammate:set_stored_health(shr)
	local rip = self._radial_rip;
	if self._main_player then
		if shr > 0 then rip:show(); end
		self:set_radial(rip, shr, 1, self._muiHPASPD);
	end
end

function MUITeammate:set_armor(data)
	self._armor_data = data;
	MUISetNewArmorValue(self);
	self:set_radial(self._radial_shield, data.current, data.total, self._muiSHASPD);
	self:update_delayed_damage();
	self:update_absorb();
end

function MUITeammate:_damage_taken()
	if not self._muiDmg then return; end
	local damage = self._damage_indicator;
	damage:stop();
	damage:animate(callback(self, self, "_animate_damage_taken"));
end

function MUITeammate:set_radial(radial, cur, tot, aspd, flx)
	flx = flx or 0;
	local n_cur, n_flx = cur / tot, 1 - flx / tot;
	local name, clr = radial:name(), radial:color();
	local diff = abs((n_cur - clr.r) + (n_flx - clr.g));

	if diff == 0 then return; end
	radial:stop(self._fade_threads[name]);
	local n_col = Color(1, n_cur, n_flx, 1);
	self._fade_threads[name] = fade_c(radial, n_col, aspd);
end

function MUITeammate:rot_radial(radial, cur, tot, aspd)
	local n_rot, name = (1 - cur / tot)*360, radial:name();
	local diff = abs(n_rot - radial:rotation());
	if diff == 0 then return; end
	radial:stop(self._rot_threads[name]);
	self._rot_threads[name] = rotate(radial, n_rot, aspd);
end

local visibility = function (o, v, a) o:set_visible(v); if a then o:set_alpha(a); end end
function MUITeammate:teammate_progress(enabled, tweak_data_id, timer, complete)
	local health = self._radial_health_panel;
	local progress = self._interact_progress;
	local success = self._interact_success;

	fade(health, enabled and 0.2 or 1);

	progress:stop();
	visibility(progress, not complete, enabled and 0);
	visibility(success, complete, 1);
	if not complete then
		if enabled then progress:animate(callback(progress, ArmStatic, "animate_progress", timer)); end
		fade(progress, enabled and 1 or 0);
	else
		-- if self._revives < 4 and (tweak_data_id == "doctor_bag" or tweak_data_id == "firstaid_box") then
			-- self:set_revives(4);
		-- end
		success:stop();
		fade(success, 0);
	end
end

function MUITeammate:start_timer(time)
	--local loc_player = managers.player:local_player();
	local cont = self._condition_timer;
	self._timer, self._timer_paused = time, 0;

	-- if not self._main_player and alive(loc_player) then
		-- "FUCK!", a buddy is out of commission.
		-- Put this line on its own in a file and assign to a key in the mod.txt for explicit-spam, if'n that's your thing.
		-- loc_player:sound():say( "g29", true, true );
	-- end

	-- if self._crimedad then
		-- local state_name = tunnel(self, "criminal", "unit", "movement", "current_state_name");
		-- if state_name == "bleed_out" then
			-- self._down = true;
		-- end
	-- end

	cont:set_color(self._comp_color);
	cont:stop(); cont:show();
	cont:animate(callback(self, self, "countdown", time));
end

function MUITeammate:set_pause_timer(pause)
	if not self._timer_paused then return; end
	self._timer_paused = self._timer_paused + (pause and 1 or -1);
end

function MUITeammate:countdown(time)
	local t, dt, old_t = time, 0, time;
	local o = self._condition_timer;
	o:set_text(format("%02d", old_t));
	local r, b = Color.red, o:color();
	while t > 0 do
		dt = coroutine.yield();
		if self._timer_paused == 0 then
			t = t - dt;
			if t > 0 and t < old_t then
				old_t = floor(t);
				o:set_text(format("%02d", old_t));
				if old_t <= 10 then
					o:set_color(r);
					fade_c(o, b, 0.5);
				end
			end
		end
	end
end

MUITeammate._mui_base.set_absorb_active = MUITeammate.set_absorb_active;
function MUITeammate:set_absorb_active(absorb_amount)
	local result = self._mui_base.set_absorb_active(self, absorb_amount);
	self:update_absorb();
	return result;
end

function MUITeammate:update_absorb()
	if self._absorb_old + self._absorb_active_amount ~= 0 then
		self:set_radial_overlay(self._absorb_health, self._absorb_shield, self._absorb_active_amount or 0);
		self._absorb_old = self._absorb_active_amount;
	end
end

function MUITeammate:update_delayed_damage()
	if not MUIMenu._data.mui_enable_health_numbers and self._delayed_old + self._delayed_damage ~= 0 then
		self:set_radial_overlay(self._delayed_health, self._delayed_shield, self._delayed_damage or 0);
		self._delayed_old = self._delayed_damage;
	end
end

function MUITeammate:set_radial_overlay(roh, ros, val)
	local d_hp, d_sh = self._health_data, self._armor_data;
	local cur_sh, tot_sh = d_sh.current, d_sh.total;
	local cur_hp, tot_hp = d_hp.current, d_hp.total;

	local ovl_sh = val < cur_sh and val or cur_sh;
	val = val - cur_sh;
	local ovl_hp = val < cur_hp and val or cur_hp;

	self:set_radial(ros, ovl_sh, tot_sh, self._muiSHASPD, cur_sh);
	self:set_radial(roh, ovl_hp, tot_hp, self._muiHPASPD, cur_hp);
end

function MUITeammate:set_copr_indicator(enabled, static_damage_ratio)
	if MUIMenu._data.mui_disable_leech_support then
		return;
	end

	local teammate_panel = self._panel:child("player");
	local radial_health_panel = self._radial_health_panel;
	local copr_overlay_panel = radial_health_panel:child("copr_overlay_panel");
	local radial_health = radial_health_panel:child("radial_health");
	local red = radial_health:color().r;
	local main = self._main_player;
	local size = main and self._muiSizeL or self._muiSizeS;
	local notch_size = 7;
	if size > 20 then
		notch_size = ((size/1.5) * 1)/2;
	end

	if alive(copr_overlay_panel) then
		copr_overlay_panel:clear();
		copr_overlay_panel:set_visible(enabled);

		if enabled then
			local num_notches = math.ceil(1 / static_damage_ratio);
			local rotation = nil;
			local cx, cy = copr_overlay_panel:center();
			local v1 = Vector3();
			local v2 = Vector3();
			local v3 = Vector3();
			local mset = mvector3.set_static;
			local x, y = nil;
			local w = 5;
			local h = math.min(copr_overlay_panel:w(), copr_overlay_panel:h()) / 6;

			for i = 0, num_notches - 1 do
				rotation = i / num_notches * 360;
				x = cx + math.sin(rotation) * notch_size;
				y = cy - math.cos(rotation) * notch_size;

				mset(v1, 0, h, 0);
				mset(v2, w, h, 0);
				mset(v3, w / 2, 0, 0);

				local notch = copr_overlay_panel:polygon({
					layer = 0,
					name = tostring(i),
					color = Color.black:with_alpha(0.6),
					rotation = rotation,
					triangles = {
						v1,
						v2,
						v3
					},
					w = w,
					h = h
				});
				notch:script().red = 1 - i / num_notches;

				notch:set_visible(notch:script().red <= red + 0.01);
				notch:set_center(x, y);
			end
		end
	end
end

function MUITeammate:set_info_meter(data)
	local rim = self._info_meter;
	rim:set_visible(data.total > 0);
	self:set_radial(rim, data.current, data.max, self._muiHPASPD);
end

function MUITeammate:set_ability_icon(icon)
	local texture, texture_rect = tweak_data.hud_icons:get_icon_data(icon, { 0, 0, 32, 32 });
	self._ability_icon:set_image(texture, unpack(texture_rect));
end

function MUITeammate:set_ability_radial(data)
	local r = data.current / data.total;
	self._ability_meter:set_color(Color(1, r, 1, 1));
	self._radial_ability:set_visible(r > 0);
end

function MUITeammate:set_custom_radial(data)
	local radial_custom = self._radial_custom;
	local r = data.current / data.total;
	radial_custom:set_color(Color(1, r, 1, 1));
	radial_custom:set_visible(r > 0);
	self._info_list:set_visible_panel(self._muiStam and self._main_player and self._revives and self._revives < 2 and r and r > 0 and self._stamina_icon:visible() and self._stamina_icon, false);
end