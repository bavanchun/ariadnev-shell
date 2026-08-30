{ lib, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule
      [
        "programs"
        "advMaterialShell"
      ]
      [
        "programs"
        "adv-material-shell"
      ]
    )
  ];
}
