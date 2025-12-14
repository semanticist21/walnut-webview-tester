//
//  WebViewScripts.swift
//  wina
//
//  JavaScript injection scripts for WebView hooking.
//

import Foundation

// MARK: - WebView Injection Scripts

/// JavaScript scripts for WKWebView feature hooking
enum WebViewScripts {
    /// Console hook script - intercepts console methods and forwards to native
    static let consoleHook = """
        (function() {
            if (window.__consoleHooked) return;
            window.__consoleHooked = true;

            // Parse stack trace to get caller location
            function getCallerSource() {
                try {
                    const stack = new Error().stack;
                    if (!stack) return null;
                    const lines = stack.split('\\n');
                    // Skip: Error, our hook function, console.method wrapper
                    // Find the first line that's not our code
                    for (let i = 3; i < lines.length; i++) {
                        const line = lines[i];
                        if (!line) continue;
                        // Match patterns like "at func (url:line:col)" or "url:line:col"
                        const match = line.match(/(?:at\\s+)?(?:[^(]+\\s+\\()?([^)\\s]+):(\\d+)(?::\\d+)?\\)?/);
                        if (match) {
                            let url = match[1];
                            const lineNum = match[2];
                            // Simplify URL: extract filename or hostname+path
                            try {
                                const parsed = new URL(url);
                                const path = parsed.pathname;
                                url = path.split('/').pop() || parsed.hostname + path;
                            } catch(e) {
                                // Use as-is if not a valid URL
                                url = url.split('/').pop() || url;
                            }
                            return url + ':' + lineNum;
                        }
                    }
                } catch(e) {}
                return null;
            }

            // Helper to format arguments
            function formatArg(arg) {
                if (arg === null) return 'null';
                if (arg === undefined) return 'undefined';
                if (typeof arg === 'function') return '[Function: ' + (arg.name || 'anonymous') + ']';
                if (typeof arg === 'symbol') return arg.toString();
                if (typeof arg === 'bigint') return arg.toString() + 'n';
                if (arg instanceof Error) return arg.name + ': ' + arg.message + (arg.stack ? '\\n' + arg.stack : '');
                if (arg instanceof Element) return '<' + arg.tagName.toLowerCase() + (arg.id ? '#' + arg.id : '') + (arg.className ? '.' + arg.className.split(' ').join('.') : '') + '>';
                if (arg instanceof RegExp) return arg.toString();
                if (arg instanceof Date) return 'Date(' + arg.toISOString() + ')';
                if (arg instanceof Promise) return 'Promise {<pending>}';
                if (arg instanceof Map) return 'Map(' + arg.size + ') {' + Array.from(arg.entries()).map(function(e) { return e[0] + ' => ' + e[1]; }).join(', ') + '}';
                if (arg instanceof Set) return 'Set(' + arg.size + ') {' + Array.from(arg).join(', ') + '}';
                if (ArrayBuffer.isView(arg)) return arg.constructor.name + '(' + arg.length + ') [' + Array.from(arg.slice(0, 10)).join(', ') + (arg.length > 10 ? ', ...' : '') + ']';
                if (arg instanceof ArrayBuffer) return 'ArrayBuffer(' + arg.byteLength + ')';
                if (typeof arg === 'object') {
                    try {
                        const str = JSON.stringify(arg, null, 2);
                        return str === '{}' && Object.keys(arg).length === 0 ? '{}' : (str === '{}' ? '[object ' + (arg.constructor?.name || 'Object') + ']' : str);
                    }
                    catch(e) { return '[object ' + (arg.constructor?.name || 'Object') + ']'; }
                }
                return String(arg);
            }

            const methods = ['log', 'info', 'warn', 'error', 'debug'];
            methods.forEach(function(method) {
                const original = console[method];
                console[method] = function(...args) {
                    try {
                        const message = args.map(formatArg).join(' ');
                        const source = getCallerSource();
                        window.webkit.messageHandlers.consoleLog.postMessage({
                            type: method,
                            message: message,
                            source: source
                        });
                    } catch(e) {}
                    original.apply(console, args);
                };
            });

            // console.group
            const originalGroup = console.group;
            console.group = function(...args) {
                try {
                    const message = args.length > 0 ? args.map(formatArg).join(' ') : 'group';
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        type: 'group',
                        message: message,
                        source: getCallerSource()
                    });
                } catch(e) {}
                originalGroup.apply(console, args);
            };

            // console.groupCollapsed
            const originalGroupCollapsed = console.groupCollapsed;
            console.groupCollapsed = function(...args) {
                try {
                    const message = args.length > 0 ? args.map(formatArg).join(' ') : 'group';
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        type: 'groupCollapsed',
                        message: message,
                        source: getCallerSource()
                    });
                } catch(e) {}
                originalGroupCollapsed.apply(console, args);
            };

            // console.groupEnd
            const originalGroupEnd = console.groupEnd;
            console.groupEnd = function() {
                try {
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        type: 'groupEnd',
                        message: '',
                        source: null
                    });
                } catch(e) {}
                originalGroupEnd.apply(console);
            };

            // console.table
            const originalTable = console.table;
            console.table = function(data, columns) {
                try {
                    let tableData = [];
                    if (Array.isArray(data)) {
                        tableData = data.map(function(item, index) {
                            if (typeof item === 'object' && item !== null) {
                                const row = { '(index)': String(index) };
                                const keys = columns || Object.keys(item);
                                keys.forEach(function(key) {
                                    row[key] = formatArg(item[key]);
                                });
                                return row;
                            }
                            return { '(index)': String(index), 'Value': formatArg(item) };
                        });
                    } else if (typeof data === 'object' && data !== null) {
                        Object.keys(data).forEach(function(key) {
                            const item = data[key];
                            if (typeof item === 'object' && item !== null) {
                                const row = { '(index)': key };
                                const keys = columns || Object.keys(item);
                                keys.forEach(function(k) {
                                    row[k] = formatArg(item[k]);
                                });
                                tableData.push(row);
                            } else {
                                tableData.push({ '(index)': key, 'Value': formatArg(item) });
                            }
                        });
                    }
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        type: 'table',
                        message: JSON.stringify(tableData),
                        source: getCallerSource()
                    });
                } catch(e) {}
                originalTable.apply(console, arguments);
            };

            // Capture uncaught errors
            window.addEventListener('error', function(e) {
                let source = null;
                if (e.filename) {
                    try {
                        const parsed = new URL(e.filename);
                        const path = parsed.pathname;
                        source = (path.split('/').pop() || parsed.hostname + path) + ':' + e.lineno;
                    } catch(err) {
                        source = e.filename + ':' + e.lineno;
                    }
                }
                window.webkit.messageHandlers.consoleLog.postMessage({
                    type: 'error',
                    message: 'Uncaught: ' + e.message,
                    source: source
                });
            });

            // Capture unhandled promise rejections
            window.addEventListener('unhandledrejection', function(e) {
                window.webkit.messageHandlers.consoleLog.postMessage({
                    type: 'error',
                    message: 'Unhandled Promise: ' + String(e.reason),
                    source: null
                });
            });
        })();
        """

