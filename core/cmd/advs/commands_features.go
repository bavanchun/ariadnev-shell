//go:build !distro_binary

package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/bavanchun/ariadnev-shell/core/internal/distros"
	"github.com/bavanchun/ariadnev-shell/core/internal/errdefs"
	"github.com/bavanchun/ariadnev-shell/core/internal/log"
	"github.com/bavanchun/ariadnev-shell/core/internal/netfetch"
	"github.com/bavanchun/ariadnev-shell/core/internal/privesc"
	"github.com/bavanchun/ariadnev-shell/core/internal/utils"
	"github.com/bavanchun/ariadnev-shell/core/internal/version"
	"github.com/spf13/cobra"
)

var updateCmd = &cobra.Command{
	Use:     "update",
	Short:   "Update AriadnevShell to the latest version",
	Long:    "Update AriadnevShell to the latest version using the appropriate package manager for your distribution",
	PreRunE: shellApp.ResolveConfig,
	Run: func(cmd *cobra.Command, args []string) {
		runUpdate()
	},
}

var updateCheckCmd = &cobra.Command{
	Use:   "check",
	Short: "Check if updates are available for AriadnevShell",
	Long:  "Check for available updates without performing the actual update",
	Run: func(cmd *cobra.Command, args []string) {
		runUpdateCheck()
	},
}

func runUpdateCheck() {
	fmt.Println("Checking for AriadnevShell updates...")
	fmt.Println()

	versionInfo, err := version.GetADVSVersionInfo()
	if err != nil {
		log.Fatalf("Error checking for updates: %v", err)
	}

	fmt.Printf("Current version: %s\n", versionInfo.Current)
	fmt.Printf("Latest version:  %s\n", versionInfo.Latest)
	fmt.Println()

	if versionInfo.HasUpdate {
		fmt.Println("✓ Update available!")
		fmt.Println()
		fmt.Println("Run 'advs update' to install the latest version.")
		os.Exit(0)
	} else {
		fmt.Println("✓ You are running the latest version.")
		os.Exit(0)
	}
}

func runUpdate() {
	osInfo, err := distros.GetOSInfo()
	if err != nil {
		log.Fatalf("Error detecting OS: %v", err)
	}

	config, exists := distros.Registry[osInfo.Distribution.ID]
	if !exists {
		log.Fatalf("Unsupported distribution: %s", osInfo.Distribution.ID)
	}

	var updateErr error
	switch config.Family {
	case distros.FamilyArch:
		updateErr = updateArchLinux()
	case distros.FamilySUSE:
		updateErr = updateOtherDistros()
	default:
		updateErr = updateOtherDistros()
	}

	if updateErr != nil {
		if errors.Is(updateErr, errdefs.ErrUpdateCancelled) {
			log.Info("Update cancelled.")
			return
		}
		if errors.Is(updateErr, errdefs.ErrNoUpdateNeeded) {
			return
		}
		log.Fatalf("Error updating ADVS: %v", updateErr)
	}

	log.Info("Update complete! Restarting ADVS...")
	shellApp.Restart()
}

