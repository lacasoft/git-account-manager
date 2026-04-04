# Contribuir a GAM

Gracias por tu interés en contribuir a Git Account Manager. Aquí te explicamos cómo hacerlo.

## Desarrollo local

```bash
# 1. Fork y clona el repo
git clone git@github.com:TU_USUARIO/git-account-manager.git
cd git-account-manager

# 2. Ejecuta directamente sin instalar (modo dev)
bash gam help
bash gam list

# 3. Si quieres probar instalado
bash install.sh
```

En modo dev, GAM detecta automáticamente que está corriendo desde el repo y usa `./lib/` en vez de `~/.gam/lib/`.

## Estructura del proyecto

```
gam                          # Entry point — router de comandos
lib/
├── utils.sh                 # Logging, confirmaciones, detección de OS, helpers
├── ssh.sh                   # Generación de claves SSH, configuración, test
├── account.sh               # add, list, remove, test, clone, export, import
└── git-config.sh            # Perfiles Git, switch, includeIf por carpeta
templates/
├── ssh-config.template      # Template para ~/.ssh/config
└── gitconfig.template       # Template para ~/.gitconfig-{cuenta}
completions/
└── gam-completion.bash      # Autocompletado bash
install.sh                   # Instalador (local y remoto)
uninstall.sh                 # Desinstalador
update.sh                    # Actualizador
```

## Convenciones

- **Bash puro** — sin dependencias externas (no python, no jq, no curl en runtime)
- **UI en español** — mensajes, prompts y confirmaciones
- **Confirmaciones**: `s/n` (sí/no)
- **Portabilidad**: todo cambio debe funcionar en Linux (Ubuntu/Debian) y macOS
  - Usar `sed_inplace` en vez de `sed -i` directamente
  - Probar diferencias de `ssh-add` y clipboard entre sistemas
- **SSH host**: `github.com-{cuenta}` — permite múltiples cuentas en `~/.ssh/config`
- **SSH keys**: Ed25519 en `~/.ssh/id_ed25519_{cuenta}`

## Cómo hacer un PR

1. Crea un branch desde `main`: `git checkout -b mi-feature`
2. Verifica que no rompe la sintaxis: `bash -n gam lib/*.sh install.sh uninstall.sh`
3. Prueba manualmente los comandos afectados
4. Haz commit con mensaje descriptivo
5. Abre un PR describiendo qué cambia y por qué

## Reportar bugs

Usa la [plantilla de bug report](https://github.com/lacasoft/git-account-manager/issues/new?template=bug_report.md) e incluye:

- Sistema operativo y versión
- Versión de bash (`bash --version`)
- Comando exacto que ejecutaste
- Output completo del error

## Ideas y features

Abre un [feature request](https://github.com/lacasoft/git-account-manager/issues/new?template=feature_request.md) con tu propuesta. Si ya tienes un plan de implementación, mejor todavía.
