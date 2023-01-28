{
  inputs.haskell-nix.follows = "kigoe/haskell-nix";
  inputs.nixpkgs.follows = "kigoe/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.haskell-nix-utils.url = "gitlab:rimmington/haskell-nix-utils";
  inputs.kigoe.url = "/home/rhys/workspace/kigoe";
  inputs.tuple.follows = "kigoe/tuple";
  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };
  outputs = { self, nixpkgs, flake-utils, haskell-nix, haskell-nix-utils, tuple, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
    let
      overlays = [
        haskell-nix.overlay
        haskell-nix-utils.overlays.default
      ];
      pkgs = import nixpkgs { inherit system overlays; inherit (haskell-nix) config; };
      utils = pkgs.haskell-nix-utils;
      project = utils.stackageProject' {
        resolver = "lts-20.2";
        name = "postgresql-pure";
        src = utils.cleanGitHaskellSource { name = "postgresql-pure-src"; src = self; };
        cabalFile = ./postgresql-pure.cabal;
        fromSrc.homotuple.src = "${tuple}/homotuple";
        fromSrc.single-tuple.src = "${tuple}/single-tuple";
        fromHackage = utils.hackage-sets.hls_1_8_0_0 // {
          # postgresql-pure = "0.2.3.0";
            either-result = "0.3.1.0";
            # homotuple = "0.2.0.0";
            list-tuple = "0.1.3.0";
            postgresql-placeholder-converter = "0.2.0.0";
            # single-tuple = "0.1.2.0";
        };
        modules = [
          {
            packages.homotuple.components.library.doHaddock = false;
            packages.list-tuple.components.library.doHaddock = false;
            packages.postgresql-pure.components.library.doHaddock = false;
          }
          {
            # https://github.com/haskell/haskell-language-server/issues/3185#issuecomment-1250264515
            packages.hlint.flags.ghc-lib = true;
            # https://github.com/haskell/haskell-language-server/blob/5d5f7e42d4edf3f203f5831a25d8db28d2871965/cabal.project#L67
            packages.ghc-lib-parser-ex.flags.auto = false;
            packages.stylish-haskell.flags.ghc-lib = true;

            # Disable unused formatters that take a while to build
            packages.haskell-language-server.flags.fourmolu = false;
            packages.haskell-language-server.flags.ormolu = false;
          }
        ];
        shell = {
          withHoogle = false;
          exactDeps = true;
          nativeBuildInputs = [
            pkgs.cabal-install
            pkgs.postgresql_12
            project.hsPkgs.hspec-discover.components.exes.hspec-discover
            project.hsPkgs.stylish-haskell.components.exes.stylish-haskell
            project.hsPkgs.haskell-language-server.components.exes.haskell-language-server
          ];
        };
      };
      additionalPackages = {};
    in pkgs.lib.recursiveUpdate project.flake' {
      packages = additionalPackages;
    });

  nixConfig = {
    allow-import-from-derivation = "true";
  };
}
