/// Proxy Service
/// 
/// Manages proxy servers for bypassing geo-restrictions
/// Uses ProxyScrape free API for proxy lists

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProxyServer {
  final String host;
  final int port;
  final String protocol; // HTTP, HTTPS, SOCKS4, SOCKS5
  final String? country;
  final bool isWorking;
  
  ProxyServer({
    required this.host,
    required this.port,
    required this.protocol,
    this.country,
    this.isWorking = true,
  });
  
  String get address => '$host:$port';
  String get fullAddress => '$protocol://$host:$port';
  
  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'protocol': protocol,
    'country': country,
    'isWorking': isWorking,
  };
  
  factory ProxyServer.fromJson(Map<String, dynamic> json) => ProxyServer(
    host: json['host'] as String,
    port: json['port'] as int,
    protocol: json['protocol'] as String? ?? 'HTTP',
    country: json['country'] as String?,
    isWorking: json['isWorking'] as bool? ?? true,
  );
}

class ProxyService {
  static final ProxyService _instance = ProxyService._internal();
  factory ProxyService() => _instance;
  ProxyService._internal();
  
  List<ProxyServer> _proxyList = [];
  int _currentProxyIndex = 0;
  DateTime? _lastFetch;
  
  static const String _cacheKey = 'cached_proxies';
  static const String _apiUrl = 'https://api.proxyscrape.com/v2/';
  
  /// Get current active proxy
  ProxyServer? get currentProxy {
    if (_proxyList.isEmpty) return null;
    return _proxyList[_currentProxyIndex];
  }
  
  /// Check if we have available proxies
  bool get hasProxies => _proxyList.isNotEmpty;
  
  /// Initialize proxy service and load cached proxies
  Future<void> initialize() async {
    await _loadCachedProxies();
    if (_proxyList.isEmpty || _shouldRefreshProxies()) {
      await fetchProxies();
    }
  }
  
  /// Fetch fresh proxy list from ProxyScrape API
  Future<List<ProxyServer>> fetchProxies() async {
    try {
      // Fetch HTTP/HTTPS proxies (most compatible)
      final httpProxies = await _fetchProxiesFromApi('http');
      final httpsProxies = await _fetchProxiesFromApi('https');
      
      // Combine and deduplicate
      final allProxies = <ProxyServer>[...httpProxies, ...httpsProxies];
      final uniqueProxies = <String, ProxyServer>{};
      
      for (final proxy in allProxies) {
        uniqueProxies[proxy.address] = proxy;
      }
      
      _proxyList = uniqueProxies.values.toList();
      _currentProxyIndex = 0;
      _lastFetch = DateTime.now();
      
      // Cache the proxies
      await _cacheProxies();
      
      return _proxyList;
    } catch (e) {
      // If fetch fails, try to use cached proxies
      await _loadCachedProxies();
      return _proxyList;
    }
  }
  
  /// Fetch proxies from ProxyScrape API for specific protocol
  Future<List<ProxyServer>> _fetchProxiesFromApi(String protocol) async {
    try {
      final url = Uri.parse(
        '$_apiUrl?request=displayproxies&protocol=$protocol&timeout=5000&country=all&ssl=all&anonymity=all&format=json'
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final proxies = <ProxyServer>[];
        
        // ProxyScrape returns array of proxy data
        if (data is List) {
          for (final item in data) {
            try {
              proxies.add(ProxyServer(
                host: item['ip'] as String? ?? item['host'] as String,
                port: int.parse(item['port'].toString()),
                protocol: protocol.toUpperCase(),
                country: item['country'] as String?,
              ));
            } catch (e) {
              // Skip invalid proxy entries
              continue;
            }
          }
        }
        
        return proxies;
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// Rotate to next proxy in the list
  void rotateProxy() {
    if (_proxyList.isEmpty) return;
    
    _currentProxyIndex = (_currentProxyIndex + 1) % _proxyList.length;
  }
  
  /// Mark current proxy as failed and rotate
  void markCurrentProxyFailed() {
    if (_proxyList.isEmpty) return;
    
    _proxyList[_currentProxyIndex] = ProxyServer(
      host: _proxyList[_currentProxyIndex].host,
      port: _proxyList[_currentProxyIndex].port,
      protocol: _proxyList[_currentProxyIndex].protocol,
      country: _proxyList[_currentProxyIndex].country,
      isWorking: false,
    );
    
    rotateProxy();
  }
  
  /// Get a random working proxy
  ProxyServer? getRandomProxy() {
    final workingProxies = _proxyList.where((p) => p.isWorking).toList();
    if (workingProxies.isEmpty) return null;
    
    workingProxies.shuffle();
    return workingProxies.first;
  }
  
  /// Load cached proxies from SharedPreferences
  Future<void> _loadCachedProxies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      
      if (cachedJson != null) {
        final List<dynamic> jsonList = jsonDecode(cachedJson);
        _proxyList = jsonList.map((json) => ProxyServer.fromJson(json)).toList();
      }
    } catch (e) {
      _proxyList = [];
    }
  }
  
  /// Cache proxies to SharedPreferences
  Future<void> _cacheProxies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _proxyList.map((p) => p.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(jsonList));
    } catch (e) {
      // Caching failed, continue without cache
    }
  }
  
  /// Check if we should refresh proxies (e.g., every 30 minutes)
  bool _shouldRefreshProxies() {
    if (_lastFetch == null) return true;
    final diff = DateTime.now().difference(_lastFetch!);
    return diff.inMinutes > 30;
  }
  
  /// Clear all proxies and cache
  Future<void> clearProxies() async {
    _proxyList = [];
    _currentProxyIndex = 0;
    _lastFetch = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
