# org-protocol setup

`org-protocol` lets the browser send a URL, page title, and any selected text
directly to a running Emacs session, triggering the `b` capture template and
appending a tagged bookmark to `~/org/inbox.org`.

Two pieces of setup are required: a **system-level URI handler** and a
**browser bookmarklet**.

---

## 1. System-level URI handler

The browser sends an `org-protocol://` URI. The OS must know to route it to
`emacsclient`.

### Linux (XDG / freedesktop)

The desktop file is included in this repo. Install it with:

```sh
mise run install-xdg
```

Verify registration:

```sh
xdg-open "org-protocol://capture?template=b&url=https%3A%2F%2Fexample.com&title=Example"
```

A running Emacs (with `emacsclient` server started) should open the capture buffer.

> **Note:** Emacs must be running with a server. Add `(server-start)` to your
> config if not already present, or start Emacs with `emacs --daemon`.

### macOS

Run:

```sh
mise run install-macos
```

This builds a minimal `~/Applications/OrgProtocol.app` whose only job is to
forward `org-protocol://` URIs to `emacsclient`, then registers it with
LaunchServices. It uses `osacompile`, `plutil`, and `codesign`, all of which
ship with macOS — no Automator app and no Xcode.

Two details worth knowing, because both are easy to get wrong by hand:

- **AppleScript is required**, not a stylistic choice. macOS delivers URI
  activations as Apple Events rather than as command-line arguments, so a plain
  shell script inside a bundle never receives the URL.
- **The bundle must be re-signed.** `osacompile` ad-hoc signs the bundle, and
  editing `Info.plist` to add `CFBundleURLTypes` invalidates that signature.
  Without the `codesign --force --sign -` step, `codesign -v` reports
  `invalid Info.plist (plist or signature have been modified)`.

Verify registration:

```sh
codesign -v ~/Applications/OrgProtocol.app && echo "signature valid"
open "org-protocol://capture?template=b&url=https%3A%2F%2Fexample.com&title=Example"
```

Remove it with `mise run uninstall-macos`.

---

## 2. Browser bookmarklet

A bookmarklet is more reliable than any extension — it constructs the
`org-protocol://capture` URL directly with no intermediary, and cannot break
when extension APIs change.

Create a new bookmark in Chrome/Firefox with the following as the URL:

```javascript
javascript:location.href='org-protocol://capture?template=b&url='+encodeURIComponent(location.href)+'&title='+encodeURIComponent(document.title)+'&body='+encodeURIComponent(window.getSelection())
```

**Setup steps:**

1. Show the bookmarks bar (`Ctrl+Shift+B` in Chrome, `Cmd+Shift+B` on macOS).
2. Right-click the bookmarks bar → **Add page…** (Chrome) or **New Bookmark**
   (Firefox).
3. Set **Name** to something short, e.g. `Org Capture`.
4. Set **URL** to the `javascript:` snippet above.
5. Save.

**Usage:** Navigate to any page, optionally select text, then click the
bookmarklet. Emacs raises and opens the capture buffer pre-filled with the URL,
title, and any selected text, and prompts for tags.

> **Note on Chrome security:** Chrome blocks `javascript:` bookmarklets from
> running on `chrome://` and Chrome Web Store pages. They work on all normal
> websites.

For pages worth more than a bookmark, use template `N` instead of `b` in the
bookmarklet URL. That routes the capture into a denote note under
`~/org/notes/`, prompting for denote keywords and seeding the title from the
page title.

---

## 3. Verify end-to-end

1. Start Emacs: `emacs --daemon` (or ensure a server is running).
2. Navigate to any page in your browser.
3. Click the bookmarklet.
4. Emacs should raise and open an org-capture buffer pre-filled with the URL
   and page title in the `b` (bookmark) template, prompting for tags.
5. Enter tags, add any extra notes, then `C-c C-c` to save.

The entry lands in `~/org/inbox.org` as:

```org
* [[https://example.com][Example Domain]]              :bookmark:reading:
  :PROPERTIES:
  :CREATED: [2026-08-05 Wed 14:30]
  :END:
  any text selected in the browser
```

Tag completion covers every tag already present across `org-agenda-files`. The
`:bookmark:` tag is applied automatically; tags entered at the prompt are
appended to it.
