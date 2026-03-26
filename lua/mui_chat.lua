--------
-- MUI <https://paydaymods.com/mods/44/arm_mui>
-- Copyright (C) 2015 Armithaig
-- License GPLv3 <https://www.gnu.org/licenses/>
--
-- Inquiries should be submitted by email to <mui@amaranth.red>.
--------
_G.MUIChat = _G.MUIChat or class(HUDChat);
ArmStatic.void(MUIChat, {
	"_create_input_panel","_layout_input_panel",
	"_layout_output_panel"
});

local insert, remove = table.insert, table.remove;

function MUIChat:init(ws, hud)
	self.load_options();
	self._ws = ws;
	self._hud_panel = hud.panel;
	self:set_channel_id(ChatManager.GAME);
	self._lines = {};
	self._font = ArmStatic.font_index(self._muiFont);
	self._freeze = false;
	self._esc_callback = callback(self, self, "esc_key_callback");
	self._enter_callback = callback(self, self, "enter_key_callback");
	self._typing_callback = 0;
	self._skip_first = false;
	self._panel = self._hud_panel:panel({
		name = "chat_panel"
	});
	self._output_panel = self._panel:panel({
		name = "output_panel",
		layer = 1
	});
	self._output_panel:panel({
		name = "output_bg"
	});
	self._input_panel = self._panel:panel({
		alpha = 0,
		name = "input_panel",
		layer = 1
	});
	self._input_panel:text({
		name = "say",
		text = utf8.to_upper(managers.localization:text("debug_chat_say")) .. " ",
		font = self._font,
		align = "left",
		halign = "left",
		vertical = "center",
		hvertical = "center",
		blend_mode = "normal",
		color = Color.white,
		layer = 1
	});
	self._input_panel:text({
		name = "input_text",
		text = "",
		font = self._font,
		align = "left",
		halign = "left",
		vertical = "center",
		hvertical = "center",
		blend_mode = "normal",
		color = Color.white,
		layer = 1,
		wrap = true,
		word_wrap = false
	});
	self._input_panel:rect({
		name = "caret",
		layer = 2,
		color = Color(0.05, 1, 1, 1)
	});
	self._input_panel:panel({
		name = "input_bg"
	});
	self._scroll_offset = 0;
	self._line_counts = {};
	self._total_lines = 0;
	self:resize();
end

function MUIChat:update_caret()
	local text = self._input_panel:child("input_text");
	local caret = self._input_panel:child("caret");
	local s, e = text:selection();
	local x, y, w, h = text:selection_rect();
	if s == 0 and e == 0 then
		if text:align() == "center" then
			x = text:world_x() + text:w() / 2;
		else
			x = text:world_x();
		end
		y = text:world_y();
	end
	h = text:h();
	if not self._focus then
		w = 0;
		h = 0;
	end
	caret:set_world_shape(x, y, w, h);
	self:set_blinking(s == e and self._focus);
end

function MUIChat:set_scroll_indicators(force_update_scroll_indicators)
end

function MUIChat:scroll_up()
	local s10 = self._muiSize / 10;
	local space = self._muiLSpacing;
	local step = s10 + space;
	local max_scroll = math.max(0, self._total_lines * step - self._muiRows * step);

	if self._scroll_offset < max_scroll then
		self._scroll_offset = self._scroll_offset + step;
		self._scroll_offset = math.floor(self._scroll_offset / step) * step;
		self._scroll_offset = math.min(self._scroll_offset, max_scroll);
		self:resize_lines();
	end
end

function MUIChat:scroll_down()
	local s10 = self._muiSize / 10;
	local space = self._muiLSpacing;
	local step = s10 + space;

	if self._scroll_offset > 0 then
		self._scroll_offset = self._scroll_offset - step;
		self._scroll_offset = math.ceil(self._scroll_offset / step) * step;
		self._scroll_offset = math.max(0, self._scroll_offset);
		self:resize_lines();
	end
end

function MUIChat:set_output_alpha(alpha)
	self._panel:child("output_panel"):set_alpha(alpha);
end

