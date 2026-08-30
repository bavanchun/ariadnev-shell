{
  self,
  pkgs,
  ...
}:
pkgs.testers.runNixOSTest {
  name = "advs-nixos-module";

  nodes.machine = {
    imports = [
      self.nixosModules.ariadnev-shell
    ];

    users.users.ariadnev = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    programs.ariadnev-shell = {
      enable = true;
      systemd.enable = true;
      lockscreen.securityKey.enable = true;
      plugins = {
        TestPlugin = {
          src = pkgs.emptyDirectory;
        };
      };
    };

    system.stateVersion = "25.11";
  };

  testScript = ''
    import json

    machine.wait_for_unit("multi-user.target")

    machine.succeed("command -v advs")
    machine.succeed("command -v quickshell")
    machine.succeed("su -- ariadnev -c 'advs --help >/dev/null'")
    machine.succeed("test -d /etc/xdg/quickshell/ariadnev-plugins")
    machine.succeed("test -f /run/current-system/sw/lib/systemd/user/advs.service")
    machine.succeed("grep -q 'lib/security/pam_u2f.so cue' /etc/pam.d/advshell-u2f")

    payload = json.loads(machine.succeed("su -- ariadnev -c 'advs doctor --json'"))
    t.assertIn("summary", payload)
    t.assertIsInstance(payload.get("results"), list)
  '';
}
