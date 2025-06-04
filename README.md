# SSHop

A simple CLI tool to quickly SSH into configured client environments with interactive selection.

---

## Features

- Interactive selection of clients and environments via `fzf` or `dialog`
- Supports multiple environments (e.g., Staging, Production)
- Reads client/server data from a YAML config file
- Easily configurable and extensible
- Homebrew installation for Mac users

---

## Installation

There are several ways to install SSHop.

### Homebrew

You can install **sshop** via Homebrew from the custom tap:

```sh
brew tap skullsneeze/homebrew-tap https://github.com/Skullsneeze/homebrew-tap.git

```

And then:

```sh
brew install skullsneeze/tap/sshop
```

### Curl

Coming soon.

---

## Usage

Simply run:

```sh
sshop
```

This will prompt you to select a client and then an environment to SSH into.

---

### Configuration

By default, `sshop` reads the configuration file from:

```
~/.sshop/clients.yaml
```

You can override this by setting the `JUMP_CONFIG` environment variable or using the `--config` option:

```sh
sshop --config /path/to/your/clients.yaml
```

---

### Clients

Clients are managed in a yaml file using the following structure:

```yaml
# Root level element is clients.
clients:
    # A client is always defined by its name.
  - name: My first client
    # A client will contain 1 or more servers
    servers:
        # Each server is identified by a name
      - name: Staging
        # Defines the host to connect to
        host: my-ssh-server.com
        # Defines which username should be used to connect to the host
        username: staging-ssh-user
        # Optional: Defines the port that should be used (defaults to 22)
        port: 2222
      - name: Production
        host: my-ssh-server.com
        username: production-ssh-user
        port: 2222
  - name: Some other client
    servers:
      - name: Testing
        host: some-server.com
        username: my-user
```

---

### Options

```
Usage: sshop [options]

Options:
--config, -c <file>   Use a specific clients.yaml config file
--dialog, -d          Force using dialog instead of fzf
--help, -h            Show this help message
```

---

## Requirements

- `fzf` or `dialog` installed (for interactive selection)
- `yq` (for processing yaml clients list)
