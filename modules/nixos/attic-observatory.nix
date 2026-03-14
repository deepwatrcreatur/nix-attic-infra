{
  atticObservatory,
}:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.attic-observatory;

  appUser = "attic-observatory";
  appGroup = "attic-observatory";

  dbSyncScript = pkgs.writeShellScript "attic-observatory-db-sync" ''
    set -euo pipefail

    tmp_db="$(mktemp ${lib.escapeShellArg "${cfg.database.snapshotPath}.tmp.XXXXXX"})"
    trap 'rm -f "$tmp_db"' EXIT

    ${pkgs.sqlite}/bin/sqlite3 ${lib.escapeShellArg cfg.database.sourcePath} ".timeout 5000" ".backup \"$tmp_db\""
    chown root:${appGroup} "$tmp_db"
    chmod 0440 "$tmp_db"
    mv -- "$tmp_db" ${lib.escapeShellArg cfg.database.snapshotPath}
    trap - EXIT
  '';
in
{
  options.services.attic-observatory = {
    enable = lib.mkEnableOption "Attic Observatory dashboard";

    package = lib.mkOption {
      type = lib.types.package;
      default = atticObservatory.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "inputs.attic-observatory.packages.${pkgs.stdenv.hostPlatform.system}.default";
      description = "Package providing the attic-observatory executable.";
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = "sugarplum";
      description = "Default attic-observatory theme.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the attic-observatory application listens on.";
    };

    listenPort = lib.mkOption {
      type = lib.types.port;
      default = 8088;
      description = "Port the attic-observatory application listens on.";
    };

    database = {
      sourcePath = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/atticd/server.db";
        description = "Path to the live Attic SQLite database.";
      };

      snapshotPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/attic-observatory/server.db";
        description = "Path to the read-only database snapshot served by attic-observatory.";
      };

      refreshOnBootSec = lib.mkOption {
        type = lib.types.str;
        default = "2m";
        description = "Delay before the first database snapshot is taken after boot.";
      };

      refreshInterval = lib.mkOption {
        type = lib.types.str;
        default = "1m";
        description = "How often to refresh the attic-observatory database snapshot.";
      };
    };

    nginx = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to expose attic-observatory through nginx.";
      };

      virtualHost = lib.mkOption {
        type = lib.types.str;
        default = "attic-observatory";
        description = "Name of the nginx virtual host used for attic-observatory.";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Address nginx listens on for the attic-observatory UI.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8082;
        description = "Port nginx listens on for the attic-observatory UI.";
      };
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the nginx UI port in the firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${appUser} = {
      isSystemUser = true;
      group = appGroup;
    };

    users.groups.${appGroup} = { };

    systemd.services.attic-observatory-db-sync = {
      description = "Refresh Attic Observatory database snapshot";
      after = [ "atticd.service" ];
      requires = [ "atticd.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = dbSyncScript;
        User = "root";
        Group = "root";
        StateDirectory = "attic-observatory";
        UMask = "0027";
      };
    };

    systemd.timers.attic-observatory-db-sync = {
      description = "Refresh Attic Observatory database snapshot";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.database.refreshOnBootSec;
        OnUnitActiveSec = cfg.database.refreshInterval;
        Unit = "attic-observatory-db-sync.service";
      };
    };

    systemd.services.attic-observatory = {
      description = "Attic Observatory dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "atticd.service"
        "attic-observatory-db-sync.service"
      ];
      requires = [
        "atticd.service"
        "attic-observatory-db-sync.service"
      ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/attic-observatory";
        Restart = "on-failure";
        RestartSec = "5";
        User = appUser;
        Group = appGroup;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
      };
      environment = {
        ATTIC_DB_PATH = cfg.database.snapshotPath;
        ATTIC_OBSERVATORY_HOST = cfg.listenAddress;
        ATTIC_OBSERVATORY_PORT = toString cfg.listenPort;
        ATTIC_OBSERVATORY_THEME = cfg.theme;
      };
    };

    services.nginx.enable = lib.mkIf cfg.nginx.enable (lib.mkDefault true);

    services.nginx.virtualHosts.${cfg.nginx.virtualHost} = lib.mkIf cfg.nginx.enable {
      listen = [
        {
          addr = cfg.nginx.listenAddress;
          port = cfg.nginx.port;
        }
      ];
      locations."/" = {
        proxyPass = "http://${cfg.listenAddress}:${toString cfg.listenPort}";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          add_header X-Cache-Source "attic-observatory";
        '';
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.nginx.enable && cfg.openFirewall) [ cfg.nginx.port ];
  };
}
