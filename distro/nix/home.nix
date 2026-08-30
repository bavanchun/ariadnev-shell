{
  config,
  pkgs,
  lib,
  ...
}@args:
let
  cfg = config.programs.ariadnev-shell;
  jsonFormat = pkgs.formats.json { };
  common = import ./common.nix {
    inherit
      config
      pkgs
      lib
      ;
  };
  hasPluginSettings = lib.any (plugin: plugin.settings != { }) (
    lib.attrValues (lib.filterAttrs (n: v: v.enable) cfg.plugins)
  );
  pluginSettings = lib.mapAttrs (name: plugin: { enabled = plugin.enable; } // plugin.settings) (
    lib.filterAttrs (n: v: v.enable) cfg.plugins
  );
in
{
  imports = [
    (import ./options.nix args)
    (lib.mkRemovedOptionModule [
      "programs"
      "ariadnev-shell"
      "enableNightMode"
    ] "Night mode is now always available")
    (lib.mkRemovedOptionModule [
      "programs"
      "ariadnev-shell"
      "default"
      "settings"
    ] "Default settings have been removed and been replaced with programs.ariadnev-shell.settings")
    (lib.mkRemovedOptionModule [
      "programs"
      "ariadnev-shell"
      "default"
      "session"
    ] "Default session has been removed and been replaced with programs.ariadnev-shell.session")
    (lib.mkRenamedOptionModule
      [ "programs" "ariadnev-shell" "enableSystemd" ]
      [ "programs" "ariadnev-shell" "systemd" "enable" ]
    )
  ];

  options.programs.ariadnev-shell = {
    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = "AriadnevShell configuration settings as an attribute set, to be written to ~/.config/AriadnevShell/settings.json.";
    };

    clipboardSettings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = "AriadnevShell clipboard settings as an attribute set, to be written to ~/.config/AriadnevShell/clsettings.json.";
    };

    session = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = "AriadnevShell session settings as an attribute set, to be written to ~/.local/state/AriadnevShell/session.json.";
    };

    managePluginSettings = lib.mkOption {
      type = lib.types.bool;
      default = hasPluginSettings;
      description = ''Whether to manage plugin settings. Automatically enabled if any plugins have settings configured.'';
    };

    systemd.target = lib.mkOption {
      type = lib.types.str;
      default = config.wayland.systemd.target;
      defaultText = lib.literalExpression "config.wayland.systemd.target";
      description = "Systemd target to bind to.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.quickshell = {
      enable = true;
      inherit (cfg.quickshell) package;
    };

    systemd.user.services.advs = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "AriadnevShell";
        PartOf = [ cfg.systemd.target ];
        After = [ cfg.systemd.target ];
      };

      Service = {
        ExecStart = lib.getExe cfg.package + " run --session";
        Restart = "on-failure";
        RestartForceExitStatus = "TEMPFAIL";
        SuccessExitStatus = "TEMPFAIL";
      };

      Install.WantedBy = [ cfg.systemd.target ];
    };

    xdg.stateFile."AriadnevShell/session.json" = lib.mkIf (cfg.session != { }) {
      source = jsonFormat.generate "session.json" cfg.session;
    };

    xdg.configFile = {
      "AriadnevShell/settings.json" = lib.mkIf (cfg.settings != { }) {
        source = jsonFormat.generate "settings.json" cfg.settings;
      };
      "AriadnevShell/clsettings.json" = lib.mkIf (cfg.clipboardSettings != { }) {
        source = jsonFormat.generate "clsettings.json" cfg.clipboardSettings;
      };
      "AriadnevShell/plugin_settings.json" = lib.mkIf cfg.managePluginSettings {
        source = jsonFormat.generate "plugin_settings.json" pluginSettings;
      };
    }
    // (lib.mapAttrs' (name: value: {
      name = "AriadnevShell/plugins/${name}";
      inherit value;
    }) common.plugins);
    warnings =
      lib.optional (!cfg.managePluginSettings && hasPluginSettings)
        "You have disabled managePluginSettings but provided plugin settings. These settings will be ignored.";
    home.packages = common.packages;
  };
}
