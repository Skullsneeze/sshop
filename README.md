# 🐇 SSHop

A simple CLI tool to quickly SSH into (or hop to) configured client environments with interactive selection.

![connection example](assets/connect_example.gif "Connect to your servers with SSHop")

---

## ✨ Features

- Interactive selection, adding, and updating of clients and environments via `fzf` and `gum`
- Supports multiple environments per client (e.g., Staging, Production)
- Reads client/server data from an easy to maintain JSON config file
- Easily configurable and extensible
- Easy Homebrew installation for Mac users

---

## Installation

There are several ways to install SSHop.

### 🍎 Homebrew

You can install **sshop** via Homebrew from the custom tap:

```sh
brew tap skullsneeze/homebrew-tap https://github.com/Skullsneeze/homebrew-tools.git

```

And then:

```sh
brew install sshop
```

### 📦 Curl + install.sh

Alternativly you can use the provided install script:

```sh
curl -sSfL https://raw.githubusercontent.com/Skullsneeze/sshop/master/install.sh | bash
```

---

## 💡 Usage

Simply run:

```sh
sshop
```

This will prompt you to select a client and then an environment to SSH into.

```
Options:
  --add, -a             Add new client via interactive prompts
  --edit, -e            Edit existing client via fzf + interactive prompts
  --delete, -d          Delete existing client via fzf + interactive prompts
  --config, -c <file>   Use a specific clients.json config file
  --help, -h            Show this help message
```

---

### ⚙️ Configuration

By default, `sshop` reads the configuration file from:

```
~/.sshop/clients.json
```

You can override this by setting the `JUMP_CONFIG` environment variable or using the `--config` option:

```sh
sshop --config /path/to/your/clients.json
```

---

### 📋 Clients

Clients are managed in a json file using the following structure:

```json
{
  "clients": [
    {
      "name": "Example Client",
      "servers": [
        {
          "name": "Production",
          "host": "prod.example.com",
          "port": 22,
          "username": "ubuntu"
        }
      ]
    },
    {
      "name": "Another Client",
      "servers": [
        {
          "name": "Test",
          "host": "test.sample.com",
          "port": 1234,
          "username": "test_sample"
        },
        {
          "name": "Production",
          "host": "sample.com",
          "port": 2222,
          "username": "root"
        }
      ]
    }
  ]
}
```

---

## 🛠️ Requirements

- `fzf` (for interactive selection)
- `jq` (for processing json clients/server list)
- `gum` (for nice looking inputs)

_Note that both Homebrew and install.sh will try to install these requirement for you._


---

## 🔭 Example Usage

**Add servers to SSHop interactively:**

![add example](assets/add_example.gif "Add servers to SSHop interactively")

**Edit servers in SSHop interactively:**

![edit example](assets/edit_example.gif "Edit servers in SSHop interactively")

**Remove servers from SSHop interactively:**

![delete example](assets/delete_example.gif "Remove servers from SSHop interactively")