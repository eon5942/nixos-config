# Recipient rules for `agenix -e` / `agenix -r` (the CLI reads this file's
# `publicKeys` to know who to encrypt each secret to). The NixOS module side
# (age.secrets.* in configuration.nix) only needs the .age file path; it
# decrypts with the keys in `age.identityPaths`.
let
  eon = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICtTd5dtPS3gfjQdsnKSJamvX/n9vFMt2+Zui9We2mUT";
in
{
  "secrets/eon-password.age".publicKeys = [ eon ];
}
