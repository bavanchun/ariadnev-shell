package providers

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/bavanchun/ariadnev-shell/core/internal/luaconfig"
	"github.com/bavanchun/ariadnev-shell/core/internal/utils"
	"github.com/bavanchun/ariadnev-shell/core/internal/windowrules"
)

type HyprlandWindowRule struct {
	MatchClass       string
	MatchTitle       string
	MatchXWayland    *bool
	MatchFloating    *bool
	MatchFullscreen  *bool
	MatchPinned      *bool
	MatchInitialised *bool
	Rule             string
	Value            string
	Source           string
	RawLine          string

	// CombinedActions is populated from single hl.window_rule({ … }) Lua calls where
	// multiple actions apply together. When non-nil it takes precedence over Rule/Value
	// in ConvertHyprlandRulesToWindowRules.
	CombinedActions *windowrules.Actions `json:"-"`
}

type HyprlandRulesParser struct {
	configDir        string
	processedFiles   map[string]bool
	rules            []HyprlandWindowRule
	currentSource    string
	advsRulesExists   bool
	advsPrimaryPath   string // advs/windowrules.lua preferred, else advs/windowrules.conf when present
	advsRulesIncluded bool
	includeCount     int
	advsIncludePos    int
	rulesAfterADVS    int
	advsProcessed     bool
	configFormat     string
	readOnly         bool

	requireLineInMain int    // hyprland.lua line (1-based) where require("advs.windowrules") occurs; else -1
	primaryHyprLua    string // absolute path to ~/.config/hypr/hyprland.lua when that is the main config
}

func NewHyprlandRulesParser(configDir string) *HyprlandRulesParser {
	return &HyprlandRulesParser{
		configDir:         configDir,
		processedFiles:    make(map[string]bool),
		rules:             []HyprlandWindowRule{},
		advsIncludePos:     -1,
		requireLineInMain: -1,
	}
}

func (p *HyprlandRulesParser) Parse() ([]HyprlandWindowRule, error) {
	expandedDir, err := utils.ExpandPath(p.configDir)
	if err != nil {
		return nil, err
	}

	advsLua := filepath.Join(expandedDir, "advs", "windowrules.lua")
	advsConf := filepath.Join(expandedDir, "advs", "windowrules.conf")

	if _, err := os.Stat(advsLua); err == nil {
		p.advsRulesExists = true
		p.advsPrimaryPath = advsLua
	} else if _, err := os.Stat(advsConf); err == nil {
		p.advsRulesExists = true
		p.advsPrimaryPath = advsConf
	}

	mainConfig, err := hyprlandMainConfigPath(expandedDir)
	if err != nil {
		return nil, err
	}

	if strings.EqualFold(filepath.Ext(mainConfig), ".lua") {
		p.configFormat = "lua"
		p.readOnly = false
		p.probeRequireWindowrulesLine(mainConfig)
		if ap, err := filepath.Abs(mainConfig); err == nil {
			p.primaryHyprLua = ap
		}
	} else {
		p.configFormat = "hyprlang"
		p.readOnly = true
	}

	if err := p.parseFile(mainConfig); err != nil {
		return nil, err
	}

	if p.advsRulesExists && !p.advsProcessed {
		p.parseADVSRulesDirectly(p.advsPrimaryPath)
	}

	return p.rules, nil
}

func (p *HyprlandRulesParser) parseADVSRulesDirectly(advsRulesPath string) {
	data, err := os.ReadFile(advsRulesPath)
	if err != nil {
		return
	}

	abs, err := filepath.Abs(advsRulesPath)
	if err != nil {
		abs = advsRulesPath
	}

	prevSource := p.currentSource
	p.currentSource = abs

	if strings.EqualFold(filepath.Ext(abs), ".lua") {
		p.parseLuaWindowRules(string(data), filepath.Dir(abs), abs, false)
	} else {
		lines := strings.SplitSeq(string(data), "\n")
		for line := range lines {
			p.parseLine(line)
		}
	}

	p.currentSource = prevSource
	p.advsProcessed = true
}

func (p *HyprlandRulesParser) parseFile(filePath string) error {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return err
	}

	if p.processedFiles[absPath] {
		return nil
	}
	p.processedFiles[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return nil
	}

	if strings.EqualFold(filepath.Ext(absPath), ".lua") {
		p.parseLuaWindowRules(string(data), filepath.Dir(absPath), absPath, true)
		return nil
	}

	prevSource := p.currentSource
	p.currentSource = absPath

	lines := strings.SplitSeq(string(data), "\n")
	for line := range lines {
		trimmed := strings.TrimSpace(line)

		if strings.HasPrefix(trimmed, "source") {
			p.handleSource(trimmed, filepath.Dir(absPath))
			continue
		}

		p.parseLine(line)
	}

	p.currentSource = prevSource
	return nil
}

func (p *HyprlandRulesParser) handleSource(line string, baseDir string) {
	parts := strings.SplitN(line, "=", 2)
	if len(parts) < 2 {
		return
	}

	sourcePath := strings.TrimSpace(parts[1])
	isADVSSource := isADVSWindowRulesSourcePath(sourcePath)

	p.includeCount++
	if isADVSSource {
		p.advsRulesIncluded = true
		p.advsIncludePos = p.includeCount
		p.advsProcessed = true
	}

	fullPath := sourcePath
	if !filepath.IsAbs(sourcePath) {
		fullPath = filepath.Join(baseDir, sourcePath)
	}

	expanded, err := utils.ExpandPath(fullPath)
	if err != nil {
		return
	}

	_ = p.parseFile(expanded)
}

