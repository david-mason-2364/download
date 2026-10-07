<cfscript>

	// Define variables
	param name = "form.address" default = "";
	param name = "form.action" default = "list";
	results = [];
	errorMessage = "";

	// Load asset functions
	assetFinder = new assets();

	// Form submitted
	if (cgi.request_method eq "POST") {

		// Prepare address (https:// is added when no protocol is given)
		form.address = trim(form.address);
		if (len(form.address) and ! reFindNoCase("^[a-z][a-z0-9+.-]*://", form.address)) form.address = "https://" & form.address;

		// Download the page's html (the final address after any redirects is used to resolve relative links)
		if (! len(form.address)) {
			errorMessage = "Please enter a page address.";
		} else {
			page = fetchUrl(form.address, application.maxPageSize);
			if (page.ok) {
				form.address = page.url;
				results = assetFinder.getAssets(charsetEncode(page.bytes, "utf-8"), form.address);
				if (! arrayLen(results)) errorMessage = "No stylesheets, scripts, images or fonts were found on that page. Pages that build their content with JavaScript may not list their files in the html.";
			} else {
				errorMessage = "The page could not be downloaded:  #page.error#";
			}
		}

		// Download assets into a work folder in the temp directory (outside the web root), zip the folder and send the zip to the browser, then delete both
		if (form.action eq "zip" and arrayLen(results)) {

			// Allow time for the downloads
			cfsetting(requestTimeout = 150);

			// Remove work folders and zip files left behind by requests that never finished
			for (tmp in directoryList(application.folders.temp, false, "path", "download_*")) {
				try {
					if (dateDiff("h", getFileInfo(tmp).lastModified, now()) ge 1) {
						if (directoryExists(tmp)) directoryDelete(tmp, true); else fileDelete(tmp);
					}
				} catch (Any e) { }
			}

			// Define variables
			startTime = getTickCount();
			totalSize = 0;
			usedNames = {};
			report = [ "Assets found: #arrayLen(results)#", "" ];
			workFolder = "#application.folders.temp#/download_#createUuid()#";
			zipFile = "#workFolder#.zip";

			try {

				// Create work folder
				directoryCreate(workFolder);

				// Loop through and download assets
				for (i = 1; i le arrayLen(results); i++) {

					// Stop at the limits
					if (i gt application.maxAssets) { arrayAppend(report, "SKIPPED (limit of #application.maxAssets# files reached)  #results[i]#"); continue; }
					if ((getTickCount() - startTime) gt 90000) { arrayAppend(report, "SKIPPED (time limit reached)  #results[i]#"); continue; }

					// Download file
					download = fetchUrl(results[i], application.maxAssetSize);
					if (! download.ok) { arrayAppend(report, "FAILED (#download.error#)  #results[i]#"); continue; }
					if (totalSize + arrayLen(download.bytes) gt application.maxTotalSize) { arrayAppend(report, "SKIPPED (#numberFormat(application.maxTotalSize / 1048576)# MB total limit reached)  #results[i]#"); continue; }
					totalSize = totalSize + arrayLen(download.bytes);

					// Determine a safe, unique file name inside its folder (css, js, images or fonts)
					filename = reReplace(listLast(listFirst(listFirst(results[i], "##"), "?"), "/"), "[^A-Za-z0-9._-]", "_", "all");
					filename = assetFinder.getAssetFolder(results[i]) & "/" & filename;
					n = 1;
					while (structKeyExists(usedNames, filename)) {
						n++;
						filename = reReplace(filename, "^(.*?)(-[0-9]+)?(\.[^./]*)$", "\1-#n#\3");
					}
					usedNames[filename] = true;

					// Save file in the work folder
					if (! directoryExists("#workFolder#/#listFirst(filename, "/")#")) directoryCreate("#workFolder#/#listFirst(filename, "/")#");
					fileWrite("#workFolder#/#filename#", download.bytes);
					arrayAppend(report, "OK  #filename#  #results[i]#");

				}

				// Save report in the work folder
				fileWrite("#workFolder#/download-report.txt", arrayToList(report, chr(13) & chr(10)), "utf-8");

				// Zip the work folder
				cfzip(action = "zip", source = workFolder, file = zipFile, recurse = true, overwrite = true);
				directoryDelete(workFolder, true);

				// Send zip to browser (deleteFile removes the zip once it has been sent)
				cfheader(name = "Content-Disposition", value = "attachment; filename=""assets.zip""");
				cfcontent(type = "application/zip", file = zipFile, deleteFile = true, reset = true);
				cfabort();

			} catch (Any e) {

				// Clean up and show the error
				try { if (directoryExists(workFolder)) directoryDelete(workFolder, true); } catch (Any e2) { }
				try { if (fileExists(zipFile)) fileDelete(zipFile); } catch (Any e2) { }
				errorMessage = "The ZIP file could not be created: #e.message#";

			}

		}

	}

</cfscript>

<cfoutput>

	<h1>Download Assets</h1>

	<p>
		This project is a utility designed to analyze a webpage and automatically identify the external resources required to
		render it. The tool processes the HTML and locates linked assets such as stylesheets, JavaScript files, images, and
		fonts. Once identified, these assets can be downloaded and stored locally, allowing developers to collect the supporting
		files associated with a webpage. This can be useful for development, testing, archiving, or analysis purposes, such as
		reviewing how a page is structured, examining dependencies, or creating a local copy of the assets needed for troubleshooting
		or experimentation. By automating the discovery and retrieval of linked resources, the project simplifies a process that
		would otherwise require manually locating and downloading each asset individually.
	</p>

	<p><br /></p>

	<form method="post" action="index.cfm">

		<div class="mb-3">
			<input type="text" name="address" id="address" value="#encodeForHtml(form.address)#" class="form-control" placeholder="Page address, for example https://www.example.com" />
		</div>

		<button type="submit" name="action" value="list" class="btn btn-primary">Find Assets</button>
		<button type="submit" name="action" value="zip" class="btn btn-primary">Download ZIP</button>
		<a href="index.cfm" class="btn btn-primary">Reset</a>

	</form>

	<cfif len(errorMessage)>
		<p><br /></p>
		<div class="alert alert-warning">#encodeForHtml(errorMessage)#</div>
	</cfif>

	<cfif arrayLen(results) gt 0>
		<h2>Assets (#arrayLen(results)#)</h2>
		<cfif arrayLen(results) gt application.maxAssets>
			<p>Only the first #application.maxAssets# are included in the ZIP file.</p>
		</cfif>
		<cfloop index="r" array="#results#">
			<a href="#encodeForHtmlAttribute(r)#" target="_blank" rel="noopener noreferrer">#encodeForHtml(r)#</a><br />
		</cfloop>
	</cfif>

</cfoutput>
