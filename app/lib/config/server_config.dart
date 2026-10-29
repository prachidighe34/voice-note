/// Base URL for your Go server. "localhost" from a phone/emulator means
/// the device itself, NOT your laptop — so it never reaches a server
/// running on your machine. Use the right value for however you're testing:
///
/// - Android emulator -> 10.0.2.2 (the emulator's special alias for the
///   host machine's localhost): http://10.0.2.2:8080
/// - iOS simulator -> localhost works fine, simulators share the host's
///   network stack: http://localhost:8080
/// - Physical device (Android or iOS) -> your laptop's actual LAN IP,
///   e.g. http://192.168.1.42:8080 (find it with `ipconfig` on Windows or
///   `ifconfig`/`ip addr` on Mac/Linux; phone and laptop must be on the
///   same Wi-Fi network, and your OS firewall must allow the connection)
const String serverBaseUrl =
    'http://192.168.29.78:8080'; // <- change to match how you're testing
