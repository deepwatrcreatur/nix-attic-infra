{ pkgs, lib, self }:

let
  # NixOS options documentation
  nixosOptions = lib.evalModules {
    modules = [
      self.nixosModules.attic-client
      self.nixosModules.attic-post-build-hook
      self.nixosModules.attic-observatory
      # Add minimal stubs for required base options if needed
      { 
        options.networking.hostName = lib.mkOption { type = lib.types.str; default = "host"; description = "Hostname stub"; };
        options.services.nginx = lib.mkOption { type = lib.types.anything; default = { }; description = "Nginx stub"; };
        options.systemd.services = lib.mkOption { type = lib.types.anything; default = { }; description = "Systemd services stub"; };
        options.systemd.timers = lib.mkOption { type = lib.types.anything; default = { }; description = "Systemd timers stub"; };
        config._module.check = false; 
      }
    ];
    specialArgs = { inherit pkgs; };
  };

  # Filter to only include our options
  ourNixosOptions = lib.filterAttrs (n: v: n == "services") nixosOptions.options;

  nixosDocs = pkgs.nixosOptionsDoc {
    options = ourNixosOptions;
    warningsAreErrors = false;
  };

  # Home Manager options documentation
  hmOptions = lib.evalModules {
    modules = [
      self.homeManagerModules.attic-client
      # HM specific types/options are often in lib or specific modules
      {
        options.home.homeDirectory = lib.mkOption { type = lib.types.path; default = "/home/user"; description = "Home directory stub"; };
        options.home.username = lib.mkOption { type = lib.types.str; default = "user"; description = "Username stub"; };
        options.home.stateVersion = lib.mkOption { type = lib.types.str; default = "25.11"; description = "State version stub"; };
        config._module.check = false;
      }
    ];
    specialArgs = { inherit pkgs; };
  };

  ourHmOptions = lib.filterAttrs (n: v: n == "programs") hmOptions.options;

  hmDocs = pkgs.nixosOptionsDoc {
    options = ourHmOptions;
    warningsAreErrors = false;
  };

in
pkgs.runCommand "generate-module-docs" { } ''
  mkdir -p $out
  
  echo "# Module Options Reference" > $out/OPTIONS.md
  echo "" >> $out/OPTIONS.md
  
  echo "## NixOS Modules" >> $out/OPTIONS.md
  echo "" >> $out/OPTIONS.md
  cat ${nixosDocs.optionsCommonMark} >> $out/OPTIONS.md
  
  echo "" >> $out/OPTIONS.md
  echo "## Home Manager Module" >> $out/OPTIONS.md
  echo "" >> $out/OPTIONS.md
  cat ${hmDocs.optionsCommonMark} >> $out/OPTIONS.md
''
