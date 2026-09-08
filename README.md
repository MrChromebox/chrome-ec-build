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
./build-docker.sh <board|generation|all> [board|generation ...]
./build-docker.sh --copy hatch
./build-docker.sh --copy dedede brya brask
./build-docker.sh --copy --keep-going --log cr50  # Skylake→Brask (CR50); continue; tee logs/
./build-docker.sh --copy --keep-going --log all   # Haswell→Brask; continue; tee logs/
./build-docker.sh --full brya
./build-docker.sh --no-sync anahera
./build-docker.sh --help
```

Default output is `chrome-ec/build/<board>/RW/ec.RW.flat` (what coreboot consumes).
With `--log`, output is also written to `logs/build-*.log` (or `$LOG_FILE`).

### Docker images

| Image | Used for |
|---|---|
| Xenial (`chrome-ec-xenial:u16`) | haswell … kabylake, grunt |
| Focal (`chrome-ec-focal:u20`) | octopus (NPCX), hatch, puff, zork, dedede (NPCX), volteer |
| coreboot-sdk | octopus/ampton + dedede IT83xx (NDS32), brya, brask |

**Link is not built by Docker.** `./build-docker.sh link` refuses to run. Link (`firmware-link-2695.B`) must be built in a **Chrome OS chroot** with CrOS `cross-arm-none-eabi` **gcc-4.9.2-r170**. Standard toolchains (Ubuntu `gcc-arm-none-eabi`, host Debian packages, etc.) produce RW images that **boot-loop and can brick** the device.

```bash
cros_sdk
cd ~/chrome-ec   # or your bind-mounted tree
git checkout firmware-link-2695.B
make BOARD=link
# output: build/link/ec.RW.flat  (ancient layout — not build/link/RW/)
```

Generations and board lists: `./build-docker.sh --help`.

## Board feature matrix

Local deltas vs the matching `upstream/<branch>` tip on each firmware branch.

| Board(s) | Branch | Features / fixes |
|---|---|---|
| **link** | `firmware-link-2695.B` | - Windows PS/2 keyboard fixes<br>- Fan lifecycle / quieter curve / RPM cap<br>- vboot_hash backport<br>- **Chrome OS chroot only** (Docker/standard toolchains brick) |
| **falco, peppy** | `firmware-falco_peppy-4389.B` | - Windows PS/2 keyboard fixes<br>- ACPI query-next-event mask<br>- Falco quieter fan curve |
| **wolf** | `firmware-wolf-4389.24.B` | - Windows PS/2 keyboard fixes<br>- ACPI query-next-event mask<br>- Sane fan speeds |
| **leon** | `firmware-leon-4389.61.B` | - Windows PS/2 keyboard fixes<br>- ACPI query-next-event mask |
| **banjo, candy, clapper, enguarde, expresso, gnawty, heli, kip, orco, quawks, squawks, sumo, swanky, winky** | per-board `firmware-<board>-5216.*.B` | - Windows PS/2 keyboard fixes |
| **glimmer** | `firmware-glimmer-5216.198.B` | - Windows PS/2 keyboard fixes<br>- Revert stock battery-update quirks |
| **ninja** | `firmware-ninja-5216.383.B` | |
| **buddy** | `firmware-buddy-6301.202.B` | |
| **gandof, paine, samus** | `firmware-<board>-630*.B` | - Windows PS/2 keyboard fixes |
| **lulu** | `firmware-lulu-6301.136.B` | - Windows PS/2 keyboard fixes<br>- Thermal limits<br>- KB light PWM default |
| **yuna** | `firmware-yuna-6301.59.B` | - Windows PS/2 keyboard fixes |
| **banon, kefka, relm, setzer, wizpig** | `firmware-strago-7287.B` | - Windows PS/2 keyboard fixes<br>- Kefka: tablet mode support |
| **celes, edgar, reks, terra, ultima** | `firmware-<board>-7287.*.B` | - Windows PS/2 keyboard fixes |
| **cyan** | `firmware-cyan-7287.57.B` | - Windows PS/2 keyboard fixes<br>- Tablet mode support<br>- Braswell Wi‑Fi power<br>- 8042/keyboard race backports |
| **asuka, caroline, cave, chell, lars, sentry** | `firmware-glados-7820.B` | - Windows PS/2 keyboard fixes<br>- Vivaldi keyboard support<br>- Top-row Fn toggle<br>- Charge-limit / battery sustainer<br>- Battery static refresh<br>- Caroline shared-mem floor for Vivaldi<br>- Chell: drop md/rw/mem console cmds (RW flash) |
| **coral** | `firmware-coral-10068.B` | - Windows PS/2 keyboard fixes<br>- Vivaldi keyboard support<br>- Top-row Fn toggle<br>- Charge-limit / battery sustainer<br>- Battery static refresh |
| **reef, pyro, sand, snappy, nasher** | `firmware-reef-9042.B` | - Windows PS/2 keyboard fixes<br>- Vivaldi keyboard support<br>- Top-row Fn toggle<br>- Charge-limit / battery sustainer<br>- Battery static refresh |
| **eve** | `firmware-eve-9584.B` | - Vivaldi keyboard support<br>- Top-row Fn toggle<br>- Charge-limit / battery sustainer<br>- Battery static refresh |
| **fizz** | `firmware-fizz-10139.B` | - S0ix / host-sleep alignment<br>- After-G3 power state<br>- Fan RPM defaults + auto fan on resume<br>- PD preserve across RO→RW |
| **karma** | `firmware-kalista-11343.B` | |
| **endeavour** | `firmware-endeavour-13259.B-master` | |
| **atlas** | `firmware-atlas-11827.B` | - Vivaldi keyboard support<br>- Top-row Fn toggle<br>- Battery static refresh |
| **nami** | `firmware-nami-10775.B` | - Vivaldi keyboard support<br>- Top-row Fn toggle<br>- Charge-limit / battery sustainer<br>- PD sink current limited to 3 A<br>- Battery static refresh |
| **nocturne** | `firmware-nocturne-10984.B` | - Charge-limit / battery sustainer<br>- Tablet mode from base attach (VBTN/TBMD)<br>- Battery static refresh |
| **nautilus**, **soraka** | `firmware-poppy-10431.B` | - Vivaldi keyboard support (nautilus only)<br>- Top-row Fn toggle<br>- Charge-limit / battery sustainer<br>- Battery static refresh |
| **rammus** | `firmware-rammus-11275.B` | - Vivaldi keyboard support<br>- Top-row Fn toggle<br>- Charge-limit / battery sustainer<br>- Motion-sensor FIFO 256 (RW RAM budget)<br>- Battery static refresh |
| **aleena, careena, grunt, liara, treeya** | `firmware-grunt-11031.B` | - Vivaldi keyboard support<br>- Top-row Fn toggle<br>- Battery static refresh |
| **ampton, bloog, bobba, casta, dood, fleex, foob, garg, lick, meep, phaser, yorp** | `firmware-octopus-11297.B` | - Vivaldi keyboard support<br>- Top-row Fn toggle<br>- Battery static refresh |
| **akemi, dratini, helios, jinlon, kindred, kohaku, nightfury** | `firmware-hatch-12672.B` | - Charge-limit / battery sustainer<br>- Vivaldi default keyboard config<br>- Top-row Fn toggle<br>- bq25710 VSYS PROCHOT<br>- Motionsense FIFO / 8042 ACK reverts<br>- Battery static refresh |
| **ambassador, dooly, genesis, moonbuggy, puff, scout** | `firmware-puff-13324.B-master` | - Custom fan RPM (puff/dooly)<br>- No TCPC reset on RO→RW |
| **berknip, dirinboz, ezkinil, gumboz, morphius, shuboz, vilboz, woomax** | `firmware-zork-13434.B-master` | - Vivaldi keyboard support<br>- Top-row Fn toggle<br>- i8042 self-test status on reset<br>- Battery static refresh<br>- Woomax: fan table OOB fix |
| **awasuki … waddledoo** (dedede set) | `firmware-dedede-13606.B-master` | - S4→G3 soft-off idle<br>- Top-row Fn toggle<br>- Battery static refresh |
| **chronicler, collis, copano, delbin, drobit, eldrid, elemi, lindar, voema, volet, voxel** | `firmware-volteer-13672.B-main` | - TBT5 / USB4 alt-mode cable handling<br>- Top-row Fn toggle<br>- i8042 self-test status on reset<br>- Battery static refresh |
| **anahera … xol** (brya set) | `firmware-ec-R136-16238.2.B-main` | - TBT5 / USB4 compatibility<br>- S4→G3 soft-off idle<br>- Top-row Fn toggle<br>- Battery static refresh<br>- Mithrax KB backlight init on `HOOK_INIT`<br>- Primus: fan table OOB fix |
| **aurash … nova** (brask set) | `firmware-android-brya-14505.885.B-main` | - TBT5 / USB4 compatibility<br>- S4→G3 soft-off idle |

### Feature glossary

| Label | Meaning |
|---|---|
| Windows PS/2 keyboard fixes | 8042 scanning stays enabled; stable CTR read; systemd-boot-safe disable; Ctrl+Alt+Del; sometimes ACPI query-next-event |
| Vivaldi keyboard support | Vivaldi top-row matrix + `EC_CMD_GET_KEYBD_CONFIG` backport |
| Top-row Fn toggle | `EC_CMD_KEYBD_TOP_ROW` (`0x013F`): switch the Vivaldi top row between ChromeOS action codes and standard F1..Fn make codes (coreboot NVRAM / ectool); does not change `GET_KEYBD_CONFIG` |
| S4→G3 soft-off idle | Hibernated AP S4 no longer parks forever in `POWER_S4` (~1W drain); after the existing S5 inactivity timeout the EC advances soft-off toward G3 / `CONFIG_HIBERNATE_DELAY_SEC` (Intel `POWER_S4` platforms only: brya, brask, dedede) |
| Battery static refresh | Static battery info is staged then published only on success; a transient gauge NAK no longer wipes the last good picture or freezes SoC (fixes crossed-out / 0% blips on Windows and FreeBSD). Battery-equipped Skylake+ (not chromeboxes) |
| Charge-limit / battery sustainer | `EC_CMD_CHARGE_CONTROL` v2, display-SoC thresholds, battery compensate where needed |
| S0ix / After-G3 | Host sleep alignment, After-G3 state, fan/LED behavior (fizz family) |
| TBT5 / USB4 compatibility | Thunderbolt 3/4 and USB4 alt-mode / cable handling fixes |
| Tablet mode | Lid-angle or base-attach driven tablet mode / input gating |
