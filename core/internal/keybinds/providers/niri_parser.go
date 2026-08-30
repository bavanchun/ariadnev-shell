package providers

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/sblinch/kdl-go"
	"github.com/sblinch/kdl-go/document"
)

type NiriKeyBinding struct {
	Mods            []string
	Key             string
	Action          string
	Args            []string
	Description     string
	HideOnOverlay   bool
	CooldownMs      int
	AllowWhenLocked bool
	AllowInhibiting *bool
	Repeat          *bool
	Source          string
}

type NiriSection struct {
	Name     string
	Keybinds []NiriKeyBinding
	Children []NiriSection
}

type NiriParser struct {
	configDir          string
	modKey             string
	processedFiles     map[string]bool
	bindMap            map[string]*NiriKeyBinding
	bindOrder          []string
	currentSource      string
	advsBindsIncluded   bool
	advsBindsExists     bool
	includeCount       int
	advsIncludePos      int
	bindsBeforeADVS     int
	bindsAfterADVS      int
	advsBindKeys        map[string]bool
	configBindKeys     map[string]bool
	advsProcessed       bool
	advsBindMap         map[string]*NiriKeyBinding
	conflictingConfigs map[string]*NiriKeyBinding
}

func parseKDL(data []byte) (*document.Document, error) {
	return kdl.Parse(strings.NewReader(normalizeKDLBraces(quoteLeadingUnderscoreIdents(string(data)))))
}

func normalizeKDLBraces(input string) string {
	var sb strings.Builder
	sb.Grow(len(input))

	var prev byte
	n := len(input)
	for i := 0; i < n; {
		c := input[i]

		switch {
		case c == '"':
			end := findStringEnd(input, i)
			sb.WriteString(input[i:end])
			prev = '"'
			i = end
		case c == '/' && i+1 < n && input[i+1] == '/':
			end := findLineCommentEnd(input, i)
			sb.WriteString(input[i:end])
			prev = '\n'
			i = end
		case c == '/' && i+1 < n && input[i+1] == '*':
			end := findBlockCommentEnd(input, i)
			sb.WriteString(input[i:end])
			prev = '/'
			i = end
		case c == '{' && prev != 0 && !isBraceAdjacentSpace(prev):
			sb.WriteByte(' ')
			sb.WriteByte(c)
			prev = c
			i++
		default:
			sb.WriteByte(c)
			prev = c
			i++
		}
	}

	return sb.String()
}

// quoteLeadingUnderscoreIdents wraps bare KDL identifiers that begin with '_'
// in double quotes. kdl-go rejects '_' as the first character of a bare
// identifier (e.g. the common `_JAVA_AWT_WM_NONREPARENTING "1"` environment
// node), even though niri's own parser and the KDL spec accept it — so without
// this the whole config fails to parse and no keybinds load. Quoting lets
// kdl-go parse it; this is safe because the niri parser only dispatches on
// fixed node/section names (binds, recent-windows, include, ...) that never
// start with '_', so re-quoting such a name cannot change what ADVS reads.
// Underscores elsewhere in an identifier (XDG_CURRENT_DESKTOP) are left
// untouched, and underscores inside strings or comments are skipped. Only a
// leading '_' is handled; other start characters kdl-go over-rejects (e.g. '.'
// or '?') do not occur in niri configs.
func quoteLeadingUnderscoreIdents(input string) string {
	var sb strings.Builder
	sb.Grow(len(input))

	var prev byte
	n := len(input)
	for i := 0; i < n; {
		c := input[i]

		switch {
		case c == '"':
			end := findStringEnd(input, i)
			sb.WriteString(input[i:end])
			prev = '"'
			i = end
		case c == '/' && i+1 < n && input[i+1] == '/':
			end := findLineCommentEnd(input, i)
			sb.WriteString(input[i:end])
			prev = '\n'
			i = end
		case c == '/' && i+1 < n && input[i+1] == '*':
			end := findBlockCommentEnd(input, i)
			sb.WriteString(input[i:end])
			prev = ' '
			i = end
		case c == '/' && i+1 < n && input[i+1] == '-':
			// KDL slashdash: /- comments out the next node/value. Keep the
			// marker but treat what follows as a fresh token start, so a
			// slashdashed leading-underscore node (e.g. `/-_FOO "1"`) still
			// gets quoted instead of crashing kdl-go.
			sb.WriteByte('/')
			sb.WriteByte('-')
			prev = ' '
			i += 2
		case c == '_' && isIdentBoundary(prev):
			end := scanBareIdent(input, i)
			sb.WriteByte('"')
			sb.WriteString(input[i:end])
			sb.WriteByte('"')
			prev = '"'
			i = end
		default:
			sb.WriteByte(c)
			prev = c
			i++
		}
	}

	return sb.String()
}

