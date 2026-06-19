# METTA OS — fork de kali-live

Distro derivada de Kali Linux con identidad propia **METTA OS**: estética Matrix, español latinoamericano por defecto, y branding completo sin referencias visibles a Kali.

## Build en GitHub Actions (recomendado)

El build oficial corre en **GitHub Actions** — no necesitas Kali ni Docker local.

### Automático

| Evento | Variante | Tests |
|--------|----------|-------|
| Push a `main` | `default` (Xfce + tools) | QEMU BIOS |
| Pull request | `xfce-light` (más rápido) | QEMU BIOS |
| Tag `v*` | `default` | QEMU + Release |

### Manual (workflow_dispatch)

1. Ve a **Actions → Build METTA OS → Run workflow**
2. Elige variante (`xfce-light` o `default`)
3. Al terminar, descarga el artefacto `metta-os-<variant>-amd64`

### Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

El workflow publica la ISO en GitHub Releases automáticamente.

### CI local (reproduce Actions)

```bash
chmod +x scripts/ci-build.sh
METTA_VARIANT=xfce-light ./scripts/ci-build.sh
```

## Build local (opcional)

- **Host Debian/Kali** o **Docker/Podman** (recomendado en Arch y otras distros no-Debian)
- ~50 GB espacio libre en disco
- 8 GB+ RAM
- Acceso a internet (descarga de paquetes desde mirrors Kali)

### Dependencias (host Debian/Kali)

```bash
sudo apt install git live-build cdebootstrap debootstrap curl \
  qemu-system-x86 ovmf python3-pillow imagemagick librsvg2-bin
```

Instalar también `kali-archive-keyring` y `live-build` parcheado de Kali (ver [documentación oficial](https://www.kali.org/blog/build-kali-with-live-build-on-debian-based-systems/)).

## Build rápido (local)

```bash
# Pipeline local con Docker
./build.sh

# Mismo pipeline que GitHub Actions
./scripts/ci-build.sh
```

### Variables de entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `METTA_USE_DOCKER` | `auto` | `1` fuerza Docker; `0` build nativo |
| `METTA_RUN_TESTS` | `1` | `0` omite tests QEMU |
| `METTA_TEST_TIMEOUT` | `120` | Segundos de test por modo boot |
| `METTA_DOCKER_IMAGE` | `metta-os-builder` | Nombre imagen Docker |

### Build manual (dentro del contenedor o en Kali)

```bash
./scripts/generate-assets.sh
./lb-build.sh --variant default --verbose
./test-iso.sh images/metta-os-1.0-amd64.iso
./scripts/verify-branding.sh '' images/metta-os-1.0-amd64.iso
sha256sum images/metta-os-1.0-amd64.iso > images/metta-os-1.0-amd64.iso.sha256
```

## Estructura del proyecto

```
assets/          Fuentes SVG y scripts de generación (logo, wallpaper)
docker/          Dockerfile para build en host no-Debian
kali-config/     Configuración live-build (hooks, includes, bootloaders)
scripts/         generate-assets.sh, verify-branding.sh
lb-build.sh      Wrapper live-build (fork de kali-live build.sh)
build.sh         Pipeline completo
test-iso.sh      Tests QEMU BIOS + UEFI
```

## Personalización

Todos los cambios van en `kali-config/common/`:

- `hooks/live/*.chroot` — scripts durante el build del chroot
- `includes.chroot/` — overlay del sistema live
- `includes.binary/` — overlay de la ISO
- `bootloaders/` — GRUB e isolinux

Regenerar assets visuales:

```bash
./scripts/generate-assets.sh
```

## Verificación de branding

```bash
# Sobre chroot post-build
./scripts/verify-branding.sh chroot/

# Sobre ISO montada
./scripts/verify-branding.sh '' images/metta-os-1.0-amd64.iso
```

## Tests QEMU

`test-iso.sh` ejecuta arranque en modo BIOS y UEFI (si OVMF está disponible), captura screenshots en `test-output/` y verifica ausencia de kernel panic.

En entornos sin KVM (CI), usa TCG automáticamente.

## Wallpaper animado (opcional)

La versión animada Matrix rain **no está activada por defecto** por consumo de CPU/GPU. El wallpaper estático (`metta-matrix-default.png`, 4K) garantiza rendimiento en cualquier hardware. Para habilitar animación en el futuro, ver documentación en `assets/wallpaper/`.

## Nota sobre la ISO de referencia

El archivo `kali-linux-*-installer-amd64.iso` en este directorio es una ISO **instaladora** de referencia, no el producto del build. METTA OS genera una **live ISO** vía live-build.

## Licencia

Basado en [kali-live](https://gitlab.com/kalilinux/build-scripts/kali-live) (GPL). Personalizaciones METTA OS: ver repositorio.
