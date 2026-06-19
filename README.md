# METTA OS — fork de kali-live

Distro derivada de Kali Linux con identidad propia **METTA OS** (v2.0.0): estética Matrix, español latinoamericano, ecosistema de apps Tauri y branding completo.

> **METTA OS 2.0:** ver [docs/METTA-2.0.md](docs/METTA-2.0.md) para arquitectura de apps, `.mettapp` y orden de build.

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

**Reutilizar ISO sin recompilar:** en Actions → *Run workflow* activa *skip_build* (o deja que el cache la restaure si no cambiaste `kali-config`/assets). Solo corre verify + QEMU (~5–10 min). La ISO del run fallido **no se guardó** en artefactos; tras el primer build exitoso queda en cache de GitHub.

### CI local (reproduce Actions)

```bash
chmod +x scripts/ci-build.sh
METTA_VARIANT=xfce-light ./scripts/ci-build.sh
```

## Build local en Arch (sin Docker para assets)

```bash
sudo ./scripts/setup-host-arch.sh   # una vez
./scripts/generate-assets.sh        # wallpaper, sonidos, Plymouth

# ISO completa (requiere Docker):
./scripts/ci-build.sh

# Solo assets + apps vía Docker (sin ISO):
./scripts/docker-run.sh ./scripts/generate-assets.sh
./scripts/docker-run.sh "cd apps && ./build-all.sh"
```

Si **no tienes Docker**, sube el código a GitHub — el workflow **Build METTA OS** genera la ISO en la nube.

## Build local (opcional)

- **Host Debian/Kali** o **Docker/Podman** (recomendado en Arch y otras distros no-Debian)
- ~50 GB espacio libre en disco
- 8 GB+ RAM
- Acceso a internet (descarga de paquetes desde mirrors Kali)

### Dependencias (host Debian/Kali)

```bash
sudo apt install git live-build cdebootstrap debootstrap curl \
  qemu-system-x86 ovmf python3-pillow python3-numpy imagemagick librsvg2-bin
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
| `METTA_SKIP_BUILD` | `0` | `1` reutiliza ISO en `images/` (no ejecuta lb-build) |
| `METTA_SKIP_ASSETS` | `0` | `1` omite `generate-assets.sh` |
| `METTA_SKIP_CHROOT_VERIFY` | `0` | `1` omite verify en `chroot/` (útil si solo tienes ISO) |

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
assets/          Fuente logo, SVG, process_logo.py, wallpaper
preview/         mockup.html + scripts preview Nivel 0/1
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

Regenerar logo y wallpaper (fuente: `assets/source/metta-logo-source.png`):

```bash
./scripts/generate-assets.sh
```

## Preview UI (sin compilar ISO)

| Nivel | Comando | Tiempo |
|-------|---------|--------|
| **0** Mockup HTML | `./preview/preview-html.sh` | instantáneo |
| **All** | `./preview/preview-all.sh` | lo que el host soporte |
| **1a** GRUB (tema) | `./preview/preview-grub.sh` | ~30s |
| **1a′** GRUB (boot ISO) | `./preview/preview-grub.sh --boot-iso` | requiere ISO |
| **1b** Plymouth | `sudo ./preview/preview-plymouth.sh` | ~10s |
| **1c** Escritorio Xfce | `./preview/preview-desktop.sh` | requiere chroot (fallback → mockup) |

### Dependencias preview (Arch Linux)

```bash
sudo pacman -S python-pillow imagemagick xorg-xephyr
# Opcional Nivel 1a (sin venv: --user; dentro de venv: sin --user):
pip install grub2-theme-preview
# o fuera del venv:
pip install --user grub2-theme-preview
# Opcional Nivel 1b:
sudo pacman -S plymouth && sudo ./preview/preview-plymouth.sh
```
| **2** Gate final | `./scripts/ci-build.sh` | 1–3h |

Ejecuta `generate-assets.sh` antes del preview para enlazar assets en `preview/assets/`.

**Importante:** `preview-grub.sh` (sin flags) solo previsualiza el **tema** del menú GRUB en QEMU. Al pulsar *Live system* verás un aviso en consola y volverás al menú — no hay kernel en esa imagen de prueba. Para arrancar METTA OS de verdad necesitas la ISO compilada:

```bash
./scripts/ci-build.sh
./test-iso.sh images/metta-os-1.0-amd64.iso
# o, si la ISO ya existe en el repo:
./preview/preview-grub.sh --boot-iso
```

## Verificación de branding

```bash
# Sobre chroot post-build
./scripts/verify-branding.sh chroot/

# Sobre ISO montada
./scripts/verify-branding.sh '' images/metta-os-1.0-amd64.iso
```

## Tests QEMU

`test-iso.sh` ejecuta un **smoke test** automático (~2–3 min): arranca QEMU, captura screenshots y **cierra solo** (no es para usar el escritorio).

Para probar la live **interactivamente** (ventana abierta hasta que la cierres):

```bash
chmod +x run-live.sh
./run-live.sh metta-os-default-amd64/metta-os-1.0-amd64.iso
# Login live: usuario metta, contraseña kali
```

En entornos sin KVM (CI), usa TCG automáticamente.

## Wallpaper animado (opcional)

El wallpaper estático usa matrix rain procedural con logo superpuesto (`metta-matrix-with-logo.png`). La versión sin logo (`metta-matrix-default.png`) queda disponible como alternativa.

## Nota sobre la ISO de referencia

El archivo `kali-linux-*-installer-amd64.iso` en este directorio es una ISO **instaladora** de referencia, no el producto del build. METTA OS genera una **live ISO** vía live-build.

## Licencia

Basado en [kali-live](https://gitlab.com/kalilinux/build-scripts/kali-live) (GPL). Personalizaciones METTA OS: ver repositorio.