// isIdentBoundary reports whether the previously emitted byte ends a token, so
// that a following '_' starts a fresh bare identifier rather than sitting in
// the middle of one.
func isIdentBoundary(prev byte) bool {
	switch prev {
	case 0, ' ', '\t', '\n', '\r', '{', '}', ';', '=', '(', ')', ',':
		return true
	}
	return false
}

// scanBareIdent returns the index just past the bare identifier starting at
// start, stopping at whitespace or any KDL delimiter.
func scanBareIdent(s string, start int) int {
	n := len(s)
	for i := start; i < n; i++ {
		switch s[i] {
		case ' ', '\t', '\n', '\r', '"', '{', '}', '(', ')', ';', '=', ',', '/', '\\', '<', '>', '[', ']':
			return i
		}
	}
	return n
}

func findStringEnd(s string, start int) int {
	n := len(s)
	for i := start + 1; i < n; {
		switch s[i] {
		case '\\':
			i += 2
		case '"':
			return i + 1
		default:
			i++
		}
	}
	return n
}

func findLineCommentEnd(s string, start int) int {
	for i := start + 2; i < len(s); i++ {
		if s[i] == '\n' {
			return i
		}
	}
	return len(s)
}

func findBlockCommentEnd(s string, start int) int {
	n := len(s)
	depth := 1
	for i := start + 2; i < n && depth > 0; {
		switch {
		case i+1 < n && s[i] == '/' && s[i+1] == '*':
			depth++
			i += 2
		case i+1 < n && s[i] == '*' && s[i+1] == '/':
			depth--
			i += 2
			if depth == 0 {
				return i
			}
		default:
			i++
		}
	}
	return n
}

func isBraceAdjacentSpace(b byte) bool {
	switch b {
	case ' ', '\t', '\n', '\r', '{':
		return true
	}
	return false
}

func NewNiriParser(configDir string) *NiriParser {
	return &NiriParser{
		configDir:          configDir,
		modKey:             "Super",
		processedFiles:     make(map[string]bool),
		bindMap:            make(map[string]*NiriKeyBinding),
		bindOrder:          []string{},
		currentSource:      "",
		advsIncludePos:      -1,
		advsBindKeys:        make(map[string]bool),
		configBindKeys:     make(map[string]bool),
		advsBindMap:         make(map[string]*NiriKeyBinding),
		conflictingConfigs: make(map[string]*NiriKeyBinding),
	}
}

func normalizeNiriBindKey(key string) string {
	parts := strings.Split(key, "+")
	for i := range parts {
		parts[i] = strings.ToLower(strings.TrimSpace(parts[i]))
	}
	return strings.Join(parts, "+")
}

func (p *NiriParser) Parse() (*NiriSection, error) {
	advsBindsPath := filepath.Join(p.configDir, "advs", "binds.kdl")
	if _, err := os.Stat(advsBindsPath); err == nil {
		p.advsBindsExists = true
	}

	configPath := filepath.Join(p.configDir, "config.kdl")
	section, err := p.parseFile(configPath, "")
	if err != nil {
		return nil, err
	}

	if p.advsBindsExists && !p.advsProcessed {
		p.parseADVSBindsDirectly(advsBindsPath, section)
	}

	section.Keybinds = p.finalizeBinds()
	return section, nil
}

func (p *NiriParser) parseADVSBindsDirectly(advsBindsPath string, section *NiriSection) {
	data, err := os.ReadFile(advsBindsPath)
	if err != nil {
		return
	}

	doc, err := parseKDL(data)
	if err != nil {
		return
	}

	prevSource := p.currentSource
	p.currentSource = advsBindsPath
	baseDir := filepath.Dir(advsBindsPath)
	p.processNodes(doc.Nodes, section, baseDir)
	p.currentSource = prevSource
	p.advsProcessed = true
}

func (p *NiriParser) finalizeBinds() []NiriKeyBinding {
	binds := make([]NiriKeyBinding, 0, len(p.bindOrder))
	for _, key := range p.bindOrder {
		if kb, ok := p.bindMap[key]; ok {
			binds = append(binds, *kb)
		}
	}
	return binds
}

