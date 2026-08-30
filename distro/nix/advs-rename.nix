{ lib, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule
      [
        "programs"
        "ariadnevShell"
      ]
      [
        "programs"
        "ariadnev-shell"
      ]
    )
  ];
}
