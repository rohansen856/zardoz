import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class DlnaDevice {
  final String name;
  final String location;
  final String ip;
  String? avTransportUrl;

  DlnaDevice({
    required this.name,
    required this.location,
    required this.ip,
    this.avTransportUrl,
  });

  @override
  bool operator ==(Object other) =>
      other is DlnaDevice && other.location == location;

  @override
  int get hashCode => location.hashCode;
}

enum CastState { idle, discovering, connecting, casting }

class CastService extends ChangeNotifier {
  static final CastService _instance = CastService._();
  factory CastService() => _instance;
  CastService._();

  CastState _state = CastState.idle;
  DlnaDevice? _connectedDevice;
  HttpServer? _imageServer;
  String? _servingUrl;
  final List<DlnaDevice> _discoveredDevices = [];

  CastState get state => _state;
  DlnaDevice? get connectedDevice => _connectedDevice;
  List<DlnaDevice> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  bool get isCasting => _state == CastState.casting;

  // -----------------------------------------------------------------------
  // Network helpers
  // -----------------------------------------------------------------------

  Future<String> _getLocalIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback && !addr.address.startsWith('127.')) {
          return addr.address;
        }
      }
    }
    throw Exception('Could not determine local IP address');
  }

  // -----------------------------------------------------------------------
  // SSDP Discovery
  // -----------------------------------------------------------------------

  Future<List<DlnaDevice>> discoverDevices({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    _discoveredDevices.clear();
    _state = CastState.discovering;
    notifyListeners();

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.multicastHops = 4;

      const search = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
          '\r\n';

      final target = InternetAddress('239.255.255.250');
      socket.send(utf8.encode(search), target, 1900);
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          socket.send(utf8.encode(search), target, 1900);
        } catch (_) {}
      });

      final locations = <String>{};
      final completer = Completer<List<DlnaDevice>>();

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket.receive();
          if (dg == null) return;
          final resp = utf8.decode(dg.data, allowMalformed: true);
          final match = RegExp(r'LOCATION:\s*(.+)', caseSensitive: false)
              .firstMatch(resp);
          if (match != null) {
            final loc = match.group(1)!.trim();
            if (locations.add(loc)) {
              _fetchDeviceInfo(loc);
            }
          }
        }
      });

      Timer(timeout, () {
        socket.close();
        if (_state == CastState.discovering) {
          _state = CastState.idle;
          notifyListeners();
        }
        if (!completer.isCompleted) completer.complete(_discoveredDevices);
      });

      return completer.future;
    } catch (e) {
      _state = CastState.idle;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _fetchDeviceInfo(String location) async {
    try {
      final resp = await http
          .get(Uri.parse(location))
          .timeout(const Duration(seconds: 4));
      final doc = XmlDocument.parse(resp.body);

      final deviceEl = doc.findAllElements('device').firstOrNull;
      if (deviceEl == null) return;

      final name =
          deviceEl.findElements('friendlyName').firstOrNull?.innerText ??
              'Unknown Device';

      final uri = Uri.parse(location);

      String? controlUrl;
      for (final svc in doc.findAllElements('service')) {
        final svcType =
            svc.findElements('serviceType').firstOrNull?.innerText ?? '';
        if (svcType.contains('AVTransport')) {
          final raw =
              svc.findElements('controlURL').firstOrNull?.innerText;
          if (raw != null) {
            controlUrl = raw.startsWith('/')
                ? '${uri.scheme}://${uri.host}:${uri.port}$raw'
                : raw;
          }
          break;
        }
      }

      final device = DlnaDevice(
        name: name,
        location: location,
        ip: uri.host,
        avTransportUrl: controlUrl,
      );

      if (!_discoveredDevices.contains(device)) {
        _discoveredDevices.add(device);
        notifyListeners();
      }
    } catch (_) {}
  }

  // -----------------------------------------------------------------------
  // Manual connection by IP
  // -----------------------------------------------------------------------

  Future<DlnaDevice?> connectByIp(String ip) async {
    _state = CastState.connecting;
    notifyListeners();

    // Try common DLNA description endpoints
    final ports = [49152, 8008, 8080, 1900, 7000, 52235, 9197];
    final paths = [
      '/dmr/DeviceDescription.xml',
      '/description.xml',
      '/dmr.xml',
      '/rootDesc.xml',
      '/upnp/dev/desc.xml',
      '/DeviceDescription.xml',
      '',
    ];

    for (final port in ports) {
      for (final path in paths) {
        try {
          final url = 'http://$ip:$port$path';
          final resp = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 2));
          if (resp.statusCode == 200 && resp.body.contains('<device>')) {
            await _fetchDeviceInfo(url);
            final device = _discoveredDevices.where((d) => d.ip == ip).firstOrNull;
            if (device != null) {
              _state = CastState.idle;
              notifyListeners();
              return device;
            }
          }
        } catch (_) {}
      }
    }

    _state = CastState.idle;
    notifyListeners();
    return null;
  }

  // -----------------------------------------------------------------------
  // Local HTTP server (serves image to the projector)
  // -----------------------------------------------------------------------

  Future<String> _startImageServer(Uint8List imageBytes) async {
    await _stopImageServer();

    final localIp = await _getLocalIp();
    _imageServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);

    _imageServer!.listen((req) {
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType('image', 'png')
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..headers.contentLength = imageBytes.length
        ..add(imageBytes)
        ..close();
    });

    _servingUrl = 'http://$localIp:${_imageServer!.port}/design.png';
    return _servingUrl!;
  }

  Future<void> _stopImageServer() async {
    await _imageServer?.close(force: true);
    _imageServer = null;
    _servingUrl = null;
  }

  // -----------------------------------------------------------------------
  // DLNA SOAP control
  // -----------------------------------------------------------------------

  Future<void> _soapAction(
    String controlUrl,
    String action,
    String body,
  ) async {
    const ns = 'urn:schemas-upnp-org:service:AVTransport:1';
    final envelope = '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body><u:$action xmlns:u="$ns">$body</u:$action></s:Body>'
        '</s:Envelope>';

    await http.post(
      Uri.parse(controlUrl),
      headers: {
        'Content-Type': 'text/xml; charset="utf-8"',
        'SOAPAction': '"$ns#$action"',
      },
      body: envelope,
    );
  }

  // -----------------------------------------------------------------------
  // Cast / Stop
  // -----------------------------------------------------------------------

  /// Downloads the image from [imageUrl], serves it locally, and tells
  /// [device] to render it via DLNA AVTransport.
  Future<void> castImage(DlnaDevice device, String imageUrl) async {
    if (device.avTransportUrl == null) {
      throw Exception('Device does not support AVTransport');
    }

    _state = CastState.connecting;
    _connectedDevice = device;
    notifyListeners();

    // Download the image
    final imgResp = await http.get(Uri.parse(imageUrl));
    if (imgResp.statusCode != 200) {
      throw Exception('Failed to download image');
    }

    // Serve it locally so the projector can fetch it
    final localUrl = await _startImageServer(imgResp.bodyBytes);

    // DLNA: set URI and play
    final escapedUrl = localUrl
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    final metadata = '&lt;DIDL-Lite xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/&quot; '
        'xmlns:dc=&quot;http://purl.org/dc/elements/1.1/&quot; '
        'xmlns:upnp=&quot;urn:schemas-upnp-org:metadata-1-0/upnp/&quot;&gt;'
        '&lt;item id=&quot;0&quot; parentID=&quot;-1&quot; restricted=&quot;1&quot;&gt;'
        '&lt;dc:title&gt;Zardoz Design&lt;/dc:title&gt;'
        '&lt;upnp:class&gt;object.item.imageItem.photo&lt;/upnp:class&gt;'
        '&lt;res protocolInfo=&quot;http-get:*:image/png:*&quot;&gt;$escapedUrl&lt;/res&gt;'
        '&lt;/item&gt;&lt;/DIDL-Lite&gt;';

    await _soapAction(device.avTransportUrl!, 'SetAVTransportURI',
        '<InstanceID>0</InstanceID>'
        '<CurrentURI>$escapedUrl</CurrentURI>'
        '<CurrentURIMetaData>$metadata</CurrentURIMetaData>');

    await _soapAction(device.avTransportUrl!, 'Play',
        '<InstanceID>0</InstanceID><Speed>1</Speed>');

    _state = CastState.casting;
    notifyListeners();
  }

  Future<void> stopCasting() async {
    if (_connectedDevice?.avTransportUrl != null) {
      try {
        await _soapAction(_connectedDevice!.avTransportUrl!, 'Stop',
            '<InstanceID>0</InstanceID>');
      } catch (_) {}
    }

    _connectedDevice = null;
    _state = CastState.idle;
    await _stopImageServer();
    notifyListeners();
  }

  @override
  void dispose() {
    _imageServer?.close(force: true);
    super.dispose();
  }
}
