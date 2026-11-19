-- 조명·분위기 (Technology는 MCP 권한으로 못 바꿈: 새 스튜디오 기본값 사용)
local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 15.2
Lighting.GeographicLatitude = 37.5
Lighting.Brightness = 2.6
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.25
Lighting.Ambient = Color3.fromRGB(70, 70, 80)
Lighting.OutdoorAmbient = Color3.fromRGB(135, 140, 150)
Lighting.ExposureCompensation = 0.1
local function ensure(class, name)
	local x = Lighting:FindFirstChild(name)
	if not x then x = Instance.new(class); x.Name = name; x.Parent = Lighting end
	return x
end
local atm = ensure("Atmosphere", "YP_Atmosphere")
atm.Density = 0.3; atm.Offset = 0.12; atm.Color = Color3.fromRGB(199, 210, 225); atm.Decay = Color3.fromRGB(110, 125, 150); atm.Glare = 0.25; atm.Haze = 1.6
local bloom = ensure("BloomEffect", "YP_Bloom")
bloom.Intensity = 0.5; bloom.Size = 28; bloom.Threshold = 1.6
local cc = ensure("ColorCorrectionEffect", "YP_Color")
cc.Brightness = 0.02; cc.Contrast = 0.12; cc.Saturation = 0.12; cc.TintColor = Color3.fromRGB(255, 250, 244)
local rays = ensure("SunRaysEffect", "YP_SunRays")
rays.Intensity = 0.06; rays.Spread = 0.8
return "lighting ok"
