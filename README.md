<div align="center">

> 🇪🇸 [Leer en español](README.es.md)

```
  ██████╗  █████╗ ███╗   ███╗
 ██╔════╝ ██╔══██╗████╗ ████║
 ██║  ███╗███████║██╔████╔██║
 ██║   ██║██╔══██║██║╚██╔╝██║
 ╚██████╔╝██║  ██║██║ ╚═╝ ██║
  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝
```

### 🔑 Git Account Manager

> Manage multiple GitHub accounts with SSH from the terminal — no manual config, no passwords, no drama.

[![Version](https://img.shields.io/badge/version-1.0.0-6366f1?style=flat-square)](https://github.com/lacasoft/git-account-manager/releases)
[![License](https://img.shields.io/badge/license-MIT-22c55e?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Linux%20%7C%20macOS-supported-f97316?style=flat-square&logo=apple&logoColor=white)](https://github.com/lacasoft/git-account-manager)
[![Shell](https://img.shields.io/badge/pure%20bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Dependencies](https://img.shields.io/badge/dependencies-none-lightgrey?style=flat-square)](https://github.com/lacasoft/git-account-manager)

</div>

---

## 🤔 Why GAM?

Got a personal and a work GitHub account on the same machine? Without GAM you have to manually edit `~/.ssh/config`, generate SSH keys, set up `~/.gitconfig`, and pray you don't push to the wrong repo with the wrong account.

**GAM fixes that with a single command:**

| Without GAM 😩 | With GAM 😎 |
|----------------|------------|
| Manually edit `~/.ssh/config` | `gam add` |
| Remember which SSH key to use | Automatic per folder |
| Change `user.email` before every commit | `gam switch work` |
| Clone with the right SSH URL | `gam clone work company/repo` |
| Lose your config when you format | `gam export > backup.txt` |

---

## ✨ Demo

```
$ gam list
╔══════════════════════════════════════════╗
║   🔑  Cuentas de GitHub configuradas   ║
╚══════════════════════════════════════════╝

  📁 personal
  ├─ 🔑  github.com-personal
  └─ 👤  John Doe <john@personal.com>

  📁 work
  ├─ 🔑  github.com-work
  └─ 👤  John Doe <john@company.com>

  ──────────────────────────────────────────
  Total: 2 account(s)

$ gam test work
[INFO] Probando conexión para work...
[✓] Conexión exitosa para work

$ gam clone work company/project
[INFO] Clonando company/project con cuenta work...
[✓] Repositorio clonado exitosamente
```

---

## 📦 Requirements

- 🐧 **Linux**: Ubuntu 20.04+, Debian 11+ (or any distro with bash 4+)
- 🍎 **macOS**: 12 Monterey or later
- 🔧 `git`
- 🔐 `openssh-client`

---

## 🚀 Installation

**One-liner** (downloads and installs automatically):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lacasoft/git-account-manager/HEAD/install.sh)
```

**From the repo** (if you prefer to review the code first):

```bash
git clone https://github.com/lacasoft/git-account-manager.git
cd git-account-manager
bash install.sh
```

Installs `gam` to `/usr/local/bin/`, deploys libraries to `~/.gam/`, and sets up shell autocompletion.

### ⬆️ Updating

If GAM is already installed, no matter how you installed it:

```bash
gam upgrade
```

It compares your version with the latest published one and, if there's a newer one, downloads and reinstalls it. Your accounts, keys, and configuration are left untouched.

If you work from a clone of the repo, `update.sh` runs `git pull` on the current branch and reinstalls:

```bash
cd git-account-manager
bash update.sh
```

> Older versions don't have `gam upgrade`. The first time, update with the one-liner above or with `bash install.sh` from the repo. Re-running the installer always updates.

> **macOS**: GAM auto-detects your system and configures `ssh-add --apple-use-keychain`, `UseKeychain` in SSH config, and uses `pbcopy` to copy keys to the clipboard.

---

## ⚡ Quick start

```bash
gam add                          # ➕ Add account (interactive)
gam list                         # 📋 List all accounts
gam check                        # 🩺 Diagnose all accounts
gam update personal              # ✏️  Change email, username, folder or key
gam test personal                # 🔌 Test SSH connection
gam clone personal lacasoft/repo # 📥 Clone with specific account
gam use ~/code/work              # 📂 Auto-configure Git per folder
gam switch work                  # 🔄 Switch global Git config
gam export > backup.txt          # 💾 Export configuration
gam import backup.txt            # 📤 Restore configuration
gam upgrade                      # ⬆️  Update GAM to the latest version
```

---

## 📖 Commands

| Command | Syntax | Description |
|---------|--------|-------------|
| `add` | `gam add [--name X --email X --username X]` | ➕ Add new account |
| `list` | `gam list` | 📋 List configured accounts |
| `update` | `gam update <account> [--email X --username X --folder X --new-key]` | ✏️ Update an existing account |
| `check` | `gam check [account] [--fix]` | 🩺 Diagnose accounts and repair common problems |
| `remove` | `gam remove <account>` | 🗑️ Remove account and its keys |
| `test` | `gam test [account]` | 🔌 Test SSH connection |
| `clone` | `gam clone <account> <user/repo>` | 📥 Clone repo with specific account |
| `switch` | `gam switch <account>` | 🔄 Switch global Git config |
| `use` | `gam use <folder>` | 📂 Auto-configure Git per folder |
| `export` | `gam export` | 💾 Export configuration |
| `import` | `gam import <file>` | 📤 Restore configuration |
| `upgrade` | `gam upgrade` | ⬆️ Update GAM to the latest version |

---

## 🧠 How it works

GAM uses **custom SSH hosts** to separate accounts:

```
# ~/.ssh/config generated by GAM
Host github.com-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal

Host github.com-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
```

And Git's **`includeIf`** directive to apply the right profile per folder:

```ini
# ~/.gitconfig
[includeIf "gitdir:~/code/personal/"]
    path = ~/.gitconfig-personal

[includeIf "gitdir:~/code/work/"]
    path = ~/.gitconfig-work
```

> 💡 Each repository automatically uses the correct name, email, and SSH key — no extra configuration needed.

---

## 🔄 `gam add` flow

```
gam add
  │
  ├─ 📝  Prompts for account name, email, and GitHub username
  ├─ 🔐  Generates Ed25519 SSH key → ~/.ssh/id_ed25519_{account}
  ├─ 🤝  Adds the key to the SSH agent
  ├─ ⚙️  Appends Host block to ~/.ssh/config
  ├─ 📋  Shows public key → paste it in GitHub Settings > SSH Keys
  ├─ ✅  Verifies connection with ssh -T github.com-{account}
  └─ 📂  Configures automatic Git profile per folder (optional)
```

---

## 🩺 Something not working?

If `gam add` was left half-done (e.g. `Ctrl+C` before registering the key on GitHub) or an account stopped working:

```bash
gam check work                # what the account is missing and how to fix it
gam check --fix               # repairs the safe stuff: broken ~/.ssh/config, permissions, lost .pub
gam update work               # complete or change email, username, folder or key (interactive)
```

`gam check` inspects the `~/.ssh/config` block, the keys and their permissions, whether GitHub recognizes the key (and on which account), the `~/.gitconfig-{account}` profile, and the `includeIf` folders. If the key isn't on GitHub yet, it prints it along with the steps to register it.

`gam update` with no options prompts for each value (Enter keeps the current one). With options:

```bash
gam update work --email me@company.com        # also updates the key comment
gam update work --folder ~/code/company       # adds another folder to the profile
gam update work --new-key                     # new key (the old one is kept as .bak.*)
```

---

## 📁 Generated files

```
~/.ssh/id_ed25519_{account}       # 🔑 SSH private key
~/.ssh/id_ed25519_{account}.pub   # 📋 SSH public key
~/.ssh/config                     # ⚙️  SSH config per account
~/.gitconfig-{account}            # 👤 Git profile for the account
~/.gitconfig                      # 🗂️  includeIf entries per folder
~/.gam/                           # 📦 GAM libraries and templates
```

---

## 🗑️ Uninstall

```bash
bash uninstall.sh
```

Prompts whether to also remove SSH keys and Git configurations generated by GAM.

---

## 🤝 Contributing

Want to improve GAM? Read [CONTRIBUTING.md](CONTRIBUTING.md) for local development instructions, conventions, and how to open a PR.

Found a bug? Open an [issue](https://github.com/lacasoft/git-account-manager/issues/new?template=bug_report.md).

---

## 📄 License

MIT © [lacasoft](https://github.com/lacasoft) — use it, modify it, share it.
