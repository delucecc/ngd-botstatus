# ngd-botstatus

The official **FiveM connector for [NemesisBot](https://nemesisbot.dev)**.

Links your FiveM server to your NemesisBot **Game Servers** dashboard:

- **Live status** — shows your server's player count, name, and uptime on your NemesisBot status panel.
- **Discord whitelist** *(optional)* — only lets whitelisted players connect, with a custom denial message.

## Install

1. Download the latest release and drop the `ngd-botstatus` folder into your server's `resources/`.
2. In the NemesisBot dashboard → **Game Servers**, create a panel and copy its **token**.
3. Add to your `server.cfg`:

   ```cfg
   set ngd_botstatus_token "your-token-from-the-dashboard"
   set ngd_botstatus_whitelist 1   # optional — turn on the Discord whitelist

   ensure ngd-botstatus
   ```

That's it — the token is the only thing you need.

## Customising

Player-facing text (the denial cards, your Discord invite, etc.) lives in **`config.lua`** — edit it to match your community.

## Links

- Setup & dashboard: **[nemesisbot.dev](https://nemesisbot.dev)**
- Docs: **[nemesisdocs.com](https://nemesisdocs.com/docs/nemesisbot-overview/)**
