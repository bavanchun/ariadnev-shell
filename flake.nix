{
  description = "AriadnevShell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };
    ariadnev-qml-common = {
      url = "github:bavanchun/ariadnev-qml-common";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ariadnev-qml-common,
      ...
    }:
    let
      goModVersion =
        let
          content = builtins.readFile ./core/go.mod;
          lines = builtins.filter builtins.isString (builtins.split "\n" content);
          goLines = builtins.filter (l: builtins.match "go [0-9]+\\..*" l != null) lines;
          matched =
            if goLines != [ ] then builtins.match "go ([0-9]+)\\.([0-9]+).*" (builtins.head goLines) else null;
        in
        if matched != null then
          {
            major = builtins.elemAt matched 0;
            minor = builtins.elemAt matched 1;
          }
        else
          {
            major = "1";
            minor = "25";
          };
      goForPkgs = pkgs: pkgs.${"go_${goModVersion.major}_${goModVersion.minor}"};
      forEachSystem =
        fn:
        nixpkgs.lib.genAttrs [ "aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux" ] (
          system: fn system nixpkgs.legacyPackages.${system}
        );
      forEachLinuxSystem =
        fn:
        nixpkgs.lib.genAttrs [ "aarch64-linux" "x86_64-linux" ] (
          system: fn system nixpkgs.legacyPackages.${system}
        );

      mkModuleWithAdvsPkgs =
        modulePath:
        args@{ pkgs, ... }:
        {
          imports = [
            (import modulePath (args // { advsPkgs = buildAdvsPkgs pkgs; }))
          ];
        };

      mkQmlImportPath =
        pkgs: qmlPkgs:
        pkgs.lib.concatStringsSep ":" (map (o: "${o}/${pkgs.qt6.qtbase.qtQmlPrefix}") qmlPkgs);

      mkQtPluginPath =
        pkgs: qtPkgs:
        pkgs.lib.concatStringsSep ":" (map (o: "${o}/${pkgs.qt6.qtbase.qtPluginPrefix}") qtPkgs);

      qmlPkgs =
        pkgs: with pkgs.kdePackages; [
          kirigami.unwrapped
          sonnet
          qtmultimedia
          qtimageformats
          kimageformats
        ];

      # Allows downstream modules to provide their own 'pkgs' (with overlays)
      # instead of being forced to use the flake's locked nixpkgs.
      mkAdvsShell =
        pkgs:
        let
          mkDate =
            longDate:
            pkgs.lib.concatStringsSep "-" [
              (builtins.substring 0 4 longDate)
              (builtins.substring 4 2 longDate)
              (builtins.substring 6 2 longDate)
            ];
          version =
            let
              rawVersion = pkgs.lib.removePrefix "v" (pkgs.lib.trim (builtins.readFile ./quickshell/VERSION));
              cleanVersion = builtins.replaceStrings [ " " ] [ "" ] rawVersion;
              dateSuffix = "+date=" + mkDate (self.lastModifiedDate or "19700101");
              revSuffix = "_" + (self.shortRev or "dirty");
            in
            "${cleanVersion}${dateSuffix}${revSuffix}";
        in
        pkgs.lib.makeOverridable (
          {
            extraQtPackages ? [ ],
          }:
          (pkgs.buildGoModule.override { go = goForPkgs pkgs; }) (
            let
              rootSrc = ./.;
              qtPackages = (qmlPkgs pkgs) ++ extraQtPackages;
            in
            {
              inherit version;
              pname = "ariadnev-shell";
              src = ./core;
              vendorHash = "sha256-X9DzsqrHZt4SQWCTvoxEABTSSBVPvFIJqAH3mtcEfio=";

              subPackages = [ "cmd/advs" ];

              ldflags = [
                "-s"
                "-w"
                "-X 'main.Version=${version}'"
              ];

              nativeBuildInputs = with pkgs; [
                installShellFiles
                makeWrapper
              ];

              postInstall = ''
                mkdir -p $out/share/quickshell/ariadnev
                cp -r ${rootSrc}/quickshell/. $out/share/quickshell/ariadnev/

                rm -f $out/share/quickshell/ariadnev/AdvCommon
                cp -r ${ariadnev-qml-common}/AdvCommon $out/share/quickshell/ariadnev/AdvCommon
                chmod -R u+w $out/share/quickshell/ariadnev/AdvCommon

                chmod u+w $out/share/quickshell/ariadnev/VERSION
                echo "${version}" > $out/share/quickshell/ariadnev/VERSION

                # Install desktop file and icon
                install -D ${rootSrc}/assets/advs-open.desktop \
                  $out/share/applications/advs-open.desktop
                install -D ${rootSrc}/assets/dev.vchun.ariadnev.desktop \
                  $out/share/applications/dev.vchun.ariadnev.desktop
                install -D ${rootSrc}/assets/dev.vchun.ariadnev.notepad.desktop \
                  $out/share/applications/dev.vchun.ariadnev.notepad.desktop
                install -D ${rootSrc}/core/assets/advlogo.svg \
                  $out/share/hicolor/scalable/apps/advlogo.svg

                # Snapshot pre-wrap Qt paths so launched apps get their own, not ADVS's pins.
                wrapProgram $out/bin/advs \
                  --add-flags "-c $out/share/quickshell/ariadnev" \
                  --run 'export ADVS_ORIG_NIXPKGS_QT6_QML_IMPORT_PATH="''${NIXPKGS_QT6_QML_IMPORT_PATH:-}"' \
                  --run 'export ADVS_ORIG_QT_PLUGIN_PATH="''${QT_PLUGIN_PATH:-}"' \
                  --prefix "NIXPKGS_QT6_QML_IMPORT_PATH" ":" "${mkQmlImportPath pkgs qtPackages}" \
                  --prefix "QT_PLUGIN_PATH" ":" "${mkQtPluginPath pkgs qtPackages}"

                install -Dm644 ${rootSrc}/assets/systemd/advs.service \
                  $out/lib/systemd/user/advs.service

                substituteInPlace $out/lib/systemd/user/advs.service \
                  --replace-fail /usr/bin/advs $out/bin/advs \
                  --replace-fail /bin/kill ${pkgs.coreutils}/bin/kill

                substituteInPlace $out/share/quickshell/ariadnev/assets/pam/fprint \
                  --replace-fail pam_fprintd.so ${pkgs.fprintd}/lib/security/pam_fprintd.so \
                  --replace-fail pam_deny.so ${pkgs.pam}/lib/security/pam_deny.so \
                  --replace-fail pam_permit.so ${pkgs.pam}/lib/security/pam_permit.so

                substituteInPlace $out/share/quickshell/ariadnev/assets/pam/u2f \
                  --replace-fail pam_u2f.so ${pkgs.pam_u2f}/lib/security/pam_u2f.so \
                  --replace-fail pam_deny.so ${pkgs.pam}/lib/security/pam_deny.so \
                  --replace-fail pam_permit.so ${pkgs.pam}/lib/security/pam_permit.so

                substituteInPlace $out/share/quickshell/ariadnev/assets/pam/other \
                  --replace-fail pam_deny.so ${pkgs.pam}/lib/security/pam_deny.so

                installShellCompletion --cmd advs \
                  --bash <($out/bin/advs completion bash) \
                  --fish <($out/bin/advs completion fish) \
                  --zsh <($out/bin/advs completion zsh)
              '';

              meta = {
                description = "Desktop shell for wayland compositors built with Quickshell & GO";
                homepage = "https://github.com/bavanchun/ariadnev-shell";
                changelog = "https://github.com/bavanchun/ariadnev-shell/releases/tag/v${version}";
                license = pkgs.lib.licenses.mit;
                mainProgram = "advs";
                platforms = pkgs.lib.platforms.linux;
              };
            }
          )
        ) { };

      buildAdvsPkgs = pkgs: {
        ariadnev-shell = mkAdvsShell pkgs;
      };
    in
    {
      packages = forEachSystem (
        system: pkgs: {
          ariadnev-shell = mkAdvsShell pkgs;
          default = self.packages.${system}.ariadnev-shell;
          quickshell = builtins.warn "ariadnev-shell: the package Quickshell is not included in the ADVS flake anymore. We recommend you to use the one from nixos-unstable branch of Nixpkgs or the upstream flake." pkgs.quickshell;
        }
      );

      lib = { inherit mkAdvsShell buildAdvsPkgs; };

      homeModules.ariadnev-shell = mkModuleWithAdvsPkgs ./distro/nix/home.nix;

      homeModules.default = self.homeModules.ariadnev-shell;

      homeModules.niri = import ./distro/nix/niri.nix;



      nixosModules.ariadnev-shell = mkModuleWithAdvsPkgs ./distro/nix/nixos.nix;

      nixosModules.default = self.nixosModules.ariadnev-shell;

      nixosModules.greeter = builtins.warn "ariadnev-shell: the greeter lives in the ariadnev-greeter repo; use `inputs.ariadnev-greeter.nixosModules.default` and `programs.advs-greeter` (https://github.com/bavanchun/ariadnev-greeter)" { };


      devShells = forEachSystem (
        system: pkgs:
        let
          devQmlPkgs = with pkgs;
          [
            quickshell
            kdePackages.qtdeclarative
          ]
          ++ (qmlPkgs pkgs);
        in
        {
          default = pkgs.mkShell {
            buildInputs =
              with pkgs;
              [
                (goForPkgs pkgs)
                go-mockery
                gopls
                delve
                go-tools
                gnumake

                prek
                uv # for prek
                shellcheck

                # Nix development tools
                nixd
                nil
              ]
              ++ devQmlPkgs;

            shellHook = ''
              touch quickshell/.qmlls.ini 2>/dev/null
              if [ ! -f .git/hooks/pre-commit ]; then prek install; fi
            '';

            QML2_IMPORT_PATH = mkQmlImportPath pkgs devQmlPkgs;
            QT_PLUGIN_PATH = mkQtPluginPath pkgs devQmlPkgs;
          };
        }
      );

      nixosTests = forEachLinuxSystem (
        system: pkgs:
        import ./distro/nix/tests {
          inherit
            self
            pkgs
            ;
          lib = pkgs.lib;
        }
      );
    };
}
