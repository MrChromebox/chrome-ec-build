# chrome-ec-build

Docker-based builder for [MrChromebox Chrome EC](https://github.com/MrChromebox/chrome-ec) firmware (Link through Brask).

This repo holds **build tooling only**. The firmware tree is a separate git clone under `chrome-ec/` (gitignored).

## Layout

```
chrome-ec-build/          ← this repo
  build-docker.sh
  docker/
  chrome-ec/              ← your chrome-ec clone (not tracked)
```

## Setup

1. Clone this repo.
2. Place your Chrome EC checkout at `./chrome-ec` (move an existing tree, or clone):

   ```bash
   git clone git@github.com:MrChromebox/chrome-ec.git chrome-ec
   ```

3. Docker must be available. First board build for each image builds or pulls it.

Optional overrides:

| Variable | Default | Meaning |
|---|---|---|
| `EC_ROOT` | `./chrome-ec` | Path to the firmware tree |
| `COREBOOT_ROOT` | `$HOME/dev/coreboot` | Used with `--copy` for blob install |
| `EC_IMAGE_XENIAL` / `EC_IMAGE_FOCAL` / `EC_IMAGE_COREBOOT_SDK` | see script | Override Docker images |

## Usage

```bash
./build-docker.sh <board|generation>
./build-docker.sh --copy hatch          # also install ec.RW.flat into coreboot blobs
./build-docker.sh --full brya           # build ec.bin (RO+RW) instead of RW-only
./build-docker.sh --no-sync anahera     # do not checkout the firmware branch
./build-docker.sh --help
```

Default output is `chrome-ec/build/<board>/RW/ec.RW.flat` (what coreboot consumes).

### Docker images

| Image | Used for |
|---|---|
| Xenial (`chrome-ec-xenial:u16`) | link … kabylake, grunt |
| Focal (`chrome-ec-focal:u20`) | octopus (NPCX), hatch, puff, zork, dedede (NPCX), volteer |
| coreboot-sdk | octopus/ampton + dedede IT83xx (NDS32), brya, brask |

Generations and board lists: `./build-docker.sh --help`.

## Why a separate repo?

Firmware lives on many platform branches. Putting build scripts on those branches means duplication or an orphan tools branch. Keeping scripts here and the EC tree as an untracked nested clone avoids that.
