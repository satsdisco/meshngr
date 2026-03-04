/// How a message should be routed through the mesh
enum RouteMode {
  auto,   // Smart: use learned path, fall back to flood
  direct, // Use known direct path only
  flood,  // Broadcast to all nodes (wide reach, more airtime)
}

/// Type of advertisement to send
enum AdvertType {
  local, // Zero-hop: only nodes directly in range hear it
  flood, // Network-wide: relayed through all repeaters
}

extension RouteModeInfo on RouteMode {
  String get label {
    switch (this) {
      case RouteMode.auto: return 'Smart';
      case RouteMode.direct: return 'Direct';
      case RouteMode.flood: return 'Broadcast';
    }
  }

  String get description {
    switch (this) {
      case RouteMode.auto:
        return 'Automatically picks the best path. Tries the fastest route first, falls back to broadcasting if needed.';
      case RouteMode.direct:
        return 'Sends through a known path only. Fastest and uses least airtime, but fails if the route breaks.';
      case RouteMode.flood:
        return 'Broadcasts to all nodes in the mesh. Most reliable for reaching someone, but uses more airtime.';
    }
  }

  String get icon {
    switch (this) {
      case RouteMode.auto: return '✨';
      case RouteMode.direct: return '→';
      case RouteMode.flood: return '📡';
    }
  }
}

extension AdvertTypeInfo on AdvertType {
  String get label {
    switch (this) {
      case AdvertType.local: return 'Nearby Only';
      case AdvertType.flood: return 'Whole Network';
    }
  }

  String get description {
    switch (this) {
      case AdvertType.local:
        return 'Only nodes directly in range will see you. Good for crowded areas where you just want to find people nearby.';
      case AdvertType.flood:
        return 'Your presence is relayed through the entire mesh network. Everyone on the network can find you.';
    }
  }
}