function MUIChat.load_options(force_load)
	if MUIChat._options and not force_load then return; end

	local data = MUIMenu._data;
	local size = data.mui_chat_size or 200;

	size = math.floor(size / 5 + 0.5) * 5;
	MUIChat._muiSize = size;
	MUIChat._muiLSpacing = math.floor(MUIChat._muiSize *0.008);
	MUIChat._muiAlpha = (data.mui_chat_alpha or 100)*0.01;
	MUIChat._muiHMargin = data.mui_chat_h_marg or 60;
	MUIChat._muiVMargin = data.mui_chat_v_marg or 60;
	MUIChat._muiHPos = data.mui_chat_h_pos or 1;
	MUIChat._muiVPos = data.mui_chat_v_pos or 3;
	MUIChat._muiRows = data.mui_chat_rows or 7;
	MUIChat._muiFade = data.mui_chat_fade or 7;
	MUIChat._muiCTime = data.mui_chat_time == true;
	MUIChat._muiMouse = data.mui_mouse_support == true;
	MUIChat._muiFont = data.mui_font_pref or 4;
	MUIChat._options = true;
end

function MUIChat:resize()
	local size = self._muiSize;
	local alpha = self._muiAlpha;
	local s200 = size * 2;
	local s10 = size/10;
	local space = self._muiLSpacing;
	local box = s10 + space;
	local rows = self._muiRows;
	local hPos = self._muiHPos;
	local vPos = self._muiVPos;
	local hMargin = self._muiHMargin;
	local vMargin = self._muiVMargin;

	local panel = self._panel;
	local output = self._output_panel;
	local input = self._input_panel;
	local say = input:child("say");
	local text = input:child("input_text");
	local caret = input:child("caret");
	local bg = input:child("input_bg");

	Figure(output):shape(s200, box * rows);
	Figure(input):shape(s200, box):attach(output, 3);
	Figure(say):rect(s10);
	Figure({text,bg}):shape(s200 - say:w(), box, s10):attach(say, 2);
	Figure(caret):attach(say, 2);

	Figure(panel):view(alpha):adapt():align(hPos, vPos, hMargin, vMargin);
	self:resize_lines();
end

function MUIChat:show()
	for _, ch in ipairs(self._panel:children()) do
		if ch.set_alpha then
			ch:set_alpha(1);
			ch:stop();
		end
	end
	self._freeze = true;
end

function MUIChat:hide()
	for _, ch in ipairs(self._panel:children()) do
		if ch.set_alpha then
			ch:set_alpha(0);
			ch:stop();
		end
	end
	self._freeze = false;
end

function MUIChat.resize_all()
	MUIChat.load_options(true);
	local chating = managers.hud._hud_chat_ingame;
	chating:resize();
	ArmStatic.align_corners(chating._panel);

	managers.hud._hud_chat_access:resize();
end

function MUIChat:resize_lines()
	local s10 = self._muiSize / 10;
	local space = self._muiLSpacing;
	local out = self._output_panel;
	local panel_w = out:w();
	local panel_h = out:h();

	local y = - self._scroll_offset;

	for i = #self._lines, 1, -1 do
		local line = self._lines[i];
		local count = self._line_counts[line] or 1;
		local line_count = count * s10;

		Figure(line):rect(s10, panel_w);
		
		line:set_h(line_count);
		line:set_bottom(panel_h - y);

		y = y + line_count + space;
	end
end

