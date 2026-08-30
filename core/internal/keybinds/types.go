package keybinds

type Keybind struct {
	Key             string   `json:"key"`
	Description     string   `json:"desc"`
	Action          string   `json:"action,omitempty"`
	Subcategory     string   `json:"subcat,omitempty"`
	Source          string   `json:"source,omitempty"`
	HideOnOverlay   bool     `json:"hideOnOverlay,omitempty"`
	CooldownMs      int      `json:"cooldownMs,omitempty"`
	Flags           string   `json:"flags,omitempty"` // Hyprland bind flags: e=repeat, l=locked, r=release, o=long-press
	AllowWhenLocked bool     `json:"allowWhenLocked,omitempty"`
	AllowInhibiting *bool    `json:"allowInhibiting,omitempty"` // nil=default(true), false=explicitly disabled
	Repeat          *bool    `json:"repeat,omitempty"`          // nil=default(true), false=explicitly disabled
	Conflict        *Keybind `json:"conflict,omitempty"`
	HasDefault      bool     `json:"hasDefault,omitempty"` // override has a ADVS default to revert to
}

type ADVSBindsStatus struct {
	Exists          bool   `json:"exists"`
	Included        bool   `json:"included"`
	IncludePosition int    `json:"includePosition"`
	TotalIncludes   int    `json:"totalIncludes"`
	BindsAfterADVS  int    `json:"bindsAfterAdvs"`
	Effective       bool   `json:"effective"`
	OverriddenBy    int    `json:"overriddenBy"`
	StatusMessage   string `json:"statusMessage"`
	ConfigFormat    string `json:"configFormat,omitempty"`
	ReadOnly        bool   `json:"readOnly,omitempty"`
}

type CheatSheet struct {
	Title             string               `json:"title"`
	Provider          string               `json:"provider"`
	ModKey            string               `json:"modKey,omitempty"`
	Binds             map[string][]Keybind `json:"binds"`
	ADVSBindsIncluded bool                 `json:"advsBindsIncluded"`
	ADVSStatus        *ADVSBindsStatus     `json:"advsStatus,omitempty"`
}

type Provider interface {
	Name() string
	GetCheatSheet() (*CheatSheet, error)
}

type WritableProvider interface {
	Provider
	SetBind(key, action, description string, options map[string]any) error
	// RemoveBind removes the bind. Hyprland writes a negative override to
	// advs/binds-user.lua; single-file providers delete the line.
	RemoveBind(key string) error
	// ResetBind reverts a user override to its ADVS default. On single-file
	// providers this aliases to RemoveBind.
	ResetBind(key string) error
	GetOverridePath() string
}
