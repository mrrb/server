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
│   │   │   ├── sync
│   │   │   │   ├── PC
│   │   │   │   ├── Phone
│   │   │   │   └── ...
│   │   │   ├── media
│   │   │   ├── share
│   │   │   └── ...
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