function MUIChat:receive_message(name, message, color, icon)
	local output_panel = self._panel:child("output_panel");
	local t = managers.game_play_central and managers.game_play_central:get_heist_timer() or 0;
	local hours = math.floor(t / 3600);
	local minutes = math.floor(t / 60) % 60;
	local seconds = math.floor(t % 60);

	local time_text = "";
	if self._muiCTime then
		if hours > 0 then
			time_text = string.format("%02d:%02d:%02d ", hours, minutes, seconds);
		else
			time_text = string.format("%02d:%02d ", minutes, seconds);
		end
	end


	local line = output_panel:text({
		text = time_text .. name .. ": " .. message,
		font = self._font,
		wrap = true,
		word_wrap = true,
		layer = 0
	});
	
	local w = output_panel:w();
	local s10 = self._muiSize / 10;
	local space = self._muiLSpacing;
	local rows = self._muiRows;
	local step = s10 + space;
	Figure(line):rect(s10, w);

	local time_len = utf8.len(time_text);
	local name_len = utf8.len(name) + 1;
	local total_len = utf8.len(line:text());

	line:set_range_color(0, time_len, Color(0.7, 0.7, 0.7));
	line:set_range_color(time_len, time_len + name_len, color);
	line:set_range_color(time_len + name_len, total_len, Color.white);
	
	local count = line:number_of_lines();

	self._line_counts[line] = count;
	self._total_lines = self._total_lines + count;
	insert(self._lines, line);

	local max_scroll = math.max(0, self._total_lines * step - rows * step);
	self._scroll_offset = math.min(self._scroll_offset, max_scroll);

	self:resize_lines();
	if not self._focus then
		output_panel:stop();
		output_panel:animate(callback(self, self, "_animate_show_component"), output_panel:alpha());
		output_panel:animate(callback(self, self, "_animate_fade_output"));
	end
end

function MUIChat.toggle_layer(force_state)
	local chating = managers.hud._hud_chat_ingame;
	if not chating then
		return;
	end

	if force_state == false or chating._panel:layer() > 1 then
		chating:hide();
		ArmStatic.remove_corners(chating._panel);
		chating:set_layer(1);
	else
		chating:show();
		ArmStatic.create_corners(chating._panel);
		chating:set_layer(1200);
	end
end

function MUIChat:enter_key_callback()
	self._scroll_offset = 0;
	self:resize_lines();
	self.super.enter_key_callback(self);
end

function MUIChat:esc_key_callback()
	self:disconnect_mouse();
	self._scroll_offset = 0;
	self:resize_lines();
	self.super.esc_key_callback(self);
end

function MUIChat:_animate_fade_output()
    local wait_t = self._muiFade;
    local fade_t = 1;
    local t = 0;

    while wait_t > t do
        local dt = coroutine.yield();
        t = t + dt;
    end
    t = 0;
	
    while fade_t > t do
        local dt = coroutine.yield();
        t = t + dt;
        self:set_output_alpha(1 - t / fade_t);
    end

    self:set_output_alpha(0);
end

function MUIChat:connect_mouse()
	if self._mouse_connected then return; end
	self._mouse_connected = true;
	managers.mouse_pointer:use_mouse({mouse_press = callback(self, self, "_mouse_press"), id = "mui_chat_mouse" });
end

function MUIChat:disconnect_mouse()
	if not self._mouse_connected then return; end
	managers.mouse_pointer:remove_mouse("mui_chat_mouse");
	self._mouse_connected = nil;
end

function MUIChat:_mouse_press(o, button, x, y)
	if button == Idstring("mouse wheel up") then
		self:scroll_up();
	elseif button == Idstring("mouse wheel down") then
		self:scroll_down();
	end
end

function MUIChat:_on_focus()
	if self._focus then return; end

	local out = self._panel:child("output_panel");

	out:stop();
	out:animate(callback(self, self, "_animate_show_output"), out:alpha());
	self._input_panel:stop();
	self._input_panel:animate(callback(self, self, "_animate_show_component"));

	self._focus = true;
	self._ws:connect_keyboard(Input:keyboard());

	if _G.IS_VR then
		Input:keyboard():show();
	end

	self._input_panel:key_press(callback(self, self, "key_press"));
	self._input_panel:key_release(callback(self, self, "key_release"));
	self._enter_text_set = false;

	self:update_caret();
	if self._muiMouse then
		self:connect_mouse();
		managers.mouse_pointer:set_pointer_image("arrow");
	end
end

function MUIChat:_loose_focus()
	if not self._focus then return; end

	self._focus = false;
	self._ws:disconnect_keyboard();
	self._input_panel:key_press(nil);
	self._input_panel:enter_text(nil);
	self._input_panel:key_release(nil);
	self._panel:child("output_panel"):stop();
	self._panel:child("output_panel"):animate(callback(self, self, "_animate_fade_output"));
	self._input_panel:stop();
	self._input_panel:animate(callback(self, self, "_animate_hide_input"));

	self:update_caret();
	if self._muiMouse then
		self:disconnect_mouse();
	end
end