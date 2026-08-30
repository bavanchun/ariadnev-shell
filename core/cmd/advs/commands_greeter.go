package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"

	"github.com/bavanchun/ariadnev-shell/core/internal/distros"
	"github.com/spf13/cobra"
)

var greeterCmd = &cobra.Command{
	Use:                "greeter",
	Short:              "Deprecated: moved to the standalone advs-greeter binary",
	Long:               "The greeter has moved to the standalone advs-greeter package.\nThis command forwards to 'advs-greeter' when it is installed.",
	DisableFlagParsing: true,
	SilenceUsage:       true,
	RunE: func(_ *cobra.Command, args []string) error {
		binary, err := exec.LookPath("advs-greeter")
		if err != nil {
			return fmt.Errorf("'advs greeter' has moved to the standalone advs-greeter package.\n  %s", greeterPackageInstallHint())
		}
		if isLegacyWrapperScript(binary) {
			return fmt.Errorf("'advs greeter' has moved to the standalone advs-greeter package; %s is the old wrapper script.\n  %s", binary, greeterPackageInstallHint())
		}
		fmt.Fprintln(os.Stderr, "warning: 'advs greeter' is deprecated; use 'advs-greeter' directly")
		return syscall.Exec(binary, append([]string{"advs-greeter"}, args...), os.Environ())
	},
}

func isLegacyWrapperScript(path string) bool {
	file, err := os.Open(path)
	if err != nil {
		return false
	}
	defer file.Close()
	header := make([]byte, 2)
	if _, err := file.Read(header); err != nil {
		return false
	}
	return string(header) == "#!"
}

func greeterPackageInstallHint() string {
	osInfo, err := distros.GetOSInfo()
	if err != nil {
		return "Install package: advs-greeter"
	}
	config, exists := distros.Registry[osInfo.Distribution.ID]
	if !exists {
		return "Install package: advs-greeter"
	}

	switch config.Family {
	case distros.FamilyArch:
		return "Build and install the package from source: git clone https://github.com/bavanchun/ariadnev-greeter && cd ariadnev-greeter/distro/arch && makepkg -si"
	case distros.FamilyVoid:
		return "No AriadnevShell XBPS repo exists yet; build from https://github.com/bavanchun/ariadnev-greeter (distro/void)"
	default:
		return "No AriadnevShell package repo exists yet for this distribution; build from source: https://github.com/bavanchun/ariadnev-greeter"
	}
}