func updateArchLinux() error {
	homeDir, err := os.UserHomeDir()
	if err == nil {
		advsPath := filepath.Join(homeDir, ".config", "quickshell", "advs")
		if _, err := os.Stat(advsPath); err == nil {
			return updateOtherDistros()
		}
	}

	var packageName string
	var isAUR bool
	if isArchPackageInstalled("ariadnev-shell") {
		packageName = "ariadnev-shell"
	} else if isArchPackageInstalled("ariadnev-shell-git") {
		packageName = "ariadnev-shell-git"
		isAUR = true
	} else if isArchPackageInstalled("ariadnev-shell-bin") {
		packageName = "ariadnev-shell-bin"
		isAUR = true
	} else {
		fmt.Println("Info: No ariadnev-shell package found.")
		fmt.Println("Info: Falling back to git-based update method...")
		return updateOtherDistros()
	}

	if !isAUR {
		fmt.Printf("This will update %s using pacman.\n", packageName)
		if !confirmUpdate() {
			return errdefs.ErrUpdateCancelled
		}

		fmt.Printf("\nRunning: pacman -S %s\n", packageName)
		if err := privesc.Run(context.Background(), "", "pacman", "-S", "--noconfirm", packageName); err != nil {
			fmt.Printf("Error: Failed to update using pacman: %v\n", err)
			return err
		}

		fmt.Println("advs successfully updated")
		return nil
	}

	var helper string
	var updateCmd *exec.Cmd

	if utils.CommandExists("yay") {
		helper = "yay"
		updateCmd = exec.Command("yay", "-S", packageName)
	} else if utils.CommandExists("paru") {
		helper = "paru"
		updateCmd = exec.Command("paru", "-S", packageName)
	} else {
		fmt.Println("Error: Neither yay nor paru found - please install an AUR helper")
		fmt.Println("Info: Falling back to git-based update method...")
		return updateOtherDistros()
	}

	fmt.Printf("This will update AriadnevShell using %s.\n", helper)
	if !confirmUpdate() {
		return errdefs.ErrUpdateCancelled
	}

	fmt.Printf("\nRunning: %s -S %s\n", helper, packageName)
	updateCmd.Stdout = os.Stdout
	updateCmd.Stderr = os.Stderr
	err = updateCmd.Run()
	if err != nil {
		fmt.Printf("Error: Failed to update using %s: %v\n", helper, err)
	}

	fmt.Println("advs successfully updated")
	return nil
}

func updateOtherDistros() error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %w", err)
	}

	advsPath := filepath.Join(homeDir, ".config", "quickshell", "advs")

	if _, err := os.Stat(advsPath); os.IsNotExist(err) {
		return fmt.Errorf("ADVS configuration directory not found at %s", advsPath)
	}

	fmt.Printf("Found ADVS configuration at %s\n", advsPath)

	versionInfo, err := version.GetADVSVersionInfo()
	if err == nil && !versionInfo.HasUpdate {
		fmt.Println()
		fmt.Printf("Current version: %s\n", versionInfo.Current)
		fmt.Printf("Latest version:  %s\n", versionInfo.Latest)
		fmt.Println()
		fmt.Println("✓ You are already running the latest version.")
		return errdefs.ErrNoUpdateNeeded
	}

	fmt.Println("\nThis will update:")
	fmt.Println("  1. The advs binary from GitHub releases")
	fmt.Println("  2. AriadnevShell configuration using git")
	if !confirmUpdate() {
		return errdefs.ErrUpdateCancelled
	}

	fmt.Println("\n=== Updating advs binary ===")
	if err := updateADVSBinary(); err != nil {
		fmt.Printf("Warning: Failed to update advs binary: %v\n", err)
		fmt.Println("Continuing with shell configuration update...")
	} else {
		fmt.Println("advs binary successfully updated")
	}

	fmt.Println("\n=== Updating ADVS shell configuration ===")

	if err := os.Chdir(advsPath); err != nil {
		return fmt.Errorf("failed to change to ADVS directory: %w", err)
	}

	statusCmd := exec.Command("git", "status", "--porcelain")
	statusOutput, _ := statusCmd.Output()
	hasLocalChanges := len(strings.TrimSpace(string(statusOutput))) > 0

	currentRefCmd := exec.Command("git", "symbolic-ref", "-q", "HEAD")
	currentRefOutput, _ := currentRefCmd.Output()
	onBranch := len(currentRefOutput) > 0

	var currentTag string
	var currentBranch string

	if !onBranch {
		tagCmd := exec.Command("git", "describe", "--exact-match", "--tags", "HEAD")
		if tagOutput, err := tagCmd.Output(); err == nil {
			currentTag = strings.TrimSpace(string(tagOutput))
		}
	} else {
		branchCmd := exec.Command("git", "rev-parse", "--abbrev-ref", "HEAD")
		if branchOutput, err := branchCmd.Output(); err == nil {
			currentBranch = strings.TrimSpace(string(branchOutput))
		}
	}

	fmt.Println("Fetching latest changes...")
	fetchCmd := exec.Command("git", "fetch", "origin", "--tags", "--force")
	fetchCmd.Stdout = os.Stdout
	fetchCmd.Stderr = os.Stderr
	if err := fetchCmd.Run(); err != nil {
		return fmt.Errorf("failed to fetch changes: %w", err)
	}

	if err := updateSubmodules(); err != nil {
		return fmt.Errorf("failed to update submodules: %w", err)
	}

	if currentTag != "" {
		latestTagCmd := exec.Command("git", "tag", "-l", "v*", "--sort=-version:refname")
		latestTagOutput, err := latestTagCmd.Output()
		if err != nil {
			return fmt.Errorf("failed to get latest tag: %w", err)
		}

		tags := strings.Split(strings.TrimSpace(string(latestTagOutput)), "\n")
		if len(tags) == 0 || tags[0] == "" {
			return fmt.Errorf("no version tags found")
		}
		latestTag := tags[0]

		if latestTag == currentTag {
			fmt.Printf("Already on latest tag: %s\n", currentTag)
			return nil
		}

		fmt.Printf("Current tag: %s\n", currentTag)
		fmt.Printf("Latest tag: %s\n", latestTag)

		if hasLocalChanges {
			fmt.Println("\nWarning: You have local changes in your ADVS configuration.")
			if offerReclone(advsPath) {
				return nil
			}
			return errdefs.ErrUpdateCancelled
		}

		fmt.Printf("Updating to %s...\n", latestTag)
		checkoutCmd := exec.Command("git", "checkout", latestTag)
		checkoutCmd.Stdout = os.Stdout
		checkoutCmd.Stderr = os.Stderr
		if err := checkoutCmd.Run(); err != nil {
			fmt.Printf("Error: Failed to checkout %s: %v\n", latestTag, err)
			if offerReclone(advsPath) {
				return nil
			}
			return fmt.Errorf("update cancelled")
		}

		if err := updateSubmodules(); err != nil {
			return fmt.Errorf("failed to update submodules: %w", err)
		}

		fmt.Printf("\nUpdate complete! Updated from %s to %s\n", currentTag, latestTag)
		return nil
	}

	if currentBranch == "" {
		currentBranch = "master"
	}

	fmt.Printf("Current branch: %s\n", currentBranch)

	if hasLocalChanges {
		fmt.Println("\nWarning: You have local changes in your ADVS configuration.")
		if offerReclone(advsPath) {
			return nil
		}
		return errdefs.ErrUpdateCancelled
	}

	pullCmd := exec.Command("git", "pull", "origin", currentBranch)
	pullCmd.Stdout = os.Stdout
	pullCmd.Stderr = os.Stderr
	if err := pullCmd.Run(); err != nil {
		fmt.Printf("Error: Failed to pull latest changes: %v\n", err)
		if offerReclone(advsPath) {
			return nil
		}
		return fmt.Errorf("update cancelled")
	}

	if err := updateSubmodules(); err != nil {
		return fmt.Errorf("failed to update submodules: %w", err)
	}

	fmt.Println("\nUpdate complete!")
	return nil
}

