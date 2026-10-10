# Aurora Linux for 2018 27-inch iMac (iMac18,3)

Custom Universal Blue container image based on [`ghcr.io/ublue-os/aurora`](https://github.com/ublue-os/aurora) that bakes in the patched Cirrus Logic CS8409 audio driver from [`armin-haghi/imac-cs8409-linux-audio`](https://github.com/armin-haghi/imac-cs8409-linux-audio).

This restores working audio from the built-in stereo speakers on 2017/2018 27-inch iMacs (`iMac18,3`, subsystem `0x106b1000`) running modern Linux (kernels 6.17+ / 7.x).

---

## Why This Image Exists

- **Hardware**: The 2017/2018 27-inch iMac uses a Cirrus Logic CS8409 HDA bridge connected to Texas Instruments TAS5764M amplifiers for internal speakers.
- **Stock Linux Issue**: Mainline Linux detects the CS8409 and creates a PCM node, but lacks Apple's proprietary GPIO power and I2C initialization verbs to wake the internal amplifiers, leaving the speakers silent.
- **Modern Kernel API**: Linux 6.17+ refactored the ALSA codec driver model. The `armin-haghi` driver ports the fix to this modern API and includes BTF ABI layout verification.
- **Atomic Architecture**: Aurora Linux has a read-only `/usr` partition. Compiling out-of-tree drivers via traditional DKMS does not persist across atomic updates. In Universal Blue, drivers are compiled during container image build and deployed as an atomic OCI image.

---

## Quick Start: Publishing to GitHub

### 1. Initialize and Push to GitHub

From this repository on your local machine:

```bash
# Initialize git with master branch
git init -b master
git add .
git commit -m "Initial commit: Aurora custom image with iMac18,3 audio driver"

# Create a public repository under your GitHub account and push
gh repo create aurora-imac --public --source=. --remote=origin --push
```

### 2. Monitor GitHub Actions Build

The GitHub Actions workflow (`.github/workflows/build.yml`) will automatically trigger on the push to `master`.

You can view the build status in your terminal:
```bash
gh run watch
```
Or in your browser under the **Actions** tab of your repository.

Once completed, your custom bootable image will be available at:
```
ghcr.io/<your-github-username>/aurora-imac:latest
```

> **Note**: If your repository was created as private, ensure the published container package visibility is set to **Public** so your iMac can pull it without credentials:
> GitHub Profile -> Packages -> `aurora-imac` -> Package Settings -> Change visibility to Public.

---

## Deploying on Your iMac

Once the GitHub Actions build succeeds, open a terminal on your iMac running Aurora Linux:

### 1. Rebase to the Custom Image
```bash
sudo bootc switch ghcr.io/<your-github-username>/aurora-imac:latest
```

*(Alternatively, if using `rpm-ostree`: `sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/<your-github-username>/aurora-imac:latest`)*

### 2. Reboot into the New Deployment
```bash
sudo systemctl reboot
```

---

## Verifying Audio

After rebooting into the new image:

1. **Verify the Patched Module is Loaded**:
   ```bash
   modinfo -n snd-hda-codec-cs8409
   ```
   *The path should contain `/updates/snd-hda-codec-cs8409.ko.zst`.*

2. **Test Speaker Playback**:
   ```bash
   speaker-test -D default -c 2 -t wav
   ```
   *You should hear audible "Front Left", "Front Right" voice announcements from the built-in stereo speakers.*

3. **Adjust Volume**:
   Open KDE Audio Settings or `alsamixer`. Note that per Apple driver design, volume is controlled via the `PCM` slider.

---

## Safety and Rollback

Because Aurora Linux uses atomic bootc/ostree deployments, your original stock Aurora installation is safely preserved as a rollback entry in GRUB.

If you ever need to revert:
1. Reboot the iMac and select the previous deployment in the GRUB boot menu.
2. Once booted into the previous system, make it permanent:
   ```bash
   sudo bootc rollback
   ```
