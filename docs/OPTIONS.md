# Module Options Reference

## NixOS Modules

## services\.attic-client\.enable



Whether to enable Attic client for NixOS with secrets management\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `



## services\.attic-client\.enablePostBuildHook



Whether to enable automatic pushing to the cache via ` nix.settings.post-build-hook `\.

Prefer the dedicated ` services.attic-post-build-hook ` module when possible\.



*Type:*
boolean



*Default:*
` false `



## services\.attic-client\.ageSecretFile

Path to the age-encrypted secret file (\.age)\. Only used when secretsBackend = “agenix”\.
The file should contain the raw JWT token\.



*Type:*
null or absolute path



*Default:*
` null `



*Example:*
` ./secrets/attic-client-token.age `



## services\.attic-client\.ageSecretGroup



Group of the decrypted agenix secret file



*Type:*
string



*Default:*
` "root" `



## services\.attic-client\.ageSecretOwner



Owner of the decrypted agenix secret file



*Type:*
string



*Default:*
` "root" `



## services\.attic-client\.cache



The name of the cache to use for pulls and pushes



*Type:*
string



*Default:*
` "cache-local" `



*Example:*
` "main" `



## services\.attic-client\.configureNixSubstituter



Whether to configure Nix substituters for the cache\.



*Type:*
boolean



*Default:*
` true `



## services\.attic-client\.manualTokenPath



Path to the token file when using secretsBackend = “none”\.
You are responsible for ensuring this file exists with the correct permissions\.



*Type:*
null or string



*Default:*
` null `



*Example:*
` "/run/secrets/attic-client-token" `



## services\.attic-client\.secretsBackend



Which secrets backend to use for managing the Attic token\.

 - “sops”: Use sops-nix (requires sops-nix module)
 - “agenix”: Use agenix (requires agenix module)
 - “none”: Manual token management (provide manualTokenPath)



*Type:*
one of “sops”, “agenix”, “none”



*Default:*
` "sops" `



*Example:*
` "agenix" `



## services\.attic-client\.server



The URL of the Attic cache server



*Type:*
string



*Default:*
` "http://localhost:5001" `



*Example:*
` "https://cache.example.com" `



## services\.attic-client\.serverName



The name used in the generated Attic config (used as a prefix for
pushes like ` serverName:cache `)\.



*Type:*
string



*Default:*
` "attic-cache" `



*Example:*
` "attic" `



## services\.attic-client\.tokenFile



Path to the SOPS encrypted token file\. Only used when secretsBackend = “sops”\.
If null with sops backend, you must ensure a token is available at /run/secrets/attic-client-token\.



*Type:*
null or absolute path



*Default:*
` null `



## services\.attic-client\.tokenKey



The key name in the SOPS file containing the token (sops backend only)



*Type:*
string



*Default:*
` "ATTIC_CLIENT_JWT_TOKEN" `



## services\.attic-client\.trustedPublicKeys



Additional trusted public keys for the configured substituter\.



*Type:*
list of string



*Default:*
` [ ] `



## services\.attic-observatory\.enable



Whether to enable Attic Observatory dashboard\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `



## services\.attic-observatory\.package



Package providing the attic-observatory executable\.



*Type:*
package



*Default:*
` inputs.attic-observatory.packages.x86_64-linux.default `



## services\.attic-observatory\.database\.refreshInterval



How often to refresh the attic-observatory database snapshot\.



*Type:*
string



*Default:*
` "1m" `



## services\.attic-observatory\.database\.refreshOnBootSec



Delay before the first database snapshot is taken after boot\.



*Type:*
string



*Default:*
` "2m" `



## services\.attic-observatory\.database\.snapshotPath



Path to the read-only database snapshot served by attic-observatory\.



*Type:*
string



*Default:*
` "/var/lib/attic-observatory/server.db" `



## services\.attic-observatory\.database\.sourcePath



Path to the live Attic SQLite database\.



*Type:*
string



*Default:*
` "/var/lib/atticd/server.db" `



## services\.attic-observatory\.dependOnAtticd



Whether to depend on the local atticd\.service\.
Set to false if atticd is running on a different host and you are
syncing the database snapshot manually\.



*Type:*
boolean



*Default:*
` true `



## services\.attic-observatory\.listenAddress



Address the attic-observatory application listens on\.



*Type:*
string



*Default:*
` "127.0.0.1" `



