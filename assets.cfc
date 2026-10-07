component output = false {

	// getAssets function (finds links to stylesheets, scripts, images and fonts in html or css, and returns them as full urls)
	public array function getAssets(string content = "", string baseUrl = "") output = false {

		// Define variables
		var extensions = "css,js,png,jpg,jpeg,gif,svg,webp,avif,ico,woff,woff2,ttf,otf,eot";
		var patterns = [ 'href\s*=\s*"([^"]*)"', "href\s*=\s*'([^']*)'", 'src\s*=\s*"([^"]*)"', "src\s*=\s*'([^']*)'", "url\(\s*[""']?([^""')]*)", "((?:https?:)?//[^\s""'<>()]+)" ];
		var base = "";
		var pattern = "";
		var matches = [];
		var match = "";
		var link = "";
		var path = "";
		var found = {};
		var results = [];

		// ----------------

		// Base url for relative links (optional)
		if (len(trim(arguments.baseUrl))) {
			try { base = createObject("java", "java.net.URL").init(trim(arguments.baseUrl)); } catch (Any e) { base = ""; }
		}

		// Find links
		for (pattern in patterns) {
			matches = reFindNoCase(pattern, arguments.content, 1, true, "all");
			for (match in matches) {

				// Skip empty matches
				if (arrayLen(match.match) lt 2 or ! len(trim(match.match[2]))) continue;

				// Clean up the link
				link = trim(match.match[2]);
				link = replaceNoCase(replaceNoCase(link, "&quot;", "", "all"), "&amp;", "&", "all");
				if (left(link, 2) eq "//") link = "https:" & link;

				// Make it a full url (relative links need a base url)
				try {
					if (reFindNoCase("^https?://", link)) link = createObject("java", "java.net.URL").init(link).toString();
					else if (isObject(base) and ! reFindNoCase("^[a-z][a-z0-9+.-]*:", link)) link = createObject("java", "java.net.URL").init(base, link).toString();
					else continue;
				} catch (Any e) {
					continue;
				}

				// Keep stylesheets, scripts, images and fonts only
				path = listFirst(listFirst(link, "##"), "?");
				if (listFindNoCase(extensions, listLast(listLast(path, "/"), ".")) eq 0 or find(".", listLast(path, "/")) eq 0) continue;

				// Remove duplicates
				if (! structKeyExists(found, link)) {
					found[link] = true;
					arrayAppend(results, link);
				}

			}
		}

		// ----------------

		// Sort
		arraySort(results, "textnocase");

		// Return results
		return results;

	}

	// getAssetFolder function (folder an asset goes in, based on its file extension)
	public string function getAssetFolder(string link = "") output = false {

		var extension = listLast(listLast(listFirst(listFirst(arguments.link, "##"), "?"), "/"), ".");

		if (listFindNoCase("css", extension)) return "css";
		if (listFindNoCase("js", extension)) return "js";
		if (listFindNoCase("woff,woff2,ttf,otf,eot", extension)) return "fonts";
		return "images";

	}

}