func (p *HyprlandRulesParser) parseLine(line string) {
	trimmed := strings.TrimSpace(line)

	if strings.HasPrefix(trimmed, "windowrule") {
		rule := p.parseWindowRuleLine(trimmed)
		if rule != nil {
			rule.Source = p.currentSource
			p.rules = append(p.rules, *rule)
		}
	}
}

var windowRuleV2Regex = regexp.MustCompile(`^windowrulev?2?\s*=\s*(.+)$`)

func (p *HyprlandRulesParser) parseWindowRuleLine(line string) *HyprlandWindowRule {
	matches := windowRuleV2Regex.FindStringSubmatch(line)
	if len(matches) < 2 {
		return nil
	}

	content := strings.TrimSpace(matches[1])
	isV2 := strings.HasPrefix(line, "windowrulev2")

	rule := &HyprlandWindowRule{
		RawLine: line,
	}

	if isV2 {
		p.parseWindowRuleV2(content, rule)
	} else {
		p.parseWindowRuleV1(content, rule)
	}

	return rule
}

func (p *HyprlandRulesParser) parseWindowRuleV1(content string, rule *HyprlandWindowRule) {
	parts := strings.SplitN(content, ",", 2)
	if len(parts) < 2 {
		return
	}

	rule.Rule = strings.TrimSpace(parts[0])
	rule.MatchClass = strings.TrimSpace(parts[1])
}

func (p *HyprlandRulesParser) parseWindowRuleV2(content string, rule *HyprlandWindowRule) {
	parts := strings.SplitN(content, ",", 2)
	if len(parts) < 2 {
		return
	}

	ruleAndValue := strings.TrimSpace(parts[0])
	matchPart := strings.TrimSpace(parts[1])

	if idx := strings.Index(ruleAndValue, " "); idx > 0 {
		rule.Rule = ruleAndValue[:idx]
		rule.Value = strings.TrimSpace(ruleAndValue[idx+1:])
	} else {
		rule.Rule = ruleAndValue
	}

	matchPairs := strings.SplitSeq(matchPart, ",")
	for pair := range matchPairs {
		pair = strings.TrimSpace(pair)
		if colonIdx := strings.Index(pair, ":"); colonIdx > 0 {
			key := strings.TrimSpace(pair[:colonIdx])
			value := strings.TrimSpace(pair[colonIdx+1:])

			switch key {
			case "class":
				rule.MatchClass = value
			case "title":
				rule.MatchTitle = value
			case "xwayland":
				b := value == "1" || value == "true"
				rule.MatchXWayland = &b
			case "floating":
				b := value == "1" || value == "true"
				rule.MatchFloating = &b
			case "fullscreen":
				b := value == "1" || value == "true"
				rule.MatchFullscreen = &b
			case "pinned":
				b := value == "1" || value == "true"
				rule.MatchPinned = &b
			case "initialised", "initialized":
				b := value == "1" || value == "true"
				rule.MatchInitialised = &b
			}
		}
	}
}

func (p *HyprlandRulesParser) HasADVSRulesIncluded() bool {
	return p.advsRulesIncluded
}

func (p *HyprlandRulesParser) buildADVSStatus() *windowrules.ADVSRulesStatus {
	status := &windowrules.ADVSRulesStatus{
		Exists:          p.advsRulesExists,
		Included:        p.advsRulesIncluded,
		IncludePosition: p.advsIncludePos,
		TotalIncludes:   p.includeCount,
		RulesAfterADVS:   p.rulesAfterADVS,
		ConfigFormat:    p.configFormat,
		ReadOnly:        p.readOnly,
	}

	switch {
	case !p.advsRulesExists:
		status.Effective = false
		status.StatusMessage = "advs window rules fragment (windowrules.lua / windowrules.conf) does not exist"
	case !p.advsRulesIncluded:
		status.Effective = false
		status.StatusMessage = "advs window rules are not loaded (missing require/source for advs/windowrules)"
	case p.rulesAfterADVS > 0:
		status.Effective = true
		status.OverriddenBy = p.rulesAfterADVS
		status.StatusMessage = "Some ADVS rules may be overridden by config rules"
	default:
		status.Effective = true
		status.StatusMessage = "ADVS window rules are active"
	}

	return status
}

type HyprlandRulesParseResult struct {
	Rules            []HyprlandWindowRule
	ADVSRulesIncluded bool
	ADVSStatus        *windowrules.ADVSRulesStatus
}

func ParseHyprlandWindowRules(configDir string) (*HyprlandRulesParseResult, error) {
	parser := NewHyprlandRulesParser(configDir)
	rules, err := parser.Parse()
	if err != nil {
		return nil, err
	}
	return &HyprlandRulesParseResult{
		Rules:            rules,
		ADVSRulesIncluded: parser.HasADVSRulesIncluded(),
		ADVSStatus:        parser.buildADVSStatus(),
	}, nil
}

