{
  description = "Override pyproject-nix with nixpkgs python package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyproject-nix = {
      url = "github:nix-community/pyproject.nix/hacky-nixpkgs-prebuilt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:adisbladis/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    pyproject-nix,
    uv2nix,
    ...
  }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    python = pkgs.python312;
    workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};

    # Create package overlay from workspace.
    overlay = workspace.mkPyprojectOverlay {
      sourcePreference = "wheel"; 
    };

    hacks = pkgs.callPackages pyproject-nix.build.hacks {};

    pyprojectOverlay = final: prev: {
      torch = hacks.nixpkgsPrebuilt {
        from = pkgs.python312Packages.torchWithoutCuda;
        prev = prev.torch;
      };
    };
    # Inject your own packages on top with overrideScope
    pythonSet =
      (pkgs.callPackage pyproject-nix.build.packages {
        inherit python;
      })
      .overrideScope (pkgs.lib.composeExtensions overlay pyprojectOverlay);
  in {
    packages.x86_64-linux.default = pythonSet.mkVirtualEnv "test-venv" {
      pyproject-nix-cuda-issue = [];
    };
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = [pkgs.uv self.packages.x86_64-linux.default];
    };
  };
}
