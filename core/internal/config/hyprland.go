package config

import _ "embed"

//go:embed embedded/hyprland.lua
var HyprlandLuaConfig string

//go:embed embedded/hypr-colors.lua
var ADVSColorsLuaConfig string

//go:embed embedded/hypr-layout.lua
var ADVSLayoutLuaConfig string

//go:embed embedded/hypr-binds.lua
var ADVSBindsLuaConfig string

//go:embed embedded/hypr-outputs.lua
var ADVSOutputsLuaConfig string

//go:embed embedded/hypr-cursor.lua
var ADVSCursorLuaConfig string

//go:embed embedded/hypr-windowrules.lua
var ADVSWindowRulesLuaConfig string

//go:embed embedded/hypr-binds-user.lua
var ADVSBindsUserLuaConfig string
