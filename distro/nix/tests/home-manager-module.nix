{
  self,
  pkgs,
  ...
}:
let
  homeManagerNixosModule =
    (fetchTarball {
      url = "https://github.com/nix-community/home-manager/archive/53ebbdc405acc04acd9bb73ccca462b51ddb8c6d.tar.gz";
      sha256 = "1cqmfgwb3jac2zzv82bwvgypxff1z30xkz9j6qcinkmqf58j3k3b";
    })
    + "/nixos";
in
pkgs.testers.runNixOSTest {
  name = "advs-home-manager-module";

  nodes.machine = {
    ...
  }: {
    imports = [
      homeManagerNixosModule
    ];

    users.users.ariadnev = {
      isNormalUser = true;
      createHome = true;
      home = "/home/ariadnev";
      extraGroups = [ "wheel" ];
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

    home-manager.users.ariadnev = {
      pkgs,
      ...
    }: {
      imports = [
        self.homeModules.ariadnev-shell
      ];

      home.username = "ariadnev";
      home.homeDirectory = "/home/ariadnev";
      home.stateVersion = "25.11";

      programs.ariadnev-shell = {
        enable = true;
        systemd = {
          enable = true;
          target = "default.target";
        };

        settings = {
          theme = "integration-test";
        };

        clipboardSettings = {
          maxItems = 10;
        };

        session = {
          startedFrom = "nixos-test";
        };

        plugins.TestPlugin = {
          enable = true;
          src = pkgs.runCommand "advs-test-plugin" { } ''
            mkdir -p "$out"
            echo plugin > "$out/plugin.txt"
          '';
          settings = {
            enabled = true;
            source = "test";
          };
        };
      };
    };

    system.stateVersion = "25.11";
  };

  testScript = ''
    import json

    machine.wait_for_unit("multi-user.target")

    machine.succeed("su -- ariadnev -c 'command -v advs'")
    machine.succeed("su -- ariadnev -c 'test -f ~/.config/AriadnevShell/settings.json'")
    machine.succeed("su -- ariadnev -c 'test -f ~/.config/AriadnevShell/clsettings.json'")
    machine.succeed("su -- ariadnev -c 'test -f ~/.config/AriadnevShell/plugin_settings.json'")
    machine.succeed("su -- ariadnev -c 'test -e ~/.config/AriadnevShell/plugins/TestPlugin'")
    machine.succeed("su -- ariadnev -c 'test -f ~/.local/state/AriadnevShell/session.json'")

    settings = json.loads(machine.succeed("su -- ariadnev -c 'cat ~/.config/AriadnevShell/settings.json'"))
    clipboard = json.loads(machine.succeed("su -- ariadnev -c 'cat ~/.config/AriadnevShell/clsettings.json'"))
    session = json.loads(machine.succeed("su -- ariadnev -c 'cat ~/.local/state/AriadnevShell/session.json'"))
    plugins = json.loads(machine.succeed("su -- ariadnev -c 'cat ~/.config/AriadnevShell/plugin_settings.json'"))
    doctor = json.loads(machine.succeed("su -- ariadnev -c 'advs doctor --json'"))

    t.assertEqual(settings["theme"], "integration-test")
    t.assertEqual(clipboard["maxItems"], 10)
    t.assertEqual(session["startedFrom"], "nixos-test")
    t.assertTrue(plugins["TestPlugin"]["enabled"])
    t.assertEqual(plugins["TestPlugin"]["source"], "test")
    t.assertIsInstance(doctor.get("results"), list)
  '';
}
