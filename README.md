# Arch install script

An Arch-based install script that aims to simplify the install process for an Arch user that's familiar with the [core install process](https://wiki.archlinux.org/title/Installation_guide).

The installer aims to set up Arch from the ground-up the way I personally use it. For this reason customization options are very limited.

**Use at your own risk ONLY!**

Features
- Linux-zen
- OpenRC if installing Artix
- One partition setup (and EFI system partition, if needed)
- Swapfile sized as big as RAM
- GRUB on an MBR installation, EFISTUB (untested) on a GPT installation
- Basic ucode and driver installation
- Arch repositories on Artix. Multilib entries present but commented.
- Post base install handled by my fork of [LARBS](https://github.com/unicatte/LARBS)

## Installation

```
$ git clone https://github.com/unicatte/artixdeploy.git
$ cd artixdeploy
# sh artixdeploy.sh
```
