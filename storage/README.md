# Server storage

## Hetzner Storage Box directories

```
/
├── internal -> Internal stuff
│   ├── .ssh
│   └── ...
├── vault    -> Main folders to be used on the server
│   ├── gocryptfs
│   │   ├── generic.crypt -> Sync, media, shares, etc...
│   │   └── private.crypt -> Personal files (mine and others)
│   └── .ssh
├── other    -> Folder intended to be directly mounted and used as-is
│   ├── .ssh
│   └── ...
└── .ssh     -> SSH files, primarily the 'authorized_keys' one
```

## Commands

Mount a remote SSH file system

`sshfs [user@]host:[dir] mountpoint [options]`

Unmount a remote SSH file system

`fusermount3 -u mountpoint`

## Other

The `.ssh` folder contains both the public and private keys of the storage server.

All the remote `.ssh` folders need to have the previous public key on theirs `authorized_keys` file.

## Box structure creation

1. Mount the box on a local system and cd into it. See the [commands](#commands) section for more info.
2. On the mounted FS, create the desired folder structure.
    * `mkdir -p .ssh`
    * `mkdir -p ./{internal,vault,other}/.ssh`
    * `mkdir -p ./vault/gocryptfs/{generic.crypt,private.crypt}`
3. Create all the `authorized_keys` files.
    * `for dot_ssh_dir in $(find . -name '.ssh' -type d); do touch $dot_ssh_dir/authorized_keys; done`
4. [Optional] Add personal public key(s) to `authorized_keys` files.
    * `for ak_file in $(find . -wholename '*/.ssh/authorized_keys' -type f); do cat ~/.ssh/id_ed25519.pub >> $ak_file; done`

## Basic box config and subaccounts

1. Go to the Hetzner Robot platform, and select the desired storage box.
2. On the "Storage Box data" tab, disable all the options, except:
   * ***SSH support***
   * ***External reachability***
3. On the "Automatic Snapshots" tab, enable weekly snapshots.
4. On the "Sub-account" tab, create the following subaccounts.
   1. Internal
        * Base directory: internal
        * Allow Samba: No
        * Allow WebDAV: No
        * Allow SSH: Yes
        * External reachability: No
        * Read-only: No
        * Comment: Internal files not reachable externally
   2. Vault
        * Base directory: vault
        * Allow Samba: No
        * Allow WebDAV: No
        * Allow SSH: Yes
        * External reachability: No
        * Read-only: No
        * Comment: Raw vault folder
   3. Other
        * Base directory: other
        * Allow Samba: Yes
        * Allow WebDAV: Yes
        * Allow SSH: Yes
        * External reachability: Yes
        * Read-only: No
        * Comment: Directly access files

## Extra security

After the set-up, on the "Storage Box data" tab, disable the *External reachability* option.
