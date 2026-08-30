package luaconfig

import (
	"os"
	"path/filepath"
	"testing"
)

func TestModuleToRelPath(t *testing.T) {
	tests := map[string]string{
		"advs.binds":      filepath.Join("advs", "binds.lua"),
		"advs/binds-user": filepath.Join("advs", "binds-user.lua"),
		"awesome/anim":    filepath.Join("awesome", "anim.lua"),
		"awesome.colors":  filepath.Join("awesome", "colors.lua"),
		" awesome.binds ": filepath.Join("awesome", "binds.lua"),
	}

	for input, want := range tests {
		if got := ModuleToRelPath(input); got != want {
			t.Fatalf("ModuleToRelPath(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestRequiresSkipsComments(t *testing.T) {
	if modules := Requires(`-- require("advs.binds")`); len(modules) != 0 {
		t.Fatalf("expected commented require to be ignored, got %#v", modules)
	}

	modules := Requires(`print("-- not a comment") require("advs.binds") -- require("ignored")`)
	if len(modules) != 1 || modules[0] != "advs.binds" {
		t.Fatalf("unexpected modules: %#v", modules)
	}
}

func TestRequiresTargetRecurses(t *testing.T) {
	tmpDir := t.TempDir()
	advsDir := filepath.Join(tmpDir, "advs")
	if err := os.MkdirAll(advsDir, 0o755); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(advsDir, "windowrules.lua")
	if err := os.WriteFile(filepath.Join(tmpDir, "hyprland.lua"), []byte(`require("advs.extra")`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(advsDir, "extra.lua"), []byte(`require("advs.windowrules")`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(target, []byte(`-- rules`), 0o644); err != nil {
		t.Fatal(err)
	}

	if !RequiresTarget(filepath.Join(tmpDir, "hyprland.lua"), target, make(map[string]bool)) {
		t.Fatal("expected recursive require lookup to find target")
	}
}