func updateSubmodules() error {
	submoduleCmd := exec.Command("git", "submodule", "update", "--init", "--recursive")
	submoduleCmd.Stdout = os.Stdout
	submoduleCmd.Stderr = os.Stderr
	return submoduleCmd.Run()
}

func offerReclone(advsPath string) bool {
	fmt.Println("\nWould you like to backup and re-clone the repository? (y/N): ")
	reader := bufio.NewReader(os.Stdin)
	response, err := reader.ReadString('\n')
	if err != nil || !strings.HasPrefix(strings.ToLower(strings.TrimSpace(response)), "y") {
		return false
	}

	timestamp := time.Now().Unix()
	backupPath := fmt.Sprintf("%s.backup-%d", advsPath, timestamp)

	fmt.Printf("Backing up current directory to %s...\n", backupPath)
	if err := os.Rename(advsPath, backupPath); err != nil {
		fmt.Printf("Error: Failed to backup directory: %v\n", err)
		return false
	}

	fmt.Println("Cloning fresh copy...")
	cloneCmd := exec.Command("git", "clone", "--recurse-submodules", "https://github.com/bavanchun/ariadnev-shell.git", advsPath)
	cloneCmd.Stdout = os.Stdout
	cloneCmd.Stderr = os.Stderr
	if err := cloneCmd.Run(); err != nil {
		fmt.Printf("Error: Failed to clone repository: %v\n", err)
		fmt.Printf("Restoring backup...\n")
		os.Rename(backupPath, advsPath)
		return false
	}

	fmt.Printf("Successfully re-cloned repository (backup at %s)\n", backupPath)
	return true
}

