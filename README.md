rpi-custom-installer
====================

A script for building a Raspbian system by using the debootstrap utility.


How to use it
-------------

In its current state, the ``rpi_raspbian_installer.sh`` script will prepare a Raspbian system with GIT support. The generated system contains a SSH server (openssh-server).
You can customize the generated system by modifying the following variables:

- ``ROOT_PASSWD``: the password of the root user
- ``DEB_MIRROR``: the raspbian mirror specified in the /etc/apt/sources.list file
- ``PACKAGES``: the packages to install on the generated system
- ``HOSTNAME_RPI``: the hostname of the system
- ``TIMEZONE``: the timezone (eg ``Europe/Paris``)
- ``LOCALES``: the locales to generate (eg ``fr_FR.UTF-8 UTF-8``)
- ``KEYBOARD_CONFIGURATION``: the keyboard configuration (eg ``fr``)

Some other params can be modified like the ``FSTAB`` content, the ``NETWORKING`` configuration file, etc.
