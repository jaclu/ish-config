# ish-config

Dialog driven ish configuration

Once installed run it with `ish-config`

## Current Features

- Time Zone - Select Region and Location via dialogs
- sshd - Asks for what port to use, installs all dependencies, and
activates it as a service, so it will be started on every launch of iSH
- Console settings - Alternate method to adopt the console
- AOK kernel tweaks - This is only available on iSH-AOK
- Install Python - This is the single most commonly asked question on the Discord
forum, so I thought it makes sense to offer it as a one-click option.

## Simple Installation

This will install to /opt/ish-config and do softlinks to /usr/local/bin

```shell
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/jaclu/ish-config/main/INSTALL)"
```

If you get the error "curl: not found".
Do this: `sudo apk add curl` and try again.

## Test data

The test_data/dummy-ssh-host-keys.tgz should not be used beyond testing,
since they are shared here they offer NADA security.
The only purpose is to save tons of time during testing not having to wait
3-4 minutes for keys to be created on my old iPad 5th

### Contributing

Contributions are welcome, and they're appreciated.
Every little bit helps, and credit is always given.

The best way to send feedback is to file an issue at
[issues](https://github.com/jaclu/ish-config/issues)

#### License

[MIT](LICENSE)
