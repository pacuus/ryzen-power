# Universal Ryzen Power Management

Automated power profile management and thermal control for AMD Ryzen laptops on Linux using `ryzenadj` and `systemd` integration. My laptop (Asus TUF FX505DV) lacks fan control options and I wanted more granularity to control fans, speed, and temperature, which I wasn't able to do directly through ROG Control Center or asusctl. I looked for detailed instructions on how to use/adjust ryzenadj, and settled down for this setup with scripts and services.  

This repo is here for my personal convenience in case I want/need to nuke my current OS and reinstall it on another one. It has been created for my CachyOS install but should be pretty distro-agnostic (automatically with pacman, dnf, apt-get, or zypper, manually for whatever you want). However, I did not create the install files before now, it is therefore untested. It should also work for other laptops with a Ryzen CPU.  

As it was written for my personal use, the contents are in French, but should be understandable anyway.


> [!IMPORTANT]
>***Full disclosure: written with Gemini.***
>I am, to say the least, not a fan of the use of generative AI in general (for a lot of ethical, philosophical, environmental reasons). However, I believe it is a tool that can be beneficial to a lot of us, especially without the code knowledge, so I am trying to use it as responsibly as possible until the bubble explodes -let it be soon.
> The install process and instructions could probably be easier/lighter. I would like to simplify the installation process/scripts as much as possible, so if you have better ideas on how to implement the changes, I'd love to hear them!

> [!CAUTION]
>Note that this was developed for my own usage and is provided as is, with my limited knowledge and the help of Generative AI, and should you decide to use it, you do so at your own risk. Tinkering with power plans and your hardware current limits can result in hardware damage and even fire hazard.  

  
---

## Prerequisites

Because modern kernels restrict user-space access to physical hardware registers (`CONFIG_IO_STRICT_DEVMEM`), `ryzenadj` requires direct access to physical memory via `/dev/mem`.

Add **`iomem=relaxed`** to your kernel boot parameters:

* **Limine (`/boot/limine.conf` or `/boot/limine/limine.conf`):** Append `iomem=relaxed` to the `cmdline:` parameter of your boot entry.
* **systemd-boot (`/boot/loader/entries/*.conf`):** Append `iomem=relaxed` to the `options` line.
* **GRUB (`/etc/default/grub`):** Append `iomem=relaxed` inside `GRUB_CMDLINE_LINUX_DEFAULT`, then regenerate your configuration (`sudo grub-mkconfig -o /boot/grub/grub.cfg` or `sudo update-grub`).

*Reboot your system once before running the installer so the memory relaxation takes effect.*

---

## Features

* **Automated Profile Switching**: Listens to D-Bus events from `power-profiles-daemon` to switch power presets whenever profiles are changed via **ROG Control Center**, desktop environment sliders, or hardware keys (`Fn + F5`).
* **Granular Power Ceilings**: Tunes STAPM, Fast/Slow PPT, TDC, and EDC limits alongside thermal throttling ceilings to eliminate micro-boost temperature spikes.
* **Suspend & Resume Persistence**: Restores custom power and current limits upon waking from suspend via `ryzenadj-resume.service`.
* **Universal Distro Support**: Automated installer compatible with Arch Linux, Fedora, Debian/Ubuntu, and openSUSE.

---

## Installation

### Automatic
#### 1. Clone the Repository
```bash
git clone https://github.com/pacuus/ryzen-power.git
cd ryzen-power
```

#### 2. Run the Installer
```bash
chmod +x install.sh
./install.sh
```

##### What does `install.sh` do exactly?
1. Detects your distribution's package manager (pacman, dnf, apt, or zypper). 
2. Disables conflicting power daemons such as TLP if active.
3. Installs build toolchains (cmake, base-devel / build-essential), pciutils, git, and system communication libraries.
4. Installs the Asus ecosystem (asusctl, rog-control-center, supergfxctl) where natively available.
5. Compiles and deploys the latest ryzenadj binary to /usr/local/bin/.
6. Deploys runtime management scripts (ryzen-profiles.sh, ryzenadj-auto.sh) to /usr/local/bin/.
7. Configures passwordless sudoers rules for ryzen-profiles.sh.
8. Registers, reloads, and enables the systemd services (ryzenadj-auto.service and ryzenadj-resume.service).

### Manual Installation

If you prefer not to use `install.sh`, you can manually install the dependencies, build `ryzenadj`, deploy the scripts, and register the systemd services step by step.  


#### 1. Install System Dependencies

Before deploying the scripts, install the following components according to your distribution's documentation:

* **Hardware Tuning**: Install `ryzenadj` (either pre-built via your package manager/AUR, or compiled from source using `git`, `cmake`, `make`, `gcc`, and `pciutils`).
* **Power Management**: Install `power-profiles-daemon` and `dbus` tools.
* **Asus Hardware Stack**: Install `asusctl`, `rog-control-center`, and `supergfxctl` (if available for your distribution).> **Note:** Ensure you have added `iomem=relaxed` to your kernel boot parameters and rebooted beforehand so `ryzenadj` can access `/dev/mem`.  

