# Package lists for the source machine

Machine-readable snapshots. Regenerate by hand when apps change:

```sh
pacman -Qqen > packages/pkglist-pacman.txt   # explicit, native + omarchy repo
pacman -Qqm  > packages/pkglist-aur.txt      # foreign (AUR); has been empty so far
flatpak list --app --columns=application > packages/pkglist-flatpak.txt
```

These files are **documentation only** — `apply.sh` and `sync.sh` never read them and
never install anything from them on a destination box. Human map + quirks: `MACHINE.md`.
