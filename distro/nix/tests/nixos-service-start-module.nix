{
  self,
  pkgs,
  ...
}:
let
  fakeAdvs = pkgs.writeShellScriptBin "advs" ''
    printf '%s\n' "$@" > /tmp/advs-service-args
    exec ${pkgs.coreutils}/bin/sleep 300
  '';
in
pkgs.testers.runNixOSTest {
  name = "advs-nixos-service-start-module";

  nodes.machine = {
    imports = [
      self.nixosModules.ariadnev-shell
    ];

    users.users.ariadnev = {
      isNormalUser = true;
      linger = true;
      extraGroups = [ "wheel" ];
    };

    programs.ariadnev-shell = {
      enable = true;
      package = fakeAdvs;
      systemd = {
        enable = true;
        target = "default.target";
      };
    };

    system.stateVersion = "25.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")

    machine.succeed("systemctl --machine=ariadnev@ --user start advs.service")
    machine.wait_until_succeeds("systemctl --machine=ariadnev@ --user is-active advs.service")
    machine.wait_until_succeeds("test -f /tmp/advs-service-args")
    machine.succeed("grep -Fx run /tmp/advs-service-args")
    machine.succeed("grep -Fx -- --session /tmp/advs-service-args")
  '';
}