func confirmUpdate() bool {
	fmt.Print("Do you want to proceed with the update? (y/N): ")
	reader := bufio.NewReader(os.Stdin)
	response, err := reader.ReadString('\n')
	if err != nil {
		fmt.Printf("Error reading input: %v\n", err)
		return false
	}
	response = strings.TrimSpace(strings.ToLower(response))
	return response == "y" || response == "yes"
}

func updateADVSBinary() error {
	arch := ""
	switch strings.ToLower(os.Getenv("HOSTTYPE")) {
	case "x86_64", "amd64":
		arch = "amd64"
	case "aarch64", "arm64":
		arch = "arm64"
	default:
		cmd := exec.Command("uname", "-m")
		output, err := cmd.Output()
		if err != nil {
			return fmt.Errorf("failed to detect architecture: %w", err)
		}
		archStr := strings.TrimSpace(string(output))
		switch archStr {
		case "x86_64":
			arch = "amd64"
		case "aarch64":
			arch = "arm64"
		default:
			return fmt.Errorf("unsupported architecture: %s", archStr)
		}
	}

	fmt.Println("Fetching latest release version...")
	version, err := netfetch.LatestReleaseTag(context.Background())
	if err != nil {
		return fmt.Errorf("failed to fetch latest release: %w", err)
	}

	fmt.Printf("Latest version: %s\n", version)

	tempDir, err := os.MkdirTemp("", "advs-update-*")
	if err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}
	defer os.RemoveAll(tempDir)

	binaryURL := fmt.Sprintf("https://github.com/bavanchun/ariadnev-shell/releases/download/%s/advs-cli-%s.gz", version, arch)
	checksumURL := fmt.Sprintf("https://github.com/bavanchun/ariadnev-shell/releases/download/%s/advs-cli-%s.gz.sha256", version, arch)

	binaryPath := filepath.Join(tempDir, "advs.gz")
	checksumPath := filepath.Join(tempDir, "advs.gz.sha256")

	fmt.Println("Downloading advs binary...")
	if err := netfetch.ToFile(context.Background(), binaryURL, netfetch.Options{Timeout: 5 * time.Minute}, binaryPath); err != nil {
		return fmt.Errorf("failed to download binary: %w", err)
	}

	fmt.Println("Downloading checksum...")
	if err := netfetch.ToFile(context.Background(), checksumURL, netfetch.Options{Timeout: 30 * time.Second}, checksumPath); err != nil {
		return fmt.Errorf("failed to download checksum: %w", err)
	}

	fmt.Println("Verifying checksum...")
	checksumData, err := os.ReadFile(checksumPath)
	if err != nil {
		return fmt.Errorf("failed to read checksum file: %w", err)
	}
	expectedChecksum := strings.Fields(string(checksumData))[0]

	actualCmd := exec.Command("sha256sum", binaryPath)
	actualOutput, err := actualCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to calculate checksum: %w", err)
	}
	actualChecksum := strings.Fields(string(actualOutput))[0]

	if expectedChecksum != actualChecksum {
		return fmt.Errorf("checksum verification failed\nExpected: %s\nGot: %s", expectedChecksum, actualChecksum)
	}

	fmt.Println("Decompressing binary...")
	decompressCmd := exec.Command("gunzip", binaryPath)
	if err := decompressCmd.Run(); err != nil {
		return fmt.Errorf("failed to decompress binary: %w", err)
	}

	decompressedPath := filepath.Join(tempDir, "advs")

	if err := os.Chmod(decompressedPath, 0o755); err != nil {
		return fmt.Errorf("failed to make binary executable: %w", err)
	}

	currentPath, err := exec.LookPath("advs")
	if err != nil {
		return fmt.Errorf("could not find current advs binary: %w", err)
	}

	fmt.Printf("Installing to %s...\n", currentPath)

	if err := privesc.Run(context.Background(), "", "install", "-m", "0755", decompressedPath, currentPath); err != nil {
		return fmt.Errorf("failed to replace binary: %w", err)
	}

	return nil
}
