{
  description = "Burrow — native macOS disk cleaner dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  # Burrow ships only for macOS — Swift toolchain and SwiftUI 6 require
  # Apple's Xcode bundle (`xcode-select -p`). Nix manages everything around it:
  # xcodegen (project generation), swiftlint, and gh (issue tracker).
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-darwin" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            xcodegen
            swiftlint
            gh
          ];

          shellHook = ''
            echo "Burrow dev shell"
            echo "  xcodegen  $(xcodegen --version 2>&1 | head -1)"
            echo "  swiftlint $(swiftlint --version 2>&1 | head -1)"
            echo "  gh        $(gh --version 2>&1 | head -1)"
            echo ""
            if ! xcode-select -p >/dev/null 2>&1; then
              echo "⚠️  Xcode not found. Install from the App Store, then:"
              echo "    sudo xcode-select -s /Applications/Xcode.app"
            else
              echo "  swift     $(xcrun swift --version 2>&1 | head -1)"
              echo "  xcode     $(xcode-select -p)"
            fi
          '';
        };
      });
}
