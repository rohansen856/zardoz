import 'package:flutter/material.dart';
import '../services/cast_service.dart';

/// Shows a bottom sheet for discovering DLNA devices and casting an image.
///
/// [imageUrl] is the network URL of the image to cast (e.g. Cloudinary).
void showCastSheet(BuildContext context, String imageUrl) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CastSheetBody(imageUrl: imageUrl),
  );
}

class _CastSheetBody extends StatefulWidget {
  final String imageUrl;
  const _CastSheetBody({required this.imageUrl});

  @override
  State<_CastSheetBody> createState() => _CastSheetBodyState();
}

class _CastSheetBodyState extends State<_CastSheetBody> {
  final _cast = CastService();
  final _ipCtl = TextEditingController();
  bool _manualMode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cast.addListener(_onCastChanged);
    if (!_cast.isCasting) _cast.discoverDevices();
  }

  @override
  void dispose() {
    _cast.removeListener(_onCastChanged);
    _ipCtl.dispose();
    super.dispose();
  }

  void _onCastChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _connectManual() async {
    final ip = _ipCtl.text.trim();
    if (ip.isEmpty) return;
    setState(() => _error = null);
    final device = await _cast.connectByIp(ip);
    if (device == null) {
      setState(() => _error = 'No DLNA renderer found at $ip');
      return;
    }
    _startCast(device);
  }

  Future<void> _startCast(DlnaDevice device) async {
    setState(() => _error = null);
    try {
      await _cast.castImage(device, widget.imageUrl);
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 480),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                Icon(Icons.cast, color: primary),
                const SizedBox(width: 10),
                const Text('Cast to Projector',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_cast.isCasting)
                  TextButton(
                    onPressed: () async {
                      await _cast.stopCasting();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Disconnect',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Currently casting
            if (_cast.isCasting) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cast_connected,
                        color: Colors.green, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Casting',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green)),
                          Text(_cast.connectedDevice?.name ?? '',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Device list or manual entry
            if (!_cast.isCasting) ...[
              if (!_manualMode) ...[
                // Discovering state
                if (_cast.state == CastState.discovering) ...[
                  const SizedBox(height: 20),
                  const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(height: 12),
                  Text('Searching for devices...',
                      style: TextStyle(color: Colors.grey[500])),
                ],

                // Connecting
                if (_cast.state == CastState.connecting) ...[
                  const SizedBox(height: 20),
                  const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(height: 12),
                  Text('Connecting...',
                      style: TextStyle(color: Colors.grey[500])),
                ],

                // Device list
                if (_cast.discoveredDevices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Available Devices',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600])),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _cast.discoveredDevices.length,
                      itemBuilder: (ctx, i) {
                        final dev = _cast.discoveredDevices[i];
                        final hasTransport = dev.avTransportUrl != null;
                        return ListTile(
                          leading: Icon(
                            hasTransport ? Icons.tv : Icons.device_unknown,
                            color: hasTransport ? primary : Colors.grey,
                          ),
                          title: Text(dev.name),
                          subtitle: Text(dev.ip,
                              style: const TextStyle(fontSize: 12)),
                          trailing: hasTransport
                              ? const Icon(Icons.arrow_forward_ios, size: 16)
                              : Text('Not supported',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[400])),
                          enabled: hasTransport,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          onTap: hasTransport ? () => _startCast(dev) : null,
                        );
                      },
                    ),
                  ),
                ],

                // No devices found after scan
                if (_cast.state == CastState.idle &&
                    _cast.discoveredDevices.isEmpty) ...[
                  const SizedBox(height: 24),
                  Icon(Icons.cast, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No devices found',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Make sure the projector is on the same WiFi network',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],

                // Action buttons
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cast.state == CastState.discovering
                            ? null
                            : () => _cast.discoverDevices(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Scan Again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _manualMode = true),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Enter IP'),
                      ),
                    ),
                  ],
                ),
              ],

              // Manual IP entry
              if (_manualMode) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onPressed: () => setState(() => _manualMode = false),
                    ),
                    const Text('Enter Projector IP',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ipCtl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '192.168.1.100',
                    prefixIcon: const Icon(Icons.router),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _cast.state == CastState.connecting
                          ? null
                          : _connectManual,
                    ),
                  ),
                  onSubmitted: (_) => _connectManual(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter the IP address shown on your projector\'s network settings',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