func applyHyprlandRuleAction(actions *windowrules.Actions, rule, value string) {
	t := true
	switch rule {
	case "float":
		actions.OpenFloating = &t
	case "tile":
		actions.Tile = &t
	case "fullscreen":
		actions.OpenFullscreen = &t
	case "maximize":
		actions.OpenMaximized = &t
	case "nofocus":
		actions.NoFocus = &t
	case "noborder":
		actions.NoBorder = &t
	case "noshadow":
		actions.NoShadow = &t
	case "nodim":
		actions.NoDim = &t
	case "noblur":
		actions.NoBlur = &t
	case "noanim":
		actions.NoAnim = &t
	case "norounding":
		actions.NoRounding = &t
	case "pin":
		actions.Pin = &t
	case "opaque":
		actions.Opaque = &t
	case "forcergbx":
		actions.ForcergbX = &t
	case "opacity":
		if f, err := strconv.ParseFloat(value, 64); err == nil {
			actions.Opacity = &f
		}
	case "monitor":
		actions.Monitor = value
	case "workspace":
		actions.Workspace = value
	case "idleinhibit":
		actions.Idleinhibit = value
	case "rounding":
		if i, err := strconv.Atoi(value); err == nil {
			actions.CornerRadius = &i
		}
	}
}

func ConvertHyprlandRulesToWindowRules(hyprRules []HyprlandWindowRule) []windowrules.WindowRule {
	result := make([]windowrules.WindowRule, 0, len(hyprRules))
	for i, hr := range hyprRules {
		wr := windowrules.WindowRule{
			ID:      strconv.Itoa(i),
			Enabled: true,
			Source:  hr.Source,
			MatchCriteria: windowrules.MatchCriteria{
				AppID:       hr.MatchClass,
				Title:       hr.MatchTitle,
				XWayland:    hr.MatchXWayland,
				IsFloating:  hr.MatchFloating,
				Fullscreen:  hr.MatchFullscreen,
				Pinned:      hr.MatchPinned,
				Initialised: hr.MatchInitialised,
			},
		}
		if hr.CombinedActions != nil {
			wr.Actions = *hr.CombinedActions
		} else {
			applyHyprlandRuleAction(&wr.Actions, hr.Rule, hr.Value)
		}
		result = append(result, wr)
	}
	return result
}

type HyprlandWritableProvider struct {
	configDir string
}

func NewHyprlandWritableProvider(configDir string) *HyprlandWritableProvider {
	return &HyprlandWritableProvider{configDir: configDir}
}

func (p *HyprlandWritableProvider) Name() string {
	return "hyprland"
}

func (p *HyprlandWritableProvider) GetOverridePath() string {
	expanded, _ := utils.ExpandPath(p.configDir)
	return filepath.Join(expanded, "advs", "windowrules.lua")
}

func (p *HyprlandWritableProvider) GetRuleSet() (*windowrules.RuleSet, error) {
	result, err := ParseHyprlandWindowRules(p.configDir)
	if err != nil {
		return nil, err
	}
	return &windowrules.RuleSet{
		Title:            "Hyprland Window Rules",
		Provider:         "hyprland",
		Rules:            ConvertHyprlandRulesToWindowRules(result.Rules),
		ADVSRulesIncluded: result.ADVSRulesIncluded,
		ADVSStatus:        result.ADVSStatus,
	}, nil
}

func (p *HyprlandWritableProvider) SetRule(rule windowrules.WindowRule) error {
	if err := p.ensureWritableConfig(); err != nil {
		return err
	}
	rules, err := p.LoadADVSRules()
	if err != nil {
		rules = []windowrules.WindowRule{}
	}

	found := false
	for i, r := range rules {
		if r.ID == rule.ID {
			rules[i] = rule
			found = true
			break
		}
	}
	if !found {
		rules = append(rules, rule)
	}

	return p.writeADVSRules(rules)
}

func (p *HyprlandWritableProvider) RemoveRule(id string) error {
	if err := p.ensureWritableConfig(); err != nil {
		return err
	}
	rules, err := p.LoadADVSRules()
	if err != nil {
		return err
	}

	newRules := make([]windowrules.WindowRule, 0, len(rules))
	for _, r := range rules {
		if r.ID != id {
			newRules = append(newRules, r)
		}
	}

	return p.writeADVSRules(newRules)
}

func (p *HyprlandWritableProvider) ReorderRules(ids []string) error {
	if err := p.ensureWritableConfig(); err != nil {
		return err
	}
	rules, err := p.LoadADVSRules()
	if err != nil {
		return err
	}

	ruleMap := make(map[string]windowrules.WindowRule)
	for _, r := range rules {
		ruleMap[r.ID] = r
	}

	newRules := make([]windowrules.WindowRule, 0, len(ids))
	for _, id := range ids {
		if r, ok := ruleMap[id]; ok {
			newRules = append(newRules, r)
			delete(ruleMap, id)
		}
	}

	for _, r := range ruleMap {
		newRules = append(newRules, r)
	}

	return p.writeADVSRules(newRules)
}

func (p *HyprlandWritableProvider) ensureWritableConfig() error {
	if p.isLegacyConfigReadOnly() {
		return fmt.Errorf("hyprland legacy conf configs are read-only; run advs setup to migrate to Lua before editing window rules")
	}
	return nil
}

func (p *HyprlandWritableProvider) isLegacyConfigReadOnly() bool {
	expanded, err := utils.ExpandPath(p.configDir)
	if err != nil {
		expanded = p.configDir
	}
	luaPath := filepath.Join(expanded, "hyprland.lua")
	if st, err := os.Stat(luaPath); err == nil && st.Mode().IsRegular() {
		return false
	}
	confPath := filepath.Join(expanded, "hyprland.conf")
	if st, err := os.Stat(confPath); err == nil && st.Mode().IsRegular() {
		return true
	}
	return false
}