    /// Performance observer script - sets up tracking for LCP and CLS
    /// Note: INP removed - Safari/WKWebView doesn't support Event Timing API (until 2026)
    static let performanceObserver = """
        (function() {
            if (window.__webVitals_initialized) return;
            window.__webVitals_initialized = true;

            // LCP tracking (Largest Contentful Paint)
            window.__webVitals_lcp = -1;
            try {
                new PerformanceObserver((list) => {
                    const entries = list.getEntries();
                    if (entries.length > 0) {
                        window.__webVitals_lcp = entries[entries.length - 1].startTime;
                    }
                }).observe({ type: 'largest-contentful-paint', buffered: true });
            } catch (e) {}

            // CLS tracking (Cumulative Layout Shift)
            window.__webVitals_cls = 0;
            try {
                new PerformanceObserver((list) => {
                    for (const entry of list.getEntries()) {
                        if (!entry.hadRecentInput) {
                            window.__webVitals_cls += entry.value;
                        }
                    }
                }).observe({ type: 'layout-shift', buffered: true });
            } catch (e) {}
        })();
        """

    /// Network hooking script - intercepts fetch and XMLHttpRequest
    static let networkHook = """
        (function() {
            if (window.__networkHooked) return;
            window.__networkHooked = true;

            // Generate unique request ID
            function generateId() {
                return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                    var r = Math.random() * 16 | 0;
                    var v = c === 'x' ? r : (r & 0x3 | 0x8);
                    return v.toString(16);
                });
            }

            // Safely stringify headers
            function headersToObject(headers) {
                if (!headers) return null;
                var obj = {};
                if (headers.forEach) {
                    headers.forEach(function(value, key) {
                        obj[key] = value;
                    });
                } else if (typeof headers === 'object') {
                    for (var key in headers) {
                        if (headers.hasOwnProperty(key)) {
                            obj[key] = headers[key];
                        }
                    }
                }
                return Object.keys(obj).length > 0 ? obj : null;
            }

            // Truncate body for large payloads
            function truncateBody(body, maxLen) {
                maxLen = maxLen || 10000;
                if (!body) return null;
                if (typeof body !== 'string') {
                    try { body = JSON.stringify(body); } catch(e) { body = String(body); }
                }
                if (body.length > maxLen) {
                    return body.substring(0, maxLen) + '... (truncated)';
                }
                return body;
            }

            // Hook fetch
            var originalFetch = window.fetch;
            window.fetch = function(input, init) {
                var requestId = generateId();
                var url = typeof input === 'string' ? input : (input.url || String(input));
                var method = (init && init.method) || (input && input.method) || 'GET';
                var headers = (init && init.headers) || (input && input.headers) || null;
                var body = (init && init.body) || null;

                try {
                    window.webkit.messageHandlers.networkRequest.postMessage({
                        action: 'start',
                        id: requestId,
                        method: method,
                        url: url,
                        type: 'fetch',
                        headers: headersToObject(headers),
                        body: truncateBody(body)
                    });
                } catch(e) {}

                return originalFetch.apply(this, arguments)
                    .then(function(response) {
                        var responseHeaders = {};
                        response.headers.forEach(function(value, key) {
                            responseHeaders[key] = value;
                        });

                        // Clone response to read body
                        var cloned = response.clone();
                        cloned.text().then(function(text) {
                            try {
                                window.webkit.messageHandlers.networkRequest.postMessage({
                                    action: 'complete',
                                    id: requestId,
                                    status: response.status,
                                    statusText: response.statusText,
                                    headers: responseHeaders,
                                    body: truncateBody(text)
                                });
                            } catch(e) {}
                        }).catch(function() {
                            try {
                                window.webkit.messageHandlers.networkRequest.postMessage({
                                    action: 'complete',
                                    id: requestId,
                                    status: response.status,
                                    statusText: response.statusText,
                                    headers: responseHeaders,
                                    body: null
                                });
                            } catch(e) {}
                        });

                        return response;
                    })
                    .catch(function(error) {
                        try {
                            window.webkit.messageHandlers.networkRequest.postMessage({
                                action: 'error',
                                id: requestId,
                                error: error.message || String(error)
                            });
                        } catch(e) {}
                        throw error;
                    });
            };

            // Hook XMLHttpRequest
            var XHR = XMLHttpRequest;
            var originalOpen = XHR.prototype.open;
            var originalSend = XHR.prototype.send;
            var originalSetRequestHeader = XHR.prototype.setRequestHeader;

            XHR.prototype.open = function(method, url) {
                this.__networkRequestId = generateId();
                this.__networkMethod = method;
                this.__networkUrl = url;
                this.__networkHeaders = {};
                return originalOpen.apply(this, arguments);
            };

            XHR.prototype.setRequestHeader = function(name, value) {
                if (this.__networkHeaders) {
                    this.__networkHeaders[name] = value;
                }
                return originalSetRequestHeader.apply(this, arguments);
            };

            XHR.prototype.send = function(body) {
                var xhr = this;
                var requestId = xhr.__networkRequestId;

                try {
                    window.webkit.messageHandlers.networkRequest.postMessage({
                        action: 'start',
                        id: requestId,
                        method: xhr.__networkMethod || 'GET',
                        url: xhr.__networkUrl || '',
                        type: 'xhr',
                        headers: xhr.__networkHeaders,
                        body: truncateBody(body)
                    });
                } catch(e) {}

                xhr.addEventListener('load', function() {
                    var responseHeaders = {};
                    var headerString = xhr.getAllResponseHeaders();
                    if (headerString) {
                        headerString.split('\\r\\n').forEach(function(line) {
                            var parts = line.split(': ');
                            if (parts.length === 2) {
                                responseHeaders[parts[0]] = parts[1];
                            }
                        });
                    }

                    try {
                        window.webkit.messageHandlers.networkRequest.postMessage({
                            action: 'complete',
                            id: requestId,
                            status: xhr.status,
                            statusText: xhr.statusText,
                            headers: Object.keys(responseHeaders).length > 0 ? responseHeaders : null,
                            body: truncateBody(xhr.responseText)
                        });
                    } catch(e) {}
                });

                xhr.addEventListener('error', function() {
                    try {
                        window.webkit.messageHandlers.networkRequest.postMessage({
                            action: 'error',
                            id: requestId,
                            error: 'Network error'
                        });
                    } catch(e) {}
                });

                xhr.addEventListener('abort', function() {
                    try {
                        window.webkit.messageHandlers.networkRequest.postMessage({
                            action: 'error',
                            id: requestId,
                            error: 'Request aborted'
                        });
                    } catch(e) {}
                });

                xhr.addEventListener('timeout', function() {
                    try {
                        window.webkit.messageHandlers.networkRequest.postMessage({
                            action: 'error',
                            id: requestId,
                            error: 'Request timeout'
                        });
                    } catch(e) {}
                });

                return originalSend.apply(this, arguments);
            };
        })();
        """

