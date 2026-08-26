import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api_client.dart';
import 'cart.dart';
import 'pos_repository.dart';

/// Escáner de código de barras para el POS. Escaneo CONTINUO: cada lectura busca
/// el producto por su código y lo agrega al carrito (con debounce y feedback).
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _processing = false;
  bool _torchOn = false;
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _added = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    // Evita procesar el mismo código repetido en <1.2 s (lecturas dobles).
    final now = DateTime.now();
    if (_processing) return;
    if (code == _lastCode && now.difference(_lastAt).inMilliseconds < 1200) {
      return;
    }
    _lastCode = code;
    _lastAt = now;
    _processing = true;

    try {
      final product = await ref.read(posRepositoryProvider).productByCode(code);
      if (!mounted) return;
      if (product != null) {
        ref.read(cartProvider.notifier).add(product);
        HapticFeedback.mediumImpact();
        setState(() => _added++);
        _feedback('«${product.name}» agregado', ok: true);
      } else {
        HapticFeedback.heavyImpact();
        _feedback('Código no encontrado: $code', ok: false);
      }
    } on ApiException catch (e) {
      if (mounted) _feedback(e.message, ok: false);
    } catch (_) {
      if (mounted) _feedback('Error al buscar el producto', ok: false);
    } finally {
      _processing = false;
    }
  }

  void _feedback(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          // Marco de guía.
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Barra superior: cerrar + linterna.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text('Escanear código',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white),
                    onPressed: () async {
                      await _controller.toggleTorch();
                      if (mounted) setState(() => _torchOn = !_torchOn);
                    },
                  ),
                ],
              ),
            ),
          ),
          // Barra inferior: contador + listo.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _added == 0
                            ? 'Apunta al código de barras'
                            : '$_added ${_added == 1 ? "producto agregado" : "productos agregados"}',
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Listo'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  final MobileScannerException error;
  const _CameraError({required this.error});

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
            const SizedBox(height: 12),
            Text(
              denied
                  ? 'Permiso de cámara denegado. Actívalo en los ajustes para escanear.'
                  : 'No se pudo iniciar la cámara.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}
