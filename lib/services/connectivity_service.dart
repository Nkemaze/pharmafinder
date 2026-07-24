// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';

class ConnectivityService {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get isConnected => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  ConnectivityService() {
    _isOnline = html.window.navigator.onLine ?? true;
    _controller.add(_isOnline);

    html.window.addEventListener('online', _onOnline);
    html.window.addEventListener('offline', _onOffline);
  }

  void _onOnline(html.Event event) {
    _isOnline = true;
    _controller.add(true);
  }

  void _onOffline(html.Event event) {
    _isOnline = false;
    _controller.add(false);
  }

  void dispose() {
    html.window.removeEventListener('online', _onOnline);
    html.window.removeEventListener('offline', _onOffline);
    _controller.close();
  }
}
