# Git Account Manager (GAM)

> Gestiona múltiples cuentas de GitHub con SSH desde la terminal, sin configuración manual.

GAM es una herramienta CLI en bash puro que automatiza la configuración de SSH keys, perfiles Git y autocompletado para trabajar con varias cuentas de GitHub (personal, trabajo, clientes) en la misma máquina.

## ¿Por qué GAM?

Trabajar con múltiples cuentas de GitHub normalmente implica editar manualmente `~/.ssh/config`, generar claves SSH, configurar `~/.gitconfig` y recordar qué clave usar en cada proyecto. GAM automatiza todo ese proceso con un solo comando.

**Lo que hace por ti:**

- Genera y registra claves SSH Ed25519 por cuenta
- Configura `~/.ssh/config` para enrutar cada cuenta por su clave correspondiente
- Crea perfiles Git individuales (`~/.gitconfig-{cuenta}`)
- Aplica el perfil correcto automáticamente según la carpeta de trabajo (usando `includeIf`)
- Hace backup de tu configuración antes de cualquier cambio

## Requisitos

- Ubuntu 24.04 o superior
- Git
- SSH (`openssh-client`)

## Instalación

```bash
git clone https://github.com/lacasoft/git-account-manager.git
cd git-account-manager
./install.sh
```

El instalador copia `gam` a `/usr/local/bin/` y crea el directorio `~/.gam/`. Para activar el autocompletado:

```bash
echo 'source ~/.gam/completions/gam-completion.bash' >> ~/.bashrc
source ~/.bashrc
```

## Desinstalación

````bash
cd git-account-manager
./uninstall.sh


## Uso rápido

```bash
# Agregar una cuenta nueva (guiado paso a paso)
gam add

# O con flags para no-interactivo
gam add --name "Juan García" --email juan@personal.com --username juangarcia

# Ver todas las cuentas configuradas
gam list

# Probar que la conexión SSH funciona
gam test personal

# Clonar un repositorio usando una cuenta específica
gam clone personal lacasoft/evvaApi

# Configurar Git automático para una carpeta y todas sus subcarpetas
gam use ~/code/trabajo
````

## Comandos

| Comando  | Sintaxis                                      | Descripción                             |
| -------- | --------------------------------------------- | --------------------------------------- |
| `add`    | `gam add [--name X --email X --username X]`   | Agrega nueva cuenta de GitHub           |
| `list`   | `gam list`                                    | Lista todas las cuentas configuradas    |
| `remove` | `gam remove <cuenta>`                         | Elimina una cuenta y sus claves SSH     |
| `test`   | `gam test [cuenta]`                           | Prueba conexión SSH a GitHub            |
| `clone`  | `gam clone <cuenta> <usuario/repo> [destino]` | Clona repositorio con cuenta específica |
| `switch` | `gam switch <cuenta>`                         | Cambia la configuración Git global      |
| `use`    | `gam use <carpeta>`                           | Configura Git automático por carpeta    |
| `export` | `gam export`                                  | Exporta configuración para backup       |
| `import` | `gam import`                                  | Restaura configuración desde backup     |

## Cómo funciona

GAM usa el mecanismo de SSH hosts personalizados para separar las cuentas:

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

Y la directiva `includeIf` de Git para aplicar el perfil correcto por carpeta:

```ini
# ~/.gitconfig
[includeIf "gitdir:~/code/personal/"]
    path = ~/.gitconfig-personal

[includeIf "gitdir:~/code/trabajo/"]
    path = ~/.gitconfig-trabajo
```

Así, cada repositorio usa automáticamente el nombre, email y clave SSH correctos sin ninguna configuración adicional.

## Flujo al agregar una cuenta

1. GAM solicita nombre, email y username de GitHub
2. Genera una clave SSH Ed25519 en `~/.ssh/id_ed25519_{cuenta}`
3. Agrega la clave al agente SSH (`ssh-add`)
4. Añade el bloque `Host` a `~/.ssh/config`
5. Muestra la clave pública para que la pegues en GitHub → _Settings > SSH Keys_
6. Verifica la conexión con `ssh -T github.com-{cuenta}`
7. Opcionalmente configura Git automático para una carpeta

## Archivos generados

```
~/.ssh/id_ed25519_{cuenta}       # clave privada SSH
~/.ssh/id_ed25519_{cuenta}.pub   # clave pública SSH
~/.ssh/config                    # entrada Host por cada cuenta
~/.gitconfig-{cuenta}            # perfil Git de la cuenta
~/.gitconfig                     # includeIf por carpeta
~/.gam/                          # directorio de configuración GAM
```

## Subir a GitHub

```bash
git init
git add .
git commit -m "feat: Git Account Manager CLI tool

- Añade comandos para gestionar múltiples cuentas de GitHub
- Configuración automática de SSH
- Autocompletado para bash
- Export/import de configuraciones"

git remote add origin git@github.com-personal:lacasoft/git-account-manager.git
git branch -M main
git push -u origin main
```

## Licencia

MIT © [lacasoft](https://github.com/lacasoft)
