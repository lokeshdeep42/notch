# Landing page

`index.html` is the whole site: one static file, no build step. Host it anywhere that serves static
files (Cloudflare Pages, Netlify, GitHub Pages).

## Waitlist → Google Sheets

Sign-ups are saved by a Google Apps Script web app attached to a Google Sheet.
Each sign-up becomes one row: Timestamp, Name, Email, Used before, Source, Referrer.
Signing up twice with the same email adds no second row.

1. Create a Google Sheet (e.g. "Sill waitlist").
2. In the sheet: **Extensions → Apps Script**. Replace the contents of `Code.gs` with
   [`google-apps-script/Code.gs`](google-apps-script/Code.gs) and save.
3. In the function dropdown pick **`setup`** and click **Run**. Approve the permission prompt
   (Google shows "unverified app" for your own scripts: **Advanced → Go to … (unsafe)**).
   This creates the `Waitlist` tab with its header row.
4. **Deploy → New deployment** → type **Web app**.
   - Execute as: **Me**
   - Who has access: **Anyone**
   Click **Deploy** and copy the **Web app URL** (ends in `/exec`).
5. Open that URL in a browser. You should see `{"ok":true,"service":"sill-waitlist"}`.
6. In `index.html`, set `const WAITLIST_ENDPOINT = "https://script.google.com/macros/s/…/exec";`
7. Open the page (served over http/https, not `file://`), sign up, and check the sheet for the row.

**Changing the script later:** use **Deploy → Manage deployments → ✏️ → Version: New version**.
Creating a *new deployment* gives you a new URL, and the page would keep posting to the old one.

**Attribution:** the Source column takes `?utm_source=` or `?ref=` from the page URL, so share
links like `https://yoursite/?ref=reddit` or `?utm_source=producthunt`.

**Spam:** a hidden form field catches most bots. Values that start with `=`, `+`, `-` or `@` are
stored as plain text so they can't run as spreadsheet formulas.
