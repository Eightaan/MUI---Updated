local MUIMenu = MUIMenu;

function MUIMenu:LoadAssets(key, path)
	DB:create_entry(Idstring("texture"), Idstring(key), path);
end

function MUIMenu:Assets()
	local data = self:Load();
	local path = self._path;
	if data.mui_custom_textures then
		self:LoadAssets("guis/dlcs/coco/textures/pd2/hud_absorb_stack_fg", path.."assets/hud_absorb_stack_fg.texture");
		self:LoadAssets("guis/dlcs/coco/textures/pd2/hud_absorb_health", path.."assets/hud_absorb_health.texture");
		self:LoadAssets("guis/dlcs/coco/textures/pd2/hud_absorb_shield", path.."assets/hud_absorb_shield.texture");
		self:LoadAssets("guis/textures/pd2/hud_stealth_exclam", path.."assets/hud_stealth_exclam.texture");
		self:LoadAssets("guis/textures/pd2/hud_stealthmeter", path.."assets/hud_stealthmeter.texture");
		self:LoadAssets("guis/textures/pd2/hud_stealth_eye", path.."assets/hud_stealth_eye.texture");
		self:LoadAssets("guis/textures/pd2/hud_fearless", path.."assets/hud_fearless.texture");
		self:LoadAssets("guis/textures/pd2/hud_health", path.."assets/hud_health.texture");
		self:LoadAssets("guis/textures/pd2/hud_shield", path.."assets/hud_shield.texture");
		self:LoadAssets("guis/textures/pd2/hud_rip", path.."assets/hud_rip.texture");
	end
end
MUIMenu:Assets();