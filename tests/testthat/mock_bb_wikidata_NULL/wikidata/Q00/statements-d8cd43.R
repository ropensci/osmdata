structure (list (
    method = "GET", url = "wikidata/Q00/statements?property=P402",
    status_code = 400L, headers = structure (list (
        date = "REDACTED",
        server = "REDACTED", `x-content-type-options` = "nosniff",
        `cache-control` = "no-cache", `content-language` = "en",
        `access-control-allow-origin` = "*", `content-type` = "application/json",
        `content-encoding` = "gzip", age = "0", vary = "x-restbase-compat, Accept-Encoding",
        `x-cache` = "cp6011 miss, cp6016 pass", `x-cache-status` = "pass",
        `server-timing` = "cache;desc=\"pass\", host;desc=\"cp6016\"",
        `strict-transport-security` = "max-age=106384710; includeSubDomains; preload",
        `report-to` = "{ \"group\": \"wm_nel\", \"max_age\": 604800, \"endpoints\": [{ \"url\": \"https://intake-logging.wikimedia.org/v1/events?stream=w3c.reportingapi.network_error&schema_uri=/w3c/reportingapi/network_error/1.0.0\" }] }",
        nel = "{ \"report_to\": \"wm_nel\", \"max_age\": 604800, \"failure_fraction\": 0.05, \"success_fraction\": 0.0}",
        `set-cookie` = "REDACTED", `set-cookie` = "REDACTED",
        `x-client-ip` = "REDACTED", `set-cookie` = "REDACTED",
        `set-cookie` = "REDACTED", `set-cookie` = "REDACTED",
        `content-length` = "103"
    ), class = "httr2_headers"),
    body = charToRaw ("{\"code\":\"invalid-path-parameter\",\"message\":\"Invalid path parameter: 'item_id'\",\"context\":{\"parameter\":\"item_id\"}}"),
    timing = c (
        redirect = 0, namelookup = 0.125609, connect = 0.149963,
        pretransfer = 0.312298, starttransfer = 0.50936, total = 0.509581
    ), cache = new.env (parent = emptyenv ())
), class = "httr2_response")
