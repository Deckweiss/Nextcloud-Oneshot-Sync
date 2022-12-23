# Nextcloud-Oneshot-Sync

Due to the lack of a scheduled sync functionality in nextcloud (see https://github.com/nextcloud/desktop/issues/96), I have created a helper script that can be run on a timer. The configuration is done in the regular nextcloud desktop client and is parsed by the script on the fly.

It requires that the nextcloud desktop app is authorized with KDE wallet, which is then read automatically by the script. This is done in this way because I didn't like the idea of leaving the password in a plaintext netrc file.

# Setup
1. download `nextcloud-oneshot-sync`
2. move it somewhere in your PATH like `~/.local/bin`
3. make it executable
4. test it by running it manually through a terminal
5. in case of issues run with `-v` and share the output
