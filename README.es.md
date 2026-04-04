<div align="center">

> 🇺🇸 [Read in English](README.md)

```
  ██████╗  █████╗ ███╗   ███╗
 ██╔════╝ ██╔══██╗████╗ ████║
 ██║  ███╗███████║██╔████╔██║
 ██║   ██║██╔══██║██║╚██╔╝██║
 ╚██████╔╝██║  ██║██║ ╚═╝ ██║
  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝
```

### 🔑 Git Account Manager

> Gestiona múltiples cuentas de GitHub con SSH desde la terminal — sin configuración manual, sin contraseñas, sin drama.

[![Version](https://img.shields.io/badge/version-1.0.0-6366f1?style=flat-square)](https://github.com/lacasoft/git-account-manager/releases)
[![License](https://img.shields.io/badge/license-MIT-22c55e?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Linux%20%7C%20macOS-supported-f97316?style=flat-square&logo=apple&logoColor=white)](https://github.com/lacasoft/git-account-manager)
[![Shell](https://img.shields.io/badge/bash-puro-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Dependencies](https://img.shields.io/badge/dependencias-ninguna-lightgrey?style=flat-square)](https://github.com/lacasoft/git-account-manager)

</div>

---

## 🤔 ¿Por qué GAM?

¿Tienes cuenta personal y de trabajo en GitHub en la misma máquina? Sin GAM, toca editar `~/.ssh/config` a mano, generar claves SSH, configurar `~/.gitconfig` y rezar para no hacer push al repo equivocado con la cuenta incorrecta.

**GAM lo resuelve con un comando:**

| Sin GAM 😩 | Con GAM 😎 |
|------------|-----------|
| Editar `~/.ssh/config` a mano | `gam add` |
| Recordar qué clave SSH usar | Automático por carpeta |
| Cambiar `user.email` antes de cada commit | `gam switch trabajo` |
| Clonar con URL SSH correcta | `gam clone trabajo empresa/repo` |
| Perder configuración al formatear | `gam export > backup.txt` |

---

## ✨ Demo

```
$ gam list
Cuentas de GitHub configuradas:
================================

📁 personal
   🔑 github.com-personal
   👤 Juan García <juan@personal.com>

📁 trabajo
   🔑 github.com-trabajo
   👤 Juan García <juan@empresa.com>

$ gam test trabajo
[INFO] Probando conexión para trabajo...
[✓] Conexión exitosa para trabajo

$ gam clone trabajo empresa/proyecto
[INFO] Clonando empresa/proyecto con cuenta trabajo...
[✓] Repositorio clonado exitosamente
```

---

## 📦 Requisitos

- 🐧 **Linux**: Ubuntu 20.04+, Debian 11+ (o cualquier distro con bash 4+)
- 🍎 **macOS**: 12 Monterey o superior
- 🔧 `git`
- 🔐 `openssh-client`

---

## 🚀 Instalación

**One-liner** (descarga e instala automáticamente):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lacasoft/git-account-manager/main/install.sh)
```

**Desde el repo** (si prefieres revisar el código antes):

```bash
git clone https://github.com/lacasoft/git-account-manager.git
cd git-account-manager
bash install.sh
```

Instala `gam` en `/usr/local/bin/`, despliega las librerías en `~/.gam/` y configura el autocompletado.

> **macOS**: GAM detecta el sistema automáticamente y configura `ssh-add --apple-use-keychain`, `UseKeychain` en SSH config, y usa `pbcopy` para copiar claves al portapapeles.

---

## ⚡ Uso rápido

```bash
gam add                          # ➕ Agregar cuenta (interactivo)
gam list                         # 📋 Ver todas las cuentas
gam test personal                # 🔌 Probar conexión SSH
gam clone personal lacasoft/repo # 📥 Clonar con cuenta específica
gam use ~/code/trabajo           # 📂 Git automático por carpeta
gam switch trabajo               # 🔄 Cambiar config Git global
gam export > backup.txt          # 💾 Exportar configuración
gam import backup.txt            # 📤 Restaurar configuración
```

---

## 📖 Comandos

| Comando | Sintaxis | Descripción |
|---------|----------|-------------|
| `add` | `gam add [--name X --email X --username X]` | ➕ Agrega nueva cuenta |
| `list` | `gam list` | 📋 Lista cuentas configuradas |
| `remove` | `gam remove <cuenta>` | 🗑️ Elimina cuenta y sus claves |
| `test` | `gam test [cuenta]` | 🔌 Prueba conexión SSH |
| `clone` | `gam clone <cuenta> <usuario/repo>` | 📥 Clona repo con cuenta específica |
| `switch` | `gam switch <cuenta>` | 🔄 Cambia config Git global |
| `use` | `gam use <carpeta>` | 📂 Git automático por carpeta |
| `export` | `gam export` | 💾 Exporta configuración |
| `import` | `gam import <archivo>` | 📤 Restaura configuración |

---

## 🧠 Cómo funciona

GAM usa **SSH hosts personalizados** para separar las cuentas:

```
# ~/.ssh/config generado por GAM
Host github.com-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal

Host github.com-trabajo
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_trabajo
```

Y la directiva **`includeIf`** de Git para aplicar el perfil correcto por carpeta:

```ini
# ~/.gitconfig
[includeIf "gitdir:~/code/personal/"]
    path = ~/.gitconfig-personal

[includeIf "gitdir:~/code/trabajo/"]
    path = ~/.gitconfig-trabajo
```

> 💡 Cada repositorio usa automáticamente el nombre, email y clave SSH correctos — sin configurar nada extra.

---

## 🔄 Flujo de `gam add`

```
gam add
  │
  ├─ 📝  Solicita nombre, email y username de GitHub
  ├─ 🔐  Genera clave SSH Ed25519 → ~/.ssh/id_ed25519_{cuenta}
  ├─ 🤝  Agrega la clave al agente SSH
  ├─ ⚙️  Añade bloque Host a ~/.ssh/config
  ├─ 📋  Muestra la clave pública → la pegas en GitHub Settings > SSH Keys
  ├─ ✅  Verifica la conexión con ssh -T github.com-{cuenta}
  └─ 📂  Configura Git automático por carpeta (opcional)
```

---

## 📁 Archivos generados

```
~/.ssh/id_ed25519_{cuenta}       # 🔑 Clave privada SSH
~/.ssh/id_ed25519_{cuenta}.pub   # 📋 Clave pública SSH
~/.ssh/config                    # ⚙️  Configuración SSH por cuenta
~/.gitconfig-{cuenta}            # 👤 Perfil Git de la cuenta
~/.gitconfig                     # 🗂️  includeIf por carpeta
~/.gam/                          # 📦 Librerías y templates de GAM
```

---

## 🗑️ Desinstalación

```bash
bash uninstall.sh
```

Pregunta si también quieres eliminar las claves SSH y configuraciones de Git generadas por GAM.

---

## 🤝 Contribuir

¿Quieres mejorar GAM? Lee [CONTRIBUTING.md](CONTRIBUTING.md) para instrucciones de desarrollo local, convenciones y cómo abrir un PR.

¿Encontraste un bug? Abre un [issue](https://github.com/lacasoft/git-account-manager/issues/new?template=bug_report.md).

---

## 📄 Licencia

MIT © [lacasoft](https://github.com/lacasoft) — úsalo, modifícalo, compártelo.
