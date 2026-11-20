import Foundation

/// An absolute `http` or `https` URL with a host.
func playableURL(_ string: String) -> URL? {
    guard let url = URL(string: string),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          let host = url.host, !host.isEmpty
    else { return nil }
    return url
}
