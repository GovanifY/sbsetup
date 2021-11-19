Secure Boot Self Setup
=====

`./sbsetup.sh` is a small script that will setup a shim+grub signed setup,
signed with a db key that you own, along with the full Secure Boot chain: PK and
KEK; no MOK involved!

## Security Notes

If you want to have a full Secure Boot chain you _need_ to have a single encrypted
/boot with grub. Not following this requirement will make
it trivial for someone to pop up a GRUB command line and boot on one of your
signed kernel in another rootfs. The only partition that is tolerated
unencrypted in this setup is your ESP/EFI partition, and nothing else.

This setup does not protect you against attacks targeting the UEFI/SPI 
and/or the hardware itself.
While Intel Boot Guard might help there is always the possibility that you might
be able to make your UEFI forget it has a password, or that a state agency has
the keys to your domain. This will not protect you against a dedicated attacker,
who could always replace your motherboard wholly and, even if you do have a TPM
enforced boot process, could always replicate your password prompt 1:1 before
siphoning it out. Sure, it is harder, but not impossible.

I recommend that you get some motion detectors if that is your threat model.

## Instructions

1. Make sure your UEFI runs in Secure Boot Setup Mode. 
   TianoCore runs in this mode by default, otherwise it's different per brand, and 
   some do not have any; you're on your own. (hint: ThinkPads support it).

2. Setup a strong password and lock your UEFI settings behind it. You may also
   lock boot options but that's unnecessary: with this setup only binaries you
   _sign yourself_ will allow to be booted, unless you disable Secure Boot.

3. Run ./sbsetup.sh as root with an active internet connection.

4. Reboot your computer and enjoy your Secure Boot chain :)
