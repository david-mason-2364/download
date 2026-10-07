component output = false {

	// Define application settings
	this.name = "download";
	this.applicationTimeout = createTimeSpan(1, 0, 0, 0);
	this.sessionManagement = true;
	this.sessionTimeout = createTimeSpan(0, 1, 0, 0);
	this.scriptProtect = "all";

	// onApplicationStart
	public void function onApplicationStart() output = false {

		// Define local variables
		var tmp = "";

		// Define base folder structure
		application.folders = {
			root = getApplicationRootPath(),
			temp = getTempDirectory()
		};

		// Define url variables
		application.urls = {
			normal = "https://www.trinthlo.com/sites/download",
			secure = "https://www.trinthlo.com/sites/download"
		};

		// Allow downloads from local or private network addresses (keep false on a public server so the site can't be used to reach internal systems)
		application.allowPrivateHosts = false;

		// Download limits (size of a page downloaded from its address, number of files, size of one file in bytes, size of all files in bytes)
		application.maxPageSize = 2 * 1024 * 1024;
		application.maxAssets = 100;
		application.maxAssetSize = 5 * 1024 * 1024;
		application.maxTotalSize = 25 * 1024 * 1024;

		// Make sure that all application.folders variables do not end with a "/" and all "\" characters are converted to "/"
		for (tmp in application.folders) {
			structUpdate(application.folders, tmp, replace(structFind(application.folders, tmp), "\", "/", "all"));
			if (right(structFind(application.folders, tmp), 1) eq "/") structUpdate(application.folders, tmp, left(structFind(application.folders, tmp), len(structFind(application.folders, tmp)) - 1));
		}

		// Make sure that all application.urls variables do not end with a "/"
		for (tmp in application.urls) {
			if (right(structFind(application.urls, tmp), 1) eq "/") structUpdate(application.urls, tmp, left(structFind(application.urls, tmp), len(structFind(application.urls, tmp)) - 1));
		}

	}

	// onRequestStart
	public void function onRequestStart() output = false {

		// Define local variables
		var tmp = "";

		// Reset application
		if (isDefined("url.reinit")) {
			tmp = application.urls.normal;
			applicationStop();
			location(tmp, false);
			cfabort();
		}

		// Load local config file
		try { include "config/#cgi.http_host#.cfc"; } catch (Any e) { }

		// Determine the host name used to serve the request
		request.urlBase = iif(cgi.https eq "on", "application.urls.secure", "application.urls.normal");
		request.sslBase = application.urls.secure;

		// Force ssl, keeping the requested page and query string
		if (cgi.https neq "on") {
			tmp = replaceNoCase(replace(getBaseTemplatePath(), "\", "/", "all"), application.folders.root, "");
			if (len(cgi.query_string)) tmp = tmp & "?" & cgi.query_string;
			location(application.urls.secure & tmp, false);
		}

	}

	// onRequest
	public void function onRequest(string targetPage = "") output = true {
		var tmp = "";
		getPageContext().getOut().clearBuffer();
		savecontent variable="request.pageContent" { include "#arguments.targetPage#"; }
		include "layout.cfm";
	}

	// getApplicationRootPath
	private string function getApplicationRootPath() output = false {
		var i = getMetaData(this);
		while (i.extends.name != "WEB-INF.cftags.component") i = getComponentMetaData(i.extends.name);
		return getDirectoryFromPath(i.path);
	}

	// isPrivateHost function (true when the host resolves to a loopback, private, link-local or other local network address)
	public boolean function isPrivateHost(string host = "") output = false {

		var addresses = [];
		var bytes = [];
		var i = 0;

		try {
			addresses = createObject("java", "java.net.InetAddress").getAllByName(arguments.host);
		} catch (Any e) {
			return false;
		}

		for (i = 1; i le arrayLen(addresses); i++) {
			if (addresses[i].isLoopbackAddress() or addresses[i].isSiteLocalAddress() or addresses[i].isLinkLocalAddress() or addresses[i].isAnyLocalAddress() or addresses[i].isMulticastAddress()) return true;
			bytes = addresses[i].getAddress();
			// 100.64.0.0/10 (carrier-grade NAT) and fc00::/7 (IPv6 unique local)
			if (arrayLen(bytes) eq 4 and bitAnd(bytes[1], 255) eq 100 and bitAnd(bytes[2], 192) eq 64) return true;
			if (arrayLen(bytes) eq 16 and bitAnd(bytes[1], 254) eq 252) return true;
		}

		return false;

	}

	// fetchUrl function (downloads a url into memory, stopping at maxBytes, and checks every redirect before following it; results.url is the final address after any redirects)
	// Note:  this uses the Apache HttpClient 4 library that ships with ColdFusion and Lucee, because newer Java versions block ColdFusion from calling Java's own https connection class
	public struct function fetchUrl(string address = "", numeric maxBytes = 5242880, numeric maxRedirects = 3) output = false {

		var results = { "ok" = false, "error" = "", "bytes" = "", "url" = "" };
		var current = arguments.address;
		var hop = 0;
		var urlObj = "";
		var config = "";
		var client = "";
		var response = "";
		var status = 0;
		var header = "";
		var entity = "";
		var stream = "";
		var output = "";
		var buffer = "";
		var count = 0;
		var total = 0;

		try {

			// Create http client (timeouts in milliseconds, and redirects are followed below, one at a time, so each new address is checked too)
			config = createObject("java", "org.apache.http.client.config.RequestConfig").custom().setConnectTimeout(javacast("int", 10000)).setConnectionRequestTimeout(javacast("int", 10000)).setSocketTimeout(javacast("int", 15000)).setRedirectsEnabled(false).build();
			client = createObject("java", "org.apache.http.impl.client.HttpClients").custom().setDefaultRequestConfig(config).disableRedirectHandling().setUserAgent("Mozilla/5.0 (compatible; asset downloader)").build();

			for (hop = 0; hop le arguments.maxRedirects; hop++) {

				// Only http and https, and no local or private network addresses unless allowed
				urlObj = createObject("java", "java.net.URL").init(current);
				if (! listFindNoCase("http,https", urlObj.getProtocol()) or ! len(urlObj.getHost())) { results.error = "Only http and https addresses are allowed."; return results; }
				if (! application.allowPrivateHosts and isPrivateHost(urlObj.getHost())) { results.error = "Local or private network addresses are not allowed."; return results; }

				// Send request
				response = client.execute(createObject("java", "org.apache.http.client.methods.HttpGet").init(current));
				status = response.getStatusLine().getStatusCode();

				// Redirect
				if (status ge 300 and status lt 400) {
					header = response.getFirstHeader("Location");
					response.close();
					if (isNull(header) or ! len(header.getValue())) { results.error = "Redirect without a location (HTTP #status#)."; return results; }
					current = createObject("java", "java.net.URL").init(urlObj, header.getValue()).toString();
					continue;
				}

				// Error
				entity = response.getEntity();
				if (status neq 200 or isNull(entity)) { response.close(); results.error = "HTTP #status#"; return results; }

				// Read the response, stopping if it gets bigger than maxBytes
				stream = entity.getContent();
				output = createObject("java", "java.io.ByteArrayOutputStream").init();
				buffer = createObject("java", "java.lang.reflect.Array").newInstance(createObject("java", "java.lang.Byte").TYPE, javacast("int", 65536));
				count = stream.read(buffer);
				while (count gt -1) {
					total = total + count;
					if (total gt arguments.maxBytes) { response.close(); results.error = "Larger than the " & numberFormat(arguments.maxBytes / 1048576, "0.0") & " MB limit."; return results; }
					output.write(buffer, javacast("int", 0), javacast("int", count));
					count = stream.read(buffer);
				}
				response.close();

				results.ok = true;
				results.bytes = output.toByteArray();
				results.url = current;
				return results;

			}

			results.error = "Too many redirects.";

		} catch (Any e) {
			results.error = "Could not be downloaded (#e.message#).";
		} finally {
			if (isObject(client)) client.close();
		}

		return results;

	}

}
