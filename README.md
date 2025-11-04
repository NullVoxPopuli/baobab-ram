# baobab-ram


This is the monorepo that produces the `ram-usage-analyzer`.

_A lightweight alternative to the linux package, [smem][ubuntu-smem]_.

Demo: https://x.com/nullvoxpopuli/status/1571271542276775938

[ubuntu-smem]: https://manpages.ubuntu.com/manpages/trusty/man8/smem.8.html

A sunburst-style chart representing ram usage, inspired by Gnome's Disk Usage Analyzer (also shipped by default with Ubuntu).

-------------------

This tool is inspired by this [AskUbuntu Question][ask-ubuntu-inspiration].

[ask-ubuntu-inspiration]: https://askubuntu.com/questions/1428703/is-there-a-utility-like-baobab-but-for-memory-ram/1428705?noredirect=1#comment2488516_1428705



## Installation & Usage

**Requirements**

- Node 22.16+
- A web browser


With `npm`

```bash
npx ram-usage-analyzer
```

With `pnpm`
```bash
pnpx ram-usage-analyzer
```

An address will be printed which you can open your browser to for viewing the visualization.

To have a browser tab opened for you, run:
```bash
npx ram-usage-analyzer --open
# or pnpx
```

## Contributing

Just open a PR or Issue -- all are welcome <3
