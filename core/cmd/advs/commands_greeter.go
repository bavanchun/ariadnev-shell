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
	case distros.FamilyDebian:
		return "Install with 'sudo apt install advs-greeter' (requires AdvLinux OBS repo — see https://ariadnev.vchun.dev/docs/advgreeter/installation#debian)"
	case distros.FamilySUSE:
		return "Install with 'sudo zypper install advs-greeter' (requires AdvLinux OBS repo — see https://ariadnev.vchun.dev/docs/advgreeter/installation#opensuse)"
	case distros.FamilyUbuntu:
		return "Install with 'sudo apt install advs-greeter' (requires ppa:bavanchun/ariadnev: sudo add-apt-repository ppa:bavanchun/ariadnev)"
	case distros.FamilyFedora:
		return "Install with 'sudo dnf install advs-greeter' (requires COPR: sudo dnf copr enable bavanchun/ariadnev)"
	case distros.FamilyArch:
		return "Install from AUR with 'paru -S greetd-advs-greeter-bin' or 'yay -S greetd-advs-greeter-bin'"
	case distros.FamilyVoid:
		return "Install with 'sudo xbps-install -S advs-greeter' (requires ADVS XBPS repo: echo 'repository=https://void.ariadnev.vchun.dev/advs/current' | sudo tee /etc/xbps.d/advs.conf)"
	default:
		return "Install the advs-greeter package for your distribution"
	}
}
