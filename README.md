# Gershwin Software

Software management tool focused on GNUstep applications

Prerequisites

```
sudo pkg install -g 'GhostBSD*-dev'
sudo pkg install gershwin-developer
```

[Gershwin authentication](https://github.com/gershwin-desktop/gershwin-authentication) must also be installed for this to work

### Features

- Automates build and installation of highly integrated GNUstep wrappers (does require the specific apps to be installed by pkg for now)
- Automates build and installation of GNUstep applications that work well on Gershwin

## Build Instructions

Note it is not recommended to install at this time since this will replace Software Station.  This will be packaged to replace Software Station in a future release.

### Build
```bash
gmake
```

### Run
```bash
openapp ./Software.app
```