func (p *NiriParser) addBind(kb *NiriKeyBinding) {
	key := p.formatBindKey(kb)
	normalizedKey := normalizeNiriBindKey(key)
	isADVSBind := strings.Contains(kb.Source, "advs/binds.kdl")

	if isADVSBind {
		p.advsBindKeys[normalizedKey] = true
		p.advsBindMap[normalizedKey] = kb
	} else if p.advsBindKeys[normalizedKey] {
		p.bindsAfterADVS++
		p.conflictingConfigs[normalizedKey] = kb
		p.configBindKeys[normalizedKey] = true
		return
	} else {
		p.configBindKeys[normalizedKey] = true
	}

	if _, exists := p.bindMap[normalizedKey]; !exists {
		p.bindOrder = append(p.bindOrder, normalizedKey)
	}
	p.bindMap[normalizedKey] = kb
}

func (p *NiriParser) formatBindKey(kb *NiriKeyBinding) string {
	parts := make([]string, 0, len(kb.Mods)+1)
	parts = append(parts, kb.Mods...)
	parts = append(parts, kb.Key)
	return strings.Join(parts, "+")
}

func (p *NiriParser) parseFile(filePath, sectionName string) (*NiriSection, error) {
	absPath, err := filepath.Abs(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to resolve path %s: %w", filePath, err)
	}

	if p.processedFiles[absPath] {
		return &NiriSection{Name: sectionName}, nil
	}
	p.processedFiles[absPath] = true

	data, err := os.ReadFile(absPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read %s: %w", absPath, err)
	}

	doc, err := parseKDL(data)
	if err != nil {
		return nil, fmt.Errorf("failed to parse KDL in %s: %w", absPath, err)
	}

	section := &NiriSection{
		Name: sectionName,
	}

	prevSource := p.currentSource
	p.currentSource = absPath
	baseDir := filepath.Dir(absPath)
	p.processNodes(doc.Nodes, section, baseDir)
	p.currentSource = prevSource

	return section, nil
}

func (p *NiriParser) processNodes(nodes []*document.Node, section *NiriSection, baseDir string) {
	for _, node := range nodes {
		name := node.Name.String()

		switch name {
		case "include":
			p.handleInclude(node, section, baseDir)
		case "input":
			p.handleInput(node)
		case "binds":
			p.extractBinds(node, "")
		case "recent-windows":
			p.handleRecentWindows(node)
		}
	}
}

func (p *NiriParser) handleInput(node *document.Node) {
	for _, child := range node.Children {
		if child.Name.String() != "mod-key" || len(child.Arguments) == 0 {
			continue
		}

		modKey := strings.Trim(strings.TrimSpace(child.Arguments[0].String()), "\"")
		if modKey != "" {
			p.modKey = modKey
		}
	}
}

func (p *NiriParser) handleInclude(node *document.Node, section *NiriSection, baseDir string) {
	if len(node.Arguments) == 0 {
		return
	}

	includePath := strings.Trim(node.Arguments[0].String(), "\"")
	isADVSInclude := includePath == "advs/binds.kdl" || strings.HasSuffix(includePath, "/advs/binds.kdl")

	p.includeCount++
	if isADVSInclude {
		p.advsBindsIncluded = true
		p.advsIncludePos = p.includeCount
		p.bindsBeforeADVS = len(p.bindMap)
	}

	fullPath := filepath.Join(baseDir, includePath)
	if filepath.IsAbs(includePath) {
		fullPath = includePath
	}

	if isADVSInclude {
		p.advsProcessed = true
	}

	includedSection, err := p.parseFile(fullPath, "")
	if err != nil {
		return
	}

	section.Children = append(section.Children, includedSection.Children...)
}

func (p *NiriParser) HasADVSBindsIncluded() bool {
	return p.advsBindsIncluded
}

func (p *NiriParser) handleRecentWindows(node *document.Node) {
	if node.Children == nil {
		return
	}

	for _, child := range node.Children {
		if child.Name.String() != "binds" {
			continue
		}
		p.extractBinds(child, "Alt-Tab")
	}
}

func (p *NiriParser) extractBinds(node *document.Node, subcategory string) {
	if node.Children == nil {
		return
	}

	for _, child := range node.Children {
		kb := p.parseKeybindNode(child, subcategory)
		if kb == nil {
			continue
		}
		p.addBind(kb)
	}
}

