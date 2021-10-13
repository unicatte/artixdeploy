# Artix install script

An Artix install script that aims to simplify the install process for an Arch user that's familiar with the core install process.

The installer aims to set up Artix from the ground-up the way I personally use it. For this reason customization options are very limited.

**Use at your own risk ONLY!**

Features
- Linux-zen, runit installation
- One partition setup (and EFI system partition, if selected)
- Swapfile
- GRUB on a MBR installation, EFISTUB (untested) on a GPT installation
- Basic ucode and driver installation
- Additional Arch repositories. Multilib entries present but commented.
- Post base install handled by my fork of [LARBS](https://github.com/unicatte/LARBS)

## Installation

```
$ git clone https://github.com/unicatte/artixdeploy.git
$ cd artixdeploy
# sh artixdeploy.sh
```
