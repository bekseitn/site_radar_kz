# Wappalyzer technology fingerprint data

This directory vendors the technology fingerprint database from
[enthec/webappanalyzer](https://github.com/enthec/webappanalyzer), a
community-maintained continuation of the original open-source
[Wappalyzer](https://github.com/wappalyzer/wappalyzer) project (which went
closed-source in August 2023).

- `categories.json` — category id → name mapping (e.g. "CMS", "Analytics").
- `technologies/*.json` — one file per starting letter, each mapping a
  technology name to its detection rules (headers, cookies, meta tags,
  script src patterns, HTML patterns, `implies`/`excludes` relationships,
  etc.). Loaded and interpreted by `Wappalyzer::Fingerprint`
  (`app/services/wappalyzer/fingerprint.rb`).

Snapshot taken from the `main` branch on 2026-08-31.

## License

**This data is licensed under the GNU General Public License v3.0** — see
[`LICENSE`](./LICENSE) in this directory — independently of the rest of
this repository, which is MIT-licensed (see the root [`LICENSE`](../../LICENSE)).
It is used here as-is, unmodified in substance (only re-serialized/parsed
at load time by our own MIT-licensed Ruby code, which is a separate work).

If you redistribute this project, keep this directory's GPLv3 license
intact and attached to it.
