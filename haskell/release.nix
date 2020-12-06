let
  nixpkgs = import ../nix/pkgs.nix;
  project = import (import ../nix/project.nix) { inherit nixpkgs; };
in project rec {
  packages = {
    asteroids = ./asteroids;
    plotting = ./plotting;
    kecsik = ./kecsik;
  };
  shellHook = pkgs: ''
    ${pkgs.addLiquidSolverHook}
  '';
  overlays = [
      (import (import ../nix/liquidhaskell.nix) { inherit compiler; })
      (import ../nix/haskell.nix { inherit compiler; })
    ];
  overlaysAfter = [ ((import ./solver.nix) { inherit compiler; }) ];
  compiler = "ghc8102";
}