#### 2. Deploy the Scripts
Copy to /usr/local/bin the scripts and mark them as executable.  

#### 3. Configure Sudoers Rule
To allow ryzen-profiles.sh to execute ryzenadj without prompting for a sudo password:
```Bash
echo "%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/ryzen-profiles.sh" | sudo tee /etc/sudoers.d/ryzen-profiles > /dev/null
echo "%sudo ALL=(ALL) NOPASSWD: /usr/local/bin/ryzen-profiles.sh" | sudo tee -a /etc/sudoers.d/ryzen-profiles > /dev/null
sudo chmod 0440 /etc/sudoers.d/ryzen-profiles
```

#### 4. Deploy and enable Systemd Services
```Bash
# 1. Copy service units
sudo cp services/ryzenadj-auto.service /etc/systemd/system/
sudo cp services/ryzenadj-resume.service /etc/systemd/system/

# 2. Reload systemd
sudo systemctl daemon-reload

# 3. Enable core daemons (if not already active)
sudo systemctl enable --now asusd.service 2>/dev/null || true
sudo systemctl enable --now supergfxd.service 2>/dev/null || true
sudo systemctl enable --now power-profiles-daemon.service

# 4. Enable RyzenAdj background automation and resume hooks
sudo systemctl enable --now ryzenadj-auto.service
sudo systemctl enable ryzenadj-resume.service
```

## Values Configuration
### Benchmarking Default Values with RyzenAdj
`ryzenadj` registers operate in volatile memory and reset to BIOS defaults on every reboot. Asus firmware applies distinct baseline power targets depending on the active fan/performance profile (Quiet, Balanced, Performance).
To record your laptop's stock power envelopes before customizing values:

1. Stop the background daemon to prevent active scripts from enforcing custom limits:
```bash
sudo systemctl stop ryzenadj-auto.service
```

2. Switch to your desired OEM profile
You can use ROG Control Center or asusctl (e.g., asusctl profile -M Quiet, Balanced, or Performance).

3. Reboot your system so the BIOS initializes its stock hardware envelopes.

4. Query the controller registers directly:
```bash
sudo ryzenadj -i 2>/dev/null
```

5. Key parameters to inspect in the output table:
* **Power Limits (mW):**
     * `STAPM LIMIT`: Sustained continuous power ceiling in mW (e.g., 30000 = 30W).
     * `PPT LIMIT FAST`: Peak short-term burst power ceiling in mW (e.g., 45000 = 45W).
     * `PPT LIMIT SLOW`: Intermediate boost power ceiling in mW (e.g., 35000 = 35W).
* **Time Windows (Seconds):**
     * `STAPM TIME`: Moving average duration window for sustained power in seconds.
     * `SLOW TIME`: Duration window allowed for intermediate burst power in seconds.
* **CPU Core Current Limits (mA):**
     * `VRM CURRENT (TDC VDD)`: Sustained thermal design current for CPU cores in mA (e.g., 20000 = 20A).
     * `VRM MAXIMUM CURRENT (EDC VDD)`: Peak burst current for CPU cores in mA (limiting this suppresses micro-boost spikes).
* **SoC / Uncore Current Limits (mA):**
     * `VRM SOC CURRENT (TDC SOC)`: Sustained current limit for the memory controller and iGPU in mA.
     * `VRM MAXIMUM SOC CURRENT (EDC SOC)`: Peak burst current limit for the memory controller and iGPU in mA.
* **Thermal Ceilings (°C):**
     * `THM LIMIT TEMP`: Temperature target where hardware begins thermal throttling.
6. Log these reference metrics for each profile, and use them to guide your custom configurations inside the ryzen-profiles.sh.
```bash
sudo nano /usr/local/bin/ryzen-profiles.sh
```

## Usage
### 1. Automated Mode (Default)
No manual interaction is required during normal use: you can switch to Silent/Balanced/Turbo through **ROG Control Center** or **Fn+F5** or your Desktop environment power profiles sliders.  
### 2. Manual CLI
You have two options:
* an interactive selection menu
```bash
sudo ryzen-profiles.sh
```
* Direct profile selection
```bash
sudo ryzen-profiles.sh silencieux
sudo ryzen-profiles.sh equilibre
sudo ryzen-profiles.sh turbo
```

*(Where "silencieux" is quiet, "equilibre" is balanced, and "turbo" is, well, turbo)*

### 3. Monitoring and Diagnostic
* **View real-time profile switching logs:**
```bash
journalctl -u ryzenadj-auto.service -f
```
* **Monitor active hardware registers in real time:**
```bash
watch -n 1 "sudo ryzenadj -i 2>/dev/null | grep -E 'STAPM LIMIT|PPT LIMIT FAST|VRM MAX|Tctl'"
```

### 4. Background Service Management
```bash
# Temporarily pause automatic profile management:
sudo systemctl stop ryzenadj-auto.service

# Disable daemon from launching on boot:
sudo systemctl disable ryzenadj-auto.service

# Re-enable and start:
sudo systemctl enable --now ryzenadj-auto.service
```