var advsRuleCommentRegex = regexp.MustCompile(`^#\s*ADVS-RULE:\s*id=([^,]+),\s*name=(.*)$`)
var advsRuleLuaHDRRegex = regexp.MustCompile(`^\s*--\s*ADVS-RULE:\s*id=([^,]+),\s*name=(.*)$`)

func hyprLuaBoolStr(b bool) string {
	if b {
		return "true"
	}
	return "false"
}

func hyprLuaExprWrap(v string) string {
	if _, err := strconv.ParseFloat(v, 64); err == nil {
		return v
	}
	return strconv.Quote(v)
}

func luaAppendMatch(mc windowrules.MatchCriteria, dst *[]string) {
	if mc.AppID != "" {
		*dst = append(*dst, fmt.Sprintf(`class = %s`, strconv.Quote(mc.AppID)))
	}
	if mc.Title != "" {
		*dst = append(*dst, fmt.Sprintf(`title = %s`, strconv.Quote(mc.Title)))
	}
	if mc.XWayland != nil {
		*dst = append(*dst, fmt.Sprintf(`xwayland = %s`, hyprLuaBoolStr(*mc.XWayland)))
	}
	if mc.IsFloating != nil {
		*dst = append(*dst, fmt.Sprintf(`floating = %s`, hyprLuaBoolStr(*mc.IsFloating)))
	}
	if mc.Fullscreen != nil {
		*dst = append(*dst, fmt.Sprintf(`fullscreen = %s`, hyprLuaBoolStr(*mc.Fullscreen)))
	}
	if mc.Pinned != nil {
		*dst = append(*dst, fmt.Sprintf(`pinned = %s`, hyprLuaBoolStr(*mc.Pinned)))
	}
	if mc.Initialised != nil {
		*dst = append(*dst, fmt.Sprintf(`initialised = %s`, hyprLuaBoolStr(*mc.Initialised)))
	}
}

func luaAppendActions(a windowrules.Actions, dst *[]string) {
	if a.OpenFloating != nil && *a.OpenFloating {
		*dst = append(*dst, `float = true`)
	}
	if a.Tile != nil && *a.Tile {
		*dst = append(*dst, `tile = true`)
	}
	if a.OpenFullscreen != nil && *a.OpenFullscreen {
		*dst = append(*dst, `fullscreen = true`)
	}
	if a.OpenMaximized != nil && *a.OpenMaximized {
		*dst = append(*dst, `maximize = true`)
	}
	if a.NoFocus != nil && *a.NoFocus {
		*dst = append(*dst, `no_focus = true`)
	}
	if a.NoBorder != nil && *a.NoBorder {
		*dst = append(*dst, `noborder = true`)
	}
	if a.NoShadow != nil && *a.NoShadow {
		*dst = append(*dst, `no_shadow = true`)
	}
	if a.NoDim != nil && *a.NoDim {
		*dst = append(*dst, `no_dim = true`)
	}
	if a.NoBlur != nil && *a.NoBlur {
		*dst = append(*dst, `no_blur = true`)
	}
	if a.NoAnim != nil && *a.NoAnim {
		*dst = append(*dst, `no_anim = true`)
	}
	if a.NoRounding != nil && *a.NoRounding {
		*dst = append(*dst, `norounding = true`)
	}
	if a.Pin != nil && *a.Pin {
		*dst = append(*dst, `pin = true`)
	}
	if a.Opaque != nil && *a.Opaque {
		*dst = append(*dst, `opaque = true`)
	}
	if a.ForcergbX != nil && *a.ForcergbX {
		*dst = append(*dst, `force_rgbx = true`)
	}
	if a.Opacity != nil {
		*dst = append(*dst, fmt.Sprintf(`opacity = %s`, strconv.FormatFloat(*a.Opacity, 'g', -1, 64)))
	}
	if a.SizeWidth != "" && a.SizeHeight != "" {
		*dst = append(*dst, fmt.Sprintf(`size = { %s, %s }`, hyprLuaExprWrap(a.SizeWidth), hyprLuaExprWrap(a.SizeHeight)))
	}
	if a.MoveX != "" && a.MoveY != "" {
		*dst = append(*dst, fmt.Sprintf(`move = { %s, %s }`, hyprLuaExprWrap(a.MoveX), hyprLuaExprWrap(a.MoveY)))
	}
	if a.Monitor != "" {
		*dst = append(*dst, fmt.Sprintf(`monitor = %s`, strconv.Quote(a.Monitor)))
	}
	if a.Workspace != "" {
		*dst = append(*dst, fmt.Sprintf(`workspace = %s`, strconv.Quote(a.Workspace)))
	}
	if a.CornerRadius != nil {
		*dst = append(*dst, fmt.Sprintf(`rounding = %d`, *a.CornerRadius))
	}
	if a.Idleinhibit != "" {
		*dst = append(*dst, fmt.Sprintf(`idle_inhibit = %s`, strconv.Quote(a.Idleinhibit)))
	}
}

