# jj.yazi

Show the status of Jujutsu (jj) file changes as linemode in the file list.

[demo_jj_yazi.webm](https://github.com/user-attachments/assets/866ce531-50fa-4ddc-8195-7bf00209166a)

## Requirements

- Yazi 26.8.15 or newer (tested with 26.9.1).
- Jujutsu 0.36.0 or newer on `PATH` (tested with 0.45.1).
- A local Jujutsu workspace. Remote and virtual filesystems are skipped.

## Installation

This plugin currently lives on the `yazi-jj-plugin` branch of
[LilDojd/plugins](https://github.com/LilDojd/plugins/tree/yazi-jj-plugin), not in
`yazi-rs/plugins`. Copy `jj.yazi` from that branch to
`~/.config/yazi/plugins/jj.yazi`.

## Setup

Add the following to your `~/.config/yazi/init.lua`:

```lua
require("jj"):setup()
```

And register it as fetchers in your `~/.config/yazi/yazi.toml`:

```toml
[[plugin.prepend_fetchers]]
group = "jj"
url   = "*"
run   = "jj"

[[plugin.prepend_fetchers]]
group = "jj"
url   = "*/"
run   = "jj"
```

## Advanced

> [!NOTE]  
> The following configuration must be put before `require("jj"):setup()`

You can customize the [Style](https://yazi-rs.github.io/docs/plugins/layout#style) of the status sign with:

- `th.jj.conflicted`
- `th.jj.renamed`
- `th.jj.modified`
- `th.jj.added`
- `th.jj.deleted`

For example:

```lua
-- ~/.config/yazi/init.lua
th.jj = th.jj or {}
th.jj.modified = ui.Style():fg("blue")
th.jj.deleted = ui.Style():fg("red"):bold()
```

You can also customize the text of the status sign with:

- `th.jj.conflicted_sign`
- `th.jj.renamed_sign`
- `th.jj.modified_sign`
- `th.jj.added_sign`
- `th.jj.deleted_sign`

For example:

```lua
-- ~/.config/yazi/init.lua
th.jj = th.jj or {}
th.jj.modified_sign = "M"
th.jj.deleted_sign = "D"
```

## License

This plugin is MIT-licensed. For more information check the [LICENSE](LICENSE) file.