    /// Emulation bootstrap script - reads config from window object and applies overrides
    /// Injected at document start, reads window.__winaEmulationConfig set by native code
    static let emulationBootstrap = """
        (function() {
            if (window.__winaEmulationApplied) return;

            // Config is set by native code before page load
            const config = window.__winaEmulationConfig || {};
            if (!config.colorScheme && !config.reducedMotion && !config.highContrast && !config.reducedTransparency) {
                return; // No emulation needed
            }

            window.__winaEmulationApplied = true;

            // Build matchMedia overrides
            const overrides = {};
            if (config.colorScheme && config.colorScheme !== 'system') {
                const scheme = config.colorScheme;
                const opposite = scheme === 'dark' ? 'light' : 'dark';
                overrides['(prefers-color-scheme: ' + scheme + ')'] = true;
                overrides['(prefers-color-scheme: ' + opposite + ')'] = false;
            }
            if (config.reducedMotion) {
                overrides['(prefers-reduced-motion: reduce)'] = true;
                overrides['(prefers-reduced-motion: no-preference)'] = false;
            }
            if (config.highContrast) {
                overrides['(prefers-contrast: more)'] = true;
                overrides['(prefers-contrast: no-preference)'] = false;
            }
            if (config.reducedTransparency) {
                overrides['(prefers-reduced-transparency: reduce)'] = true;
                overrides['(prefers-reduced-transparency: no-preference)'] = false;
            }

            // Override matchMedia for JS-based detection
            const originalMatchMedia = window.matchMedia.bind(window);
            window.matchMedia = function(query) {
                const result = originalMatchMedia(query);
                const normalizedQuery = query.replace(/\\s+/g, ' ').trim().toLowerCase();

                for (const [pattern, matches] of Object.entries(overrides)) {
                    const feature = pattern.slice(1, -1); // Remove outer parens
                    if (normalizedQuery.includes(feature)) {
                        return {
                            matches: matches,
                            media: query,
                            onchange: null,
                            addListener: function(cb) { result.addListener(cb); },
                            removeListener: function(cb) { result.removeListener(cb); },
                            addEventListener: function(type, cb) { result.addEventListener(type, cb); },
                            removeEventListener: function(type, cb) { result.removeEventListener(type, cb); },
                            dispatchEvent: function(e) { return result.dispatchEvent(e); }
                        };
                    }
                }
                return result;
            };

            // Build and inject CSS overrides
            let css = '';
            if (config.colorScheme && config.colorScheme !== 'system') {
                css += ':root { color-scheme: ' + config.colorScheme + '; }\\n';
            }
            if (config.reducedMotion) {
                css += '*, *::before, *::after { animation-duration: 0.001ms !important; animation-iteration-count: 1 !important; transition-duration: 0.001ms !important; scroll-behavior: auto !important; }\\n';
            }
            if (config.highContrast) {
                css += ':root { forced-color-adjust: auto; }\\n';
            }
            if (config.reducedTransparency) {
                css += '* { backdrop-filter: none !important; -webkit-backdrop-filter: none !important; }\\n';
            }

            if (css) {
                const style = document.createElement('style');
                style.id = 'wina-emulation-style';
                style.textContent = css;
                (document.head || document.documentElement).appendChild(style);
            }

            console.log('[Wina] Emulation active:', Object.keys(overrides).length / 2, 'overrides');
        })();
        """

    /// Script to set emulation config (call before page load or reload)
    static func emulationConfigScript(
        colorScheme: String,
        reducedMotion: Bool,
        highContrast: Bool,
        reducedTransparency: Bool
    ) -> String {
        return """
            window.__winaEmulationConfig = {
                colorScheme: '\(colorScheme)',
                reducedMotion: \(reducedMotion),
                highContrast: \(highContrast),
                reducedTransparency: \(reducedTransparency)
            };
            window.__winaEmulationApplied = false;
            """
    }
}
