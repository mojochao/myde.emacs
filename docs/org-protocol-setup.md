# org-protocol setup

`org-protocol` lets the browser send a URL and page title directly to a running
Emacs session, triggering the `u` capture template and appending the bookmark to
`$myde-org-dir/bookmarks.org`.

Two pieces of setup are required: a **system-level URI handler** and a
**browser bookmarklet**.

---

## 1. System-level URI handler

The browser sends an `org-protocol://` URI. The OS must know to route it to
`emacsclient`.

### Linux (XDG / freedesktop)

The desktop file is included in this repo. Install it with:

```sh
make install-xdg
```

Verify registration:

```sh
xdg-open "org-protocol://capture?template=u&url=https%3A%2F%2Fexample.com&title=Example"
```

A running Emacs (with `emacsclient` server started) should open the capture buffer.

> **Note:** Emacs must be running with a server. Add `(server-start)` to your
> config if not already present, or start Emacs with `emacs --daemon`.

### macOS

Register the `org-protocol://` scheme via a minimal Automator app:

1. Open Automator → New Document → Application.
2. Add action: **Run Shell Script**, set shell to `/bin/bash`, content:
   ```sh
   /usr/local/bin/emacsclient "$@"
   ```
   (Use `/opt/homebrew/bin/emacsclient` on Apple Silicon.)
3. Save as `OrgProtocol.app` in `/Applications`.
4. Register the scheme by editing the app's `Info.plist` to add:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>org-protocol</string>
       </array>
     </dict>
   </array>
   ```
5. Run once to register:
   ```sh
   open -a "OrgProtocol" "org-protocol://test"
   ```

---

## 2. Browser bookmarklet

A bookmarklet is more reliable than any extension — it constructs the
`org-protocol://capture` URL directly with no intermediary.

Create a new bookmark in Chrome/Firefox with the following as the URL:

```javascript
javascript:location.href='org-protocol://capture?template=u&url='+encodeURIComponent(location.href)+'&title='+encodeURIComponent(document.title)+'&body='+encodeURIComponent(window.getSelection())
```

**Setup steps:**

1. Show the bookmarks bar (`Ctrl+Shift+B` in Chrome).
2. Right-click the bookmarks bar → **Add page…** (Chrome) or **New Bookmark**
   (Firefox).
3. Set **Name** to something short, e.g. `Org Capture`.
4. Set **URL** to the `javascript:` snippet above.
5. Save.

**Usage:** Navigate to any page, optionally select text, then click the
bookmarklet. Emacs raises and opens the capture buffer pre-filled with the URL,
title, and any selected text.

> **Note on Chrome security:** Chrome blocks `javascript:` bookmarklets from
> running on `chrome://` and Chrome Web Store pages. They work on all normal
> websites.

---

## 3. Verify end-to-end

1. Start Emacs: `emacs --daemon` (or ensure a server is running).
2. Navigate to any page in your browser.
3. Click the bookmarklet.
4. Emacs should raise and open an org-capture buffer pre-filled with the URL
   and page title in the `u` (bookmark) template.
5. Add any extra tags or notes, then `C-c C-c` to save.

The entry lands in `$myde-org-dir/bookmarks.org` as:

```org
* [[https://example.com][Example Domain]] :bookmark:
:PROPERTIES:
:CREATED: [2026-05-10 Sun 14:30]
:END:
```