func (p *NiriParser) parseKeybindNode(node *document.Node, _ string) *NiriKeyBinding {
	keyCombo := node.Name.String()
	if keyCombo == "" {
		return nil
	}

	mods, key := p.parseKeyCombo(keyCombo)

	var action string
	var args []string
	if len(node.Children) > 0 {
		actionNode := node.Children[0]
		action = actionNode.Name.String()
		for _, arg := range actionNode.Arguments {
			args = append(args, arg.ValueString())
		}
		if actionNode.Properties != nil {
			for _, propName := range []string{"focus", "show-pointer", "write-to-disk", "skip-confirmation", "delay-ms"} {
				if val, ok := actionNode.Properties.Get(propName); ok {
					args = append(args, propName+"="+val.String())
				}
			}
		}
	}

	var description string
	var hideOnOverlay bool
	var cooldownMs int
	var allowWhenLocked bool
	var allowInhibiting *bool
	var repeat *bool
	if node.Properties != nil {
		if val, ok := node.Properties.Get("hotkey-overlay-title"); ok {
			switch val.ValueString() {
			case "null", "":
				hideOnOverlay = true
			default:
				description = val.ValueString()
			}
		}
		if val, ok := node.Properties.Get("cooldown-ms"); ok {
			cooldownMs, _ = strconv.Atoi(val.String())
		}
		if val, ok := node.Properties.Get("allow-when-locked"); ok {
			allowWhenLocked = val.String() == "true"
		}
		if val, ok := node.Properties.Get("allow-inhibiting"); ok {
			v := val.String() == "true"
			allowInhibiting = &v
		}
		if val, ok := node.Properties.Get("repeat"); ok {
			v := val.String() == "true"
			repeat = &v
		}
	}

	return &NiriKeyBinding{
		Mods:            mods,
		Key:             key,
		Action:          action,
		Args:            args,
		Description:     description,
		HideOnOverlay:   hideOnOverlay,
		CooldownMs:      cooldownMs,
		AllowWhenLocked: allowWhenLocked,
		AllowInhibiting: allowInhibiting,
		Repeat:          repeat,
		Source:          p.currentSource,
	}
}

func (p *NiriParser) parseKeyCombo(combo string) ([]string, string) {
	parts := strings.Split(combo, "+")

	switch len(parts) {
	case 0:
		return nil, combo
	case 1:
		return nil, parts[0]
	default:
		return parts[:len(parts)-1], parts[len(parts)-1]
	}
}

type NiriParseResult struct {
	Section            *NiriSection
	ModKey             string
	ADVSBindsIncluded   bool
	ADVSStatus          *ADVSBindsStatusInfo
	ConflictingConfigs map[string]*NiriKeyBinding
}

type ADVSBindsStatusInfo struct {
	Exists          bool
	Included        bool
	IncludePosition int
	TotalIncludes   int
	BindsAfterADVS   int
	Effective       bool
	OverriddenBy    int
	StatusMessage   string
}

func (p *NiriParser) buildADVSStatus() *ADVSBindsStatusInfo {
	status := &ADVSBindsStatusInfo{
		Exists:          p.advsBindsExists,
		Included:        p.advsBindsIncluded,
		IncludePosition: p.advsIncludePos,
		TotalIncludes:   p.includeCount,
		BindsAfterADVS:   p.bindsAfterADVS,
	}

	switch {
	case !p.advsBindsExists:
		status.Effective = false
		status.StatusMessage = "advs/binds.kdl does not exist"
	case !p.advsBindsIncluded:
		status.Effective = false
		status.StatusMessage = "advs/binds.kdl is not included in config.kdl"
	case p.bindsAfterADVS > 0:
		status.Effective = true
		status.OverriddenBy = p.bindsAfterADVS
		status.StatusMessage = "Some ADVS binds may be overridden by config binds"
	default:
		status.Effective = true
		status.StatusMessage = "ADVS binds are active"
	}

	return status
}

func ParseNiriKeys(configDir string) (*NiriParseResult, error) {
	parser := NewNiriParser(configDir)
	section, err := parser.Parse()
	if err != nil {
		return nil, err
	}
	return &NiriParseResult{
		Section:            section,
		ModKey:             parser.modKey,
		ADVSBindsIncluded:   parser.HasADVSBindsIncluded(),
		ADVSStatus:          parser.buildADVSStatus(),
		ConflictingConfigs: parser.conflictingConfigs,
	}, nil
}
