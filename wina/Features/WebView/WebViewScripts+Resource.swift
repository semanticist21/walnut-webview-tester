//
//  WebViewScripts+Resource.swift
//  wina
//
//  Resource Timing API script for WebView.
//

import Foundation

extension WebViewScripts {
    /// Resource Timing hook script - observes all resource loading via PerformanceObserver
    static let resourceTimingHook = """
        (function() {
            if (window.__resourceTimingHooked) return;
            window.__resourceTimingHooked = true;

            // Process a single performance entry
            function processEntry(entry) {
                if (entry.entryType !== 'resource') return null;

                // Calculate detailed timings
                var dnsTime = entry.domainLookupEnd - entry.domainLookupStart;
                var tcpTime = entry.connectEnd - entry.connectStart;
                var tlsTime = entry.secureConnectionStart > 0 ?
                    (entry.connectEnd - entry.secureConnectionStart) : 0;
                var requestTime = entry.responseStart - entry.requestStart;
                var responseTime = entry.responseEnd - entry.responseStart;

                return {
                    name: entry.name,
                    initiatorType: entry.initiatorType || 'other',
                    startTime: entry.startTime,
                    duration: entry.duration,
                    transferSize: entry.transferSize || 0,
                    encodedBodySize: entry.encodedBodySize || 0,
                    decodedBodySize: entry.decodedBodySize || 0,
                    dnsTime: Math.max(0, dnsTime),
                    tcpTime: Math.max(0, tcpTime),
                    tlsTime: Math.max(0, tlsTime),
                    requestTime: Math.max(0, requestTime),
                    responseTime: Math.max(0, responseTime)
                };
            }

            // Send entries to Swift
            function sendEntries(entries) {
                var processed = [];
                for (var i = 0; i < entries.length; i++) {
                    var data = processEntry(entries[i]);
                    if (data) processed.push(data);
                }
                if (processed.length > 0) {
                    try {
                        window.webkit.messageHandlers.resourceTiming.postMessage({
                            action: 'entries',
                            entries: processed
                        });
                    } catch(e) {}
                }
            }

            // Set up PerformanceObserver for new entries
            try {
                var observer = new PerformanceObserver(function(list) {
                    sendEntries(list.getEntries());
                });
                observer.observe({ type: 'resource', buffered: true });
            } catch(e) {
                // Fallback: just get current entries
                var entries = performance.getEntriesByType('resource');
                sendEntries(entries);
            }
        })();
        """

    /// Script to fetch current resource entries (for manual refresh)
    static let fetchResourceEntries = """
        (function() {
            var entries = performance.getEntriesByType('resource');
            var processed = [];

            for (var i = 0; i < entries.length; i++) {
                var entry = entries[i];
                var dnsTime = entry.domainLookupEnd - entry.domainLookupStart;
                var tcpTime = entry.connectEnd - entry.connectStart;
                var tlsTime = entry.secureConnectionStart > 0 ?
                    (entry.connectEnd - entry.secureConnectionStart) : 0;
                var requestTime = entry.responseStart - entry.requestStart;
                var responseTime = entry.responseEnd - entry.responseStart;

                processed.push({
                    name: entry.name,
                    initiatorType: entry.initiatorType || 'other',
                    startTime: entry.startTime,
                    duration: entry.duration,
                    transferSize: entry.transferSize || 0,
                    encodedBodySize: entry.encodedBodySize || 0,
                    decodedBodySize: entry.decodedBodySize || 0,
                    dnsTime: Math.max(0, dnsTime),
                    tcpTime: Math.max(0, tcpTime),
                    tlsTime: Math.max(0, tlsTime),
                    requestTime: Math.max(0, requestTime),
                    responseTime: Math.max(0, responseTime)
                });
            }

            return JSON.stringify(processed);
        })();
        """
}
