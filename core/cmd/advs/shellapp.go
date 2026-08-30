package main

import (
	"context"
	"fmt"
	"os"

	"github.com/bavanchun/ariadnev-shell/core/internal/config"
	"github.com/bavanchun/ariadnev-shell/core/internal/log"
	"github.com/bavanchun/ariadnev-shell/core/internal/server"
	"github.com/bavanchun/ariadnev-shell/core/internal/shellembed"
	"github.com/AvengeMedia/dankgo/shellapp"
)

var shellApp = shellapp.New(shellapp.Config{
	ID:                     "ariadnev",
	EnvPrefix:              "ADVS",
	QSAppID:                "dev.vchun.ariadnev",
	Version:                Version,
	Embedded:               embeddedShell{},
	Boot:                   bootBackend,
	PreLaunch:              preLaunch,
	ExtraEnv:               advsExtraEnv,
	OnUIExit:               logStartupFailure,
	SessionRestartExitCode: advsSessionRestartExitCode,
	TryManagedRestart:      trySystemdRestart,
})

type embeddedShell struct{}

func (embeddedShell) Available() bool { return shellembed.Available() }

func (embeddedShell) Extract(baseDir string) (string, error) { return shellembed.Extract(baseDir) }

func (embeddedShell) Prune(baseDir, keep string) { shellembed.Prune(baseDir, keep) }

type advsBackend struct {
	srv  *server.Server
	done chan error
}

func (b *advsBackend) SocketPath() string { return b.srv.SocketPath() }

func (b *advsBackend) Close() { b.srv.Close() }

func (b *advsBackend) Done() <-chan error { return b.done }

func bootBackend(ctx context.Context) (shellapp.Backend, error) {
	config.CleanupStrayHyprlandConfFile(log.Infof)
	server.CLIVersion = Version

	srv := server.New()
	if err := srv.Listen(); err != nil {
		return nil, err
	}

	backend := &advsBackend{srv: srv, done: make(chan error, 1)}
	go func() {
		defer func() {
			if r := recover(); r != nil {
				backend.done <- fmt.Errorf("server panic: %v", r)
			}
		}()
		backend.done <- srv.Serve(false)
	}()

	return backend, nil
}

func preLaunch() {
	go printASCII()
	ensureFontCache()
}

func advsExtraEnv(string) []string {
	var env []string
	if selfPath, err := os.Executable(); err == nil {
		env = append(env, "ADVS_EXECUTABLE="+selfPath)
	}
	if os.Getenv("QSG_USE_SIMPLE_ANIMATION_DRIVER") == "" {
		env = append(env, "QSG_USE_SIMPLE_ANIMATION_DRIVER=1")
	}
	if _, set := os.LookupEnv("MALLOC_CONF"); !set {
		env = append(env, "MALLOC_CONF=thp:never,narenas:4,dirty_decay_ms:3000")
	}
	return env
}