## services\.attic-observatory\.listenPort



Port the attic-observatory application listens on\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*
` 8088 `



## services\.attic-observatory\.nginx\.enable



Whether to expose attic-observatory through nginx\.



*Type:*
boolean



*Default:*
` true `



## services\.attic-observatory\.nginx\.listenAddress



Address nginx listens on for the attic-observatory UI\.



*Type:*
string



*Default:*
` "0.0.0.0" `



## services\.attic-observatory\.nginx\.port



Port nginx listens on for the attic-observatory UI\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*
` 8082 `



## services\.attic-observatory\.nginx\.virtualHost



Name of the nginx virtual host used for attic-observatory\.



*Type:*
string



*Default:*
` "attic-observatory" `



## services\.attic-observatory\.openFirewall



Whether to open the nginx UI port in the firewall\.



*Type:*
boolean



*Default:*
` false `



## services\.attic-observatory\.theme



Default attic-observatory theme\.



*Type:*
string



*Default:*
` "sugarplum" `



## services\.attic-post-build-hook\.enable



Whether to enable Attic post-build hook for automatic cache uploads\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `



## services\.attic-post-build-hook\.cacheName



The name of the cache to push to



*Type:*
string



*Default:*
` "cache-local" `



*Example:*
` "main" `



## services\.attic-post-build-hook\.serverEndpoint



The URL of the Attic cache server



*Type:*
string



*Default:*
` "http://localhost:5001" `



*Example:*
` "https://cache.example.com" `



## services\.attic-post-build-hook\.serverHostnames



List of hostnames running atticd that should not have post-build hooks enabled
to prevent circular dependencies\.



*Type:*
list of string



*Default:*

```
[
  "atticd"
  "attic-cache"
  "cache-server"
]
```



## services\.attic-post-build-hook\.serverName



The name used in the generated Attic config (used as a prefix for
pushes like ` serverName:cache `)\.



*Type:*
string



*Default:*
` "attic-cache" `



*Example:*
` "attic" `



## services\.attic-post-build-hook\.tokenFile



Runtime path to a plain-text file containing the Attic token\.
If set, the post-build hook reads this file at execution time and
generates an ephemeral Attic config outside the Nix store\.



*Type:*
null or string or absolute path



*Default:*
` null `



*Example:*
` config.sops.secrets."attic-client-token".path `



## services\.attic-post-build-hook\.verbose



Whether to enable verbose diagnostic logging for the post-build hook\.



*Type:*
boolean



*Default:*
` false `



## services\.nginx



Nginx stub



*Type:*
anything



*Default:*
` { } `



## Home Manager Module

## programs\.attic-client\.enable

Whether to enable Attic binary cache client with SOPS-managed authentication\.



*Type:*
boolean



*Default:*
` false `



*Example:*
` true `



## programs\.attic-client\.enableShellAliases



Whether to create convenient shell aliases for attic push commands



*Type:*
boolean



*Default:*
` true `



## programs\.attic-client\.servers



Attic servers configuration



*Type:*
attribute set of (submodule)



*Default:*
` { } `



*Example:*

```
{
  development = {
    aliases = [
      "dev"
    ];
    endpoint = "http://cache.dev.example.com:5001";
    tokenPath = "/path/to/dev-token";
  };
  production = {
    aliases = [
      "prod"
      "main"
    ];
    endpoint = "https://cache.prod.example.com";
    tokenPath = "/path/to/prod-token";
  };
}
```



## programs\.attic-client\.servers\.\<name>\.aliases



List of cache names to create shell aliases for\.
Creates ‘attic-push-{name}’ aliases for each entry\.



*Type:*
list of string



*Default:*
` [ ] `



*Example:*

```
[
  "main"
  "dev"
]
```



## programs\.attic-client\.servers\.\<name>\.endpoint



Attic server endpoint URL



*Type:*
string



*Example:*
` "https://cache.example.com" `



## programs\.attic-client\.servers\.\<name>\.tokenPath



Path to the token file (typically managed by SOPS)\.
The file should contain a valid Attic authentication token\.



*Type:*
string



*Default:*
` "/home/user/.config/sops/attic-token" `



## programs\.attic-client\.tokenSubstitution



Whether to enable automatic token substitution during home-manager activation\.
When disabled, you must manually manage the attic configuration file\.



*Type:*
boolean



*Default:*
` true `