func formatLuaManagedHyprRule(rule windowrules.WindowRule) []string {
	var matchParts []string
	luaAppendMatch(rule.MatchCriteria, &matchParts)
	var body []string
	if len(matchParts) > 0 {
		body = append(body, fmt.Sprintf(`match = { %s }`, strings.Join(matchParts, ", ")))
	}
	luaAppendActions(rule.Actions, &body)

	out := []string{fmt.Sprintf("-- ADVS-RULE: id=%s, name=%s", rule.ID, rule.Name)}
	if len(body) == 0 {
		out = append(out, fmt.Sprintf("-- (no matchers/actions for rule %s)", rule.ID))
	} else {
		out = append(out, fmt.Sprintf("hl.window_rule({ %s })", strings.Join(body, ", ")))
	}
	out = append(out, "")
	return out
}

func (p *HyprlandWritableProvider) LoadADVSRules() ([]windowrules.WindowRule, error) {
	luaPath := p.GetOverridePath()
	expanded, err := utils.ExpandPath(p.configDir)
	if err != nil {
		return nil, err
	}
	confPath := filepath.Join(expanded, "advs", "windowrules.conf")

	var data []byte
	var loadedFrom string

	if data, err = os.ReadFile(luaPath); err == nil {
		loadedFrom = luaPath
	} else if !os.IsNotExist(err) {
		return nil, err
	} else if data, err = os.ReadFile(confPath); err == nil {
		loadedFrom = confPath
	} else if os.IsNotExist(err) {
		return []windowrules.WindowRule{}, nil
	} else {
		return nil, err
	}

	if strings.EqualFold(filepath.Ext(loadedFrom), ".lua") {
		return p.loadADVSRulesFromLua(data, luaPath)
	}
	return p.loadADVSRulesFromConf(data, loadedFrom)
}

func (p *HyprlandWritableProvider) loadADVSRulesFromConf(data []byte, rulesPath string) ([]windowrules.WindowRule, error) {
	var rules []windowrules.WindowRule
	var currentID, currentName string
	lines := strings.SplitSeq(string(data), "\n")

	for line := range lines {
		trimmed := strings.TrimSpace(line)

		if matches := advsRuleCommentRegex.FindStringSubmatch(trimmed); matches != nil {
			currentID = matches[1]
			currentName = matches[2]
			continue
		}

		if strings.HasPrefix(trimmed, "windowrulev2") {
			parser := NewHyprlandRulesParser(p.configDir)
			hrule := parser.parseWindowRuleLine(trimmed)
			if hrule == nil {
				continue
			}

			wr := windowrules.WindowRule{
				ID:      currentID,
				Name:    currentName,
				Enabled: true,
				Source:  rulesPath,
				MatchCriteria: windowrules.MatchCriteria{
					AppID:       hrule.MatchClass,
					Title:       hrule.MatchTitle,
					XWayland:    hrule.MatchXWayland,
					IsFloating:  hrule.MatchFloating,
					Fullscreen:  hrule.MatchFullscreen,
					Pinned:      hrule.MatchPinned,
					Initialised: hrule.MatchInitialised,
				},
			}
			applyHyprlandRuleAction(&wr.Actions, hrule.Rule, hrule.Value)

			if wr.ID == "" {
				wr.ID = hrule.MatchClass
				if wr.ID == "" {
					wr.ID = hrule.MatchTitle
				}
			}

			rules = append(rules, wr)
			currentID = ""
			currentName = ""
		}
	}

	return rules, nil
}

func (p *HyprlandWritableProvider) loadADVSRulesFromLua(data []byte, rulesPath string) ([]windowrules.WindowRule, error) {
	var rules []windowrules.WindowRule
	lines := strings.Split(string(data), "\n")

	var curID, curName string

	for li := 0; li < len(lines); {
		trimmed := strings.TrimSpace(lines[li])
		if strings.HasPrefix(trimmed, "--") {
			if m := advsRuleLuaHDRRegex.FindStringSubmatch(trimmed); m != nil {
				curID, curName = m[1], m[2]
				li++
				continue
			}
		}

		if strings.Contains(strings.ToLower(trimmed), hlWinRuleLower) {
			tail := strings.Join(lines[li:], "\n")
			idx := strings.Index(strings.ToLower(tail), hlWinRuleLower)
			if idx < 0 {
				li++
				continue
			}
			frag := tail[idx:]
			tableArg, consumedFrag, ok := extractHlWindowRuleTableArg(frag)
			if !ok {
				li++
				continue
			}

			idSnap := curID
			nameSnap := curName

			if acts, mf, ok2 := parseHlWindowRuleLuaTable(tableArg); ok2 && acts != nil {
				wr := windowrules.WindowRule{
					ID:            idSnap,
					Name:          nameSnap,
					Enabled:       true,
					Source:        rulesPath,
					MatchCriteria: luaMatchFieldsToCriteria(mf),
					Actions:       *acts,
				}
				if wr.ID == "" {
					wr.ID = fmt.Sprintf("advs_rule_%d", len(rules))
				}
				rules = append(rules, wr)
			}
			curID = ""
			curName = ""

			advance := strings.Count(tail[:idx+consumedFrag], "\n")
			if advance == 0 {
				li++
			} else {
				li += advance
			}
			continue
		}
		if trimmed != "" && !strings.HasPrefix(trimmed, "--") {
			curID = ""
			curName = ""
		}
		li++
	}

	return rules, nil
}

