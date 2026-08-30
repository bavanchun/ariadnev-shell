-- Minimal Hyprland (Lua) session for greetd — replace _ADVS_PATH_ with your ADVS checkout.
-- Copy to `/etc/greetd/advs-hypr.lua` alongside `greet-hyprland.sh`.

hl.env("ADVS_RUN_GREETER", "1")

hl.on("hyprland.start", function()
	hl.exec_cmd('sh -c "qs -p _ADVS_PATH_; hyprctl dispatch exit"')
end)
