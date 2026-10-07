# Download Assets

A small ColdFusion site that takes a page's address, finds the stylesheets, scripts, images and fonts linked from its HTML, and downloads them for you as a ZIP file.

Live demo: https://www.trinthlo.com/sites/download

## What it does

- Enter a page's address, for example `https://www.example.com`. If you leave off `https://`, it's added for you. The server downloads the page's HTML and follows up to 3 redirects. Relative links like `/css/site.css` or `images/logo.png` are resolved against the final address.
- **Find Assets** lists every linked `.css`, `.js`, image (`.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.avif`, `.ico`) and font (`.woff`, `.woff2`, `.ttf`, `.otf`, `.eot`) file as a full URL. It looks in `href` and `src` attributes, CSS `url(...)` values in the page and any other absolute URLs in the HTML. It doesn't look inside the CSS files themselves, and pages that build their content with JavaScript may not list all of their files in the HTML.
- **Download ZIP** downloads those files on the server and sends them to your browser as `assets.zip`, sorted into `css/`, `js/`, `images/` and `fonts/` folders. Files with the same name are numbered (`logo.png`, `logo-2.png`). A `download-report.txt` inside the ZIP lists every file and whether it was downloaded, and if not, why.

Nothing is kept on the server. Each request downloads its files into its own work folder in ColdFusion's temp directory, outside the web root, so the files can never be opened or run as pages on your site. The folder is zipped, the work folder is deleted, and the ZIP is deleted once it has been sent. Work folders left behind by a request that didn't finish are deleted after an hour.

## Limits and safety

Because the server downloads the files, a public copy of this tool could be used to reach machines on the server's own network or to download large files. To prevent that:

- Only `http://` and `https://` URLs are downloaded.
- Local and private network addresses are refused. This covers `localhost`, `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `169.254.0.0/16` (including cloud metadata addresses), `100.64.0.0/10` and their IPv6 equivalents. Host names are resolved first, so a name that points to one of these addresses is refused too.
- Redirects are followed one at a time, up to 3, and each new address goes through the same checks.
- The page's HTML can be up to 2 MB. Each file can be up to 5 MB, a ZIP can hold up to 100 files and 25 MB in total, and downloading stops after 90 seconds. Files past a limit are listed in the report as skipped.
- Each download times out after 10 seconds connecting or 15 seconds waiting for data.

The limits are set in `onApplicationStart` in `Application.cfc` (`application.maxPageSize`, `application.maxAssets`, `application.maxAssetSize` and `application.maxTotalSize`). To download from your own machine or network, set `application.allowPrivateHosts = true`. Only do this on a copy that isn't reachable from the internet.

## Requirements

- Adobe ColdFusion 2023 (tested). Earlier versions that include Apache HttpClient 4 should also work. Downloads use the Apache HttpClient 4 library that ships with ColdFusion, because newer Java versions block ColdFusion from calling Java's built-in https connection class. Lucee also includes HttpClient 4, but this hasn't been tested on Lucee.
- HTTPS. The site redirects every http request to `application.urls.secure`.

## Setup

1. Put the folder in your web root, for example `https://localhost/download`.
2. In `Application.cfc`, inside `onApplicationStart`, change `application.urls.normal` and `application.urls.secure` to the address where the site will run (for example `https://localhost/download`). If you skip this step, the https redirect and the page's CSS, JavaScript and images still point to the Trinthlo demo site.
3. Open `index.cfm` in a browser. If you opened the site before changing the URLs, restart ColdFusion first so the new values are loaded.

## Project structure

```
Application.cfc   App settings and limits, SSL redirect, isPrivateHost() and fetchUrl()
assets.cfc        getAssets() finds asset links, getAssetFolder() picks the ZIP folder
index.cfm         The form, the asset list and building the ZIP file
layout.cfm        Page layout and footer
assets/           Bootstrap, jQuery, site CSS and images
```

## License

MIT, see [LICENSE](LICENSE). Files you download with this tool belong to their owners. Make sure you're allowed to copy them.