func (p *HyprlandWritableProvider) writeADVSRules(rules []windowrules.WindowRule) error {
	rulesPath := p.GetOverridePath()

	if err := os.MkdirAll(filepath.Dir(rulesPath), 0755); err != nil {
		return err
	}

	var lines []string
	lines = append(lines, "-- ADVS Window Rules — managed by AriadnevShell")
	lines = append(lines, "-- Do not edit manually; changes may be overwritten")
	lines = append(lines, "")

	for _, rule := range rules {
		lines = append(lines, formatLuaManagedHyprRule(rule)...)
	}

	return os.WriteFile(rulesPath, []byte(strings.Join(lines, "\n")), 0644)
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

const hlWinRuleLower = "hl.window_rule"

func hyprlandMainConfigPath(dir string) (string, error) {
	expandedDir, err := utils.ExpandPath(dir)
	if err != nil {
		return "", err
	}
	luaPath := filepath.Join(expandedDir, "hyprland.lua")
	if st, err := os.Stat(luaPath); err == nil && st.Mode().IsRegular() {
		return luaPath, nil
	}
	confPath := filepath.Join(expandedDir, "hyprland.conf")
	if st, err := os.Stat(confPath); err == nil && st.Mode().IsRegular() {
		return confPath, nil
	}
	return "", os.ErrNotExist
}

func isADVSWindowRulesSourcePath(sourcePath string) bool {
	p := filepath.ToSlash(strings.TrimSpace(sourcePath))
	return p == "advs/windowrules.lua" || strings.HasSuffix(p, "/advs/windowrules.lua") ||
		p == "advs/windowrules.conf" || strings.HasSuffix(p, "/advs/windowrules.conf") ||
		p == "./advs/windowrules.lua" || p == "./advs/windowrules.conf"
}

func isADVSWindowRulesRequireModule(mod string) bool {
	return isADVSWindowRulesSourcePath(luaconfig.ModuleToRelPath(mod))
}

func (p *HyprlandRulesParser) probeRequireWindowrulesLine(mainLua string) {
	data, err := os.ReadFile(mainLua)
	if err != nil {
		return
	}
	lines := strings.Split(string(data), "\n")
	for i, line := range lines {
		if mod, ok := luaconfig.Require(line); ok && isADVSWindowRulesRequireModule(mod) {
			p.requireLineInMain = i + 1
			return
		}
	}
}

// luaMatchFields collects fields from Lua match={...} subtrees before copying into HyprlandWindowRule.
type luaMatchFields struct {
	class                                               string
	title                                               string
	xwayland, floating, fullscreen, pinned, initialised *bool
}

func (p *HyprlandRulesParser) parseLuaWindowRules(content, baseDir, absPath string, allowRequires bool) {
	prev := p.currentSource
	p.currentSource = absPath
	defer func() { p.currentSource = prev }()

	lines := strings.Split(content, "\n")
	rootDir := baseDir
	if expanded, err := utils.ExpandPath(p.configDir); err == nil && expanded != "" {
		rootDir = expanded
	}
	curAbs := absPath
	if a, err := filepath.Abs(absPath); err == nil {
		curAbs = a
	}
	mainAbs := ""
	if p.primaryHyprLua != "" {
		if a, err := filepath.Abs(p.primaryHyprLua); err == nil {
			mainAbs = a
		}
	}

	for i := 0; i < len(lines); {
		trimmed := strings.TrimSpace(lines[i])
		if trimmed == "" || strings.HasPrefix(trimmed, "--") {
			i++
			continue
		}

		if modules := luaconfig.Requires(trimmed); len(modules) > 0 && allowRequires {
			for _, mod := range modules {
				rel := luaconfig.ModuleToRelPath(mod)
				if rel == "" {
					continue
				}
				fullPath := luaconfig.ModuleToPath(rootDir, mod)
				expanded, err := utils.ExpandPath(fullPath)
				if err != nil {
					continue
				}
				p.includeCount++
				if isADVSWindowRulesRequireModule(mod) {
					p.advsRulesIncluded = true
					p.advsIncludePos = p.includeCount
					p.advsProcessed = true
				}
				_ = p.parseFile(expanded)
			}
			i++
			continue
		}

		lowTrim := strings.ToLower(trimmed)
		if strings.Contains(lowTrim, hlWinRuleLower) {
			tail := strings.Join(lines[i:], "\n")
			idx := strings.Index(strings.ToLower(tail), hlWinRuleLower)
			if idx < 0 {
				i++
				continue
			}
			frag := tail[idx:]
			tableArg, consumedFrag, ok := extractHlWindowRuleTableArg(frag)
			if !ok {
				i++
				continue
			}

			startLine := i + strings.Count(tail[:idx], "\n") + 1
			if acts, mf, ok2 := parseHlWindowRuleLuaTable(tableArg); ok2 && acts != nil {
				raw := strings.Join(strings.Fields(strings.ReplaceAll(strings.TrimSpace(frag[:consumedFrag]), "\n", " ")), " ")
				if len(raw) > 240 {
					raw = raw[:240] + "…"
				}
				hr := HyprlandWindowRule{
					Source:          curAbs,
					RawLine:         raw,
					CombinedActions: acts,
				}
				fillRuleFromLuaMatch(&hr, mf)

				p.rules = append(p.rules, hr)

				if p.requireLineInMain > 0 && mainAbs != "" && curAbs == mainAbs && startLine > p.requireLineInMain {
					p.rulesAfterADVS++
				}
			}
			advance := strings.Count(tail[:idx+consumedFrag], "\n")
			if advance == 0 {
				i++
			} else {
				i += advance
			}
			continue
		}

		i++
	}
}

func fillRuleFromLuaMatch(hr *HyprlandWindowRule, m luaMatchFields) {
	hr.MatchClass = m.class
	hr.MatchTitle = m.title
	hr.MatchXWayland = m.xwayland
	hr.MatchFloating = m.floating
	hr.MatchFullscreen = m.fullscreen
	hr.MatchPinned = m.pinned
	hr.MatchInitialised = m.initialised
}

func luaMatchFieldsToCriteria(m luaMatchFields) windowrules.MatchCriteria {
	return windowrules.MatchCriteria{
		AppID:       m.class,
		Title:       m.title,
		XWayland:    m.xwayland,
		IsFloating:  m.floating,
		Fullscreen:  m.fullscreen,
		Pinned:      m.pinned,
		Initialised: m.initialised,
	}
}

// extractHlWindowRuleTableArg parses a fragment beginning with (optional prefix then) hl.window_rule( ... ).
// consumed is counted from frag[0] (caller adds idx offset when iterating).
func extractHlWindowRuleTableArg(frag string) (inner string, consumed int, ok bool) {
	tagIdx := strings.Index(strings.ToLower(frag), hlWinRuleLower)
	if tagIdx < 0 {
		return "", 0, false
	}
	afterTag := frag[tagIdx+len(hlWinRuleLower):]
	openIdx := strings.IndexByte(afterTag, '(')
	if openIdx < 0 || (openIdx > 0 && strings.TrimSpace(afterTag[:openIdx]) != "") {
		return "", 0, false
	}
	parenTail := afterTag[openIdx:]
	body, endAfter, ok := extractBalancedParensFromOpen(parenTail, 0)
	if !ok {
		return "", 0, false
	}
	consumedFromFrag := tagIdx + openIdx + endAfter
	return strings.TrimSpace(body), consumedFromFrag, true
}

// extractBalancedParensFromOpen extracts inner string between '(' at openIdx and its matching ')'.
func extractBalancedParensFromOpen(s string, openIdx int) (inner string, endExclusive int, ok bool) {
	if openIdx >= len(s) || s[openIdx] != '(' {
		return "", 0, false
	}
	depth := 0
	inStr := byte(0)
	esc := false
	for i := openIdx; i < len(s); i++ {
		c := s[i]
		if inStr != 0 {
			if esc {
				esc = false
				continue
			}
			if c == '\\' && inStr == '"' {
				esc = true
				continue
			}
			if c == inStr {
				inStr = 0
			}
			continue
		}
		switch c {
		case '"', '\'':
			inStr = c
		case '(':
			depth++
			if depth == 1 {
				continue
			}
		case ')':
			if depth > 0 {
				depth--
				if depth == 0 {
					return strings.TrimSpace(s[openIdx+1 : i]), i + 1, true
				}
			}
		}
	}
	return "", 0, false
}

func trimOuterBraces(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 2 && s[0] == '{' && s[len(s)-1] == '}' {
		return strings.TrimSpace(s[1 : len(s)-1])
	}
	return s
}

func splitTopLevelCommaLua(s string) []string {
	var out []string
	depth := 0
	inStr := byte(0)
	esc := false
	start := 0
	for i := 0; i < len(s); i++ {
		c := s[i]
		if inStr != 0 {
			if esc {
				esc = false
				continue
			}
			if c == '\\' && inStr == '"' {
				esc = true
				continue
			}
			if c == inStr {
				inStr = 0
			}
			continue
		}
		switch c {
		case '"', '\'':
			inStr = c
		case '{', '(':
			depth++
		case '}', ')':
			if depth > 0 {
				depth--
			}
		case ',':
			if depth == 0 {
				out = append(out, strings.TrimSpace(s[start:i]))
				start = i + 1
			}
		}
	}
	out = append(out, strings.TrimSpace(s[start:]))
	return out
}

func splitLuaKeyVal(seg string) (key, val string, ok bool) {
	seg = strings.TrimSpace(seg)
	if seg == "" {
		return "", "", false
	}
	depth := 0
	inStr := byte(0)
	esc := false
	for i := 0; i < len(seg); i++ {
		c := seg[i]
		if inStr != 0 {
			if esc {
				esc = false
				continue
			}
			if c == '\\' && inStr == '"' {
				esc = true
				continue
			}
			if c == inStr {
				inStr = 0
			}
			continue
		}
		switch c {
		case '"', '\'':
			inStr = c
		case '{', '(':
			depth++
		case '}', ')':
			if depth > 0 {
				depth--
			}
		case '=':
			if depth == 0 {
				return strings.TrimSpace(seg[:i]), strings.TrimSpace(seg[i+1:]), true
			}
		}
	}
	return "", "", false
}

func luaStringValue(s string) string {
	s = strings.TrimSpace(s)
	if len(s) >= 2 {
		q0 := s[0]
		q1 := s[len(s)-1]
		if q0 == q1 && (q0 == '"' || q0 == '\'') {
			if q0 == '"' {
				if u, err := strconv.Unquote(s); err == nil {
					return u
				}
			} else if len(s) >= 2 && q0 == '\'' {
				v := strings.TrimSuffix(strings.TrimPrefix(s, "'"), "'")
				v = strings.ReplaceAll(v, `\'`, `'`)
				return v
			}
		}
	}
	v := strings.Trim(strings.TrimSpace(s), `"'`)
	if len(v) >= 2 && v[0] == '(' && v[len(v)-1] == ')' {
		v = strings.TrimSpace(v[1 : len(v)-1])
	}
	return v
}

func luaBoolLike(s string) (val bool, ok bool) {
	s = strings.TrimSpace(strings.ToLower(s))
	switch s {
	case "true", "yes", "1":
		return true, true
	case "false", "no", "0":
		return false, true
	default:
		return false, false
	}
}

func parseMatchLua(val string, m *luaMatchFields) {
	body := trimOuterBraces(val)
	segs := splitTopLevelCommaLua(body)
	for _, seg := range segs {
		k, v, ok := splitLuaKeyVal(seg)
		if !ok {
			continue
		}
		switch strings.TrimSpace(strings.ToLower(k)) {
		case "class":
			m.class = luaStringValue(v)
		case "title":
			m.title = luaStringValue(v)
		case "xwayland":
			if b, okb := luaBoolLike(v); okb {
				m.xwayland = new(b)
			}
		case "floating":
			if b, okb := luaBoolLike(v); okb {
				m.floating = new(b)
			}
		case "fullscreen":
			if b, okb := luaBoolLike(v); okb {
				m.fullscreen = new(b)
			}
		case "pinned":
			if b, okb := luaBoolLike(v); okb {
				m.pinned = new(b)
			}
		case "initialised", "initialized":
			if b, okb := luaBoolLike(v); okb {
				m.initialised = new(b)
			}
		}
	}
}

func applyLuaActionKey(a *windowrules.Actions, key, raw string) bool {
	k := strings.TrimSpace(strings.ToLower(key))
	raw = strings.TrimSpace(raw)
	switch k {
	case "float":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.OpenFloating = &t
			return true
		}
	case "tile":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.Tile = &t
			return true
		}
	case "fullscreen":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.OpenFullscreen = &t
			return true
		}
	case "maximize":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.OpenMaximized = &t
			return true
		}
	case "nofocus", "no_focus", "no_initial_focus":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoFocus = &t
			return true
		}
	case "noborder":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoBorder = &t
			return true
		}
	case "noshadow", "no_shadow":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoShadow = &t
			return true
		}
	case "nodim", "no_dim":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoDim = &t
			return true
		}
	case "noblur", "no_blur":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoBlur = &t
			return true
		}
	case "noanim", "no_anim":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoAnim = &t
			return true
		}
	case "norounding":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.NoRounding = &t
			return true
		}
	case "pin":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.Pin = &t
			return true
		}
	case "opaque":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.Opaque = &t
			return true
		}
	case "forcergbx", "force_rgbx":
		if b, ok := luaBoolLike(raw); ok && b {
			t := true
			a.ForcergbX = &t
			return true
		}
	case "opacity":
		if f, err := strconv.ParseFloat(luaStringValue(raw), 64); err == nil {
			a.Opacity = &f
			return true
		}
	case "rounding":
		if v := luaStringValue(raw); v != "" {
			if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil {
				a.CornerRadius = &n
				return true
			}
		}
	case "size":
		v := strings.TrimSpace(luaStringValue(raw))
		if strings.HasPrefix(v, "{") && strings.HasSuffix(v, "}") {
			inner := trimOuterBraces(v)
			parts := splitTopLevelCommaLua(inner)
			if len(parts) == 2 {
				a.SizeWidth = strings.TrimSpace(luaStringValue(parts[0]))
				a.SizeHeight = strings.TrimSpace(luaStringValue(parts[1]))
				return true
			}
		}
		return false
	case "move":
		v := strings.TrimSpace(luaStringValue(raw))
		if strings.HasPrefix(v, "{") && strings.HasSuffix(v, "}") {
			inner := trimOuterBraces(v)
			parts := splitTopLevelCommaLua(inner)
			if len(parts) == 2 {
				a.MoveX = strings.TrimSpace(luaStringValue(parts[0]))
				a.MoveY = strings.TrimSpace(luaStringValue(parts[1]))
				return true
			}
		}
		return false
	case "monitor":
		a.Monitor = strings.TrimSpace(luaStringValue(raw))
		return true
	case "workspace":
		a.Workspace = strings.TrimSpace(luaStringValue(raw))
		return true
	case "idleinhibit", "idle_inhibit":
		a.Idleinhibit = strings.TrimSpace(luaStringValue(raw))
		return true
	default:
		// Unsupported keys are left to Hyprland; ADVS only round-trips managed fields.
	}
	return false
}

func parseHlWindowRuleLuaTable(inner string) (*windowrules.Actions, luaMatchFields, bool) {
	body := trimOuterBraces(strings.TrimSpace(inner))
	if body == "" {
		return nil, luaMatchFields{}, false
	}
	segs := splitTopLevelCommaLua(body)
	var match luaMatchFields
	var a windowrules.Actions
	matchParsed := false
	haveActions := false

	for _, seg := range segs {
		k, v, ok := splitLuaKeyVal(seg)
		if !ok {
			continue
		}
		switch strings.TrimSpace(strings.ToLower(k)) {
		case "match":
			parseMatchLua(v, &match)
			matchParsed = true
		default:
			if applyLuaActionKey(&a, k, v) {
				haveActions = true
			}
		}
	}
	if !haveActions {
		return nil, luaMatchFields{}, false
	}
	return &a, match, matchParsed || haveActions
}
