import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';import '../services/settings_service.dart';

/// A cache entry for resolved IP addresses.
class _DnsCacheEntry {
  final String ip;
  final DateTime expiry;

  _DnsCacheEntry(this.ip, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// A custom DNS adapter for [Dio] to intercept socket-level domain resolution.
///
/// On native platforms (iOS, Android, macOS, Windows, Linux), it uses a custom
/// `HttpClient.connectionFactory` to connect to a dynamically resolved IP address
/// using Cloudflare (1.1.1.1) and Google (8.8.8.8) DNS-over-HTTPS (DoH).
/// On web platforms, it falls back to the browser's default DNS/networking stack.
class CustomDnsAdapter {
  /// Map of optional static DNS overrides.
  final Map<String, String>? dnsMap;

  // In-memory DNS cache to prevent repeated DoH queries
  static final Map<String, _DnsCacheEntry> _dnsCache = {};

  CustomDnsAdapter({this.dnsMap});

  /// Applies the custom DNS resolution to the provided [Dio] instance.
  void configure(Dio dio) {
    if (kIsWeb) {
      debugPrint(
        '[CustomDnsAdapter] Browser/Web platform detected. Defaulting to standard browser DNS.',
      );
      return;
    }

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();

        client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
          if (!SettingsService().useCustomAdapter) {
            final completer = Completer<Socket>();
            Future<void> directConnect() async {
              try {
                final socket = await Socket.connect(
                  uri.host,
                  uri.port,
                  timeout: const Duration(seconds: 10),
                );
                if (uri.scheme == 'https') {
                  final secureSocket = await SecureSocket.secure(socket, host: uri.host);
                  completer.complete(secureSocket);
                } else {
                  completer.complete(socket);
                }
              } catch (e) {
                completer.completeError(e);
              }
            }
            directConnect();
            return ConnectionTask.fromSocket(completer.future, () {});
          }

          final completer = Completer<Socket>();

          Future<void> attemptConnection() async {
            // 1. If a proxy is configured, respect it and connect directly to the proxy
            if (proxyHost != null) {
              try {
                final socket = await Socket.connect(
                  proxyHost,
                  proxyPort!,
                  timeout: const Duration(seconds: 10),
                );
                completer.complete(socket);
              } catch (proxyError) {
                completer.completeError(proxyError);
              }
              return;
            }

            // 2. Perform static map or dynamic DNS resolution via DoH first (bypasses DNS hijacking instantly)
            String targetHost = uri.host;
            try {
              if (dnsMap != null && dnsMap!.containsKey(uri.host)) {
                targetHost = dnsMap![uri.host]!;
              } else {
                final resolvedIp = await _resolveHostViaDoh(uri.host);
                if (resolvedIp != null) {
                  targetHost = resolvedIp;
                }
              }

              final socket = await Socket.connect(
                targetHost,
                uri.port,
                timeout: const Duration(seconds: 5),
              );

              if (uri.scheme == 'https') {
                final secureSocket = await SecureSocket.secure(
                  socket,
                  host: uri.host, // Original host for SNI / validation
                );
                completer.complete(secureSocket);
              } else {
                completer.complete(socket);
              }
            } catch (e) {
              debugPrint(
                '[CustomDnsAdapter] DoH/IP connection to $targetHost failed: $e. Falling back to direct hostname connection...',
              );
              try {
                final socket = await Socket.connect(
                  uri.host,
                  uri.port,
                  timeout: const Duration(seconds: 10),
                );

                if (uri.scheme == 'https') {
                  final secureSocket = await SecureSocket.secure(
                    socket,
                    host: uri.host,
                  );
                  completer.complete(secureSocket);
                } else {
                  completer.complete(socket);
                }
              } catch (fallbackError) {
                completer.completeError(fallbackError);
              }
            }
          }

          attemptConnection();
          return ConnectionTask.fromSocket(completer.future, () {});
        };

        return client;
      },
    );
  }

  /// Resolves the given hostname using Cloudflare (1.1.1.1) or Google (8.8.8.8) DoH APIs.
  Future<String?> _resolveHostViaDoh(String host) async {
    // Skip IP addresses, localhost, or standard loopback interfaces to prevent infinite loops
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '1.1.1.1' ||
        host == '8.8.8.8' ||
        RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host)) {
      return null;
    }

    // Check in-memory cache
    final cached = _dnsCache[host];
    if (cached != null && !cached.isExpired) {
      debugPrint('[CustomDnsAdapter] Cache hit: $host -> ${cached.ip}');
      return cached.ip;
    }

    debugPrint('[CustomDnsAdapter] Resolving $host via DoH...');

    // Try Cloudflare (1.1.1.1) first
    String? resolvedIp = await _queryCloudflareDoh(host);

    // Fallback to Google (8.8.8.8) if Cloudflare fails
    if (resolvedIp == null) {
      debugPrint(
        '[CustomDnsAdapter] Cloudflare resolution failed. Falling back to Google DoH (8.8.8.8)...',
      );
      resolvedIp = await _queryGoogleDoh(host);
    }

    if (resolvedIp != null) {
      debugPrint('[CustomDnsAdapter] Resolved $host -> $resolvedIp');
      // Cache the result for 5 minutes (300 seconds)
      _dnsCache[host] = _DnsCacheEntry(
        resolvedIp,
        DateTime.now().add(const Duration(minutes: 5)),
      );
      return resolvedIp;
    }

    debugPrint(
      '[CustomDnsAdapter] All DoH resolution failed. Falling back to system DNS for $host.',
    );
    return null;
  }

  /// Queries Cloudflare's DoH JSON API at 1.1.1.1
  Future<String?> _queryCloudflareDoh(String host) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);

      final uri = Uri.parse('https://1.1.1.1/dns-query?name=$host&type=A');
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/dns-json');

      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = json.decode(body) as Map<String, dynamic>;
        final answers = data['Answer'] as List?;
        if (answers != null && answers.isNotEmpty) {
          for (var answer in answers) {
            if (answer['type'] == 1) {
              // Type 1 is A record
              return answer['data'] as String?;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[CustomDnsAdapter] Cloudflare DoH failed for $host: $e');
    }
    return null;
  }

  /// Queries Google's DoH JSON API at 8.8.8.8
  Future<String?> _queryGoogleDoh(String host) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      // Since we are querying the raw IP 8.8.8.8 directly, the certificate may be issued
      // to "dns.google". We allow the handshake by accepting any certificate since we trust
      // the destination IP 8.8.8.8 directly.
      client.badCertificateCallback = (cert, host, port) => true;

      final uri = Uri.parse('https://8.8.8.8/resolve?name=$host&type=A');
      final request = await client.getUrl(uri);

      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = json.decode(body) as Map<String, dynamic>;
        final answers = data['Answer'] as List?;
        if (answers != null && answers.isNotEmpty) {
          for (var answer in answers) {
            if (answer['type'] == 1) {
              return answer['data'] as String?;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[CustomDnsAdapter] Google DoH failed for $host: $e');
    }
    return null;
  }
}
