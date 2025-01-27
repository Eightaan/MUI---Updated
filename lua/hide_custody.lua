Hooks:PostHook(PlayerManager, "change_stockholm_syndrome_count", "MUI_PlayerManager_change_stockholm_syndrome_count", function (self, ...)
	if managers.hud and managers.hud._hud_player_custody and managers.hud._hud_player_custody.hide then
		managers.hud._hud_player_custody:hide(false)
	end
end)
