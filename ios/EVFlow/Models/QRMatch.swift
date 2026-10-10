import Foundation

/// QR → connector. Operators print the EVSE id in many shapes ("LT*IGN*E000A", URLs with ?evse=…),
/// so both sides are normalised and the connector id only has to appear inside the QR text.
func normalizeEVSE(_ s: String) -> String {
    s.uppercased().filter { $0 != "*" && $0 != "-" && $0 != " " && $0 != "_" }
}

/// Station's own connectors first, then everything else; when several match, the longest id wins.
func matchConnector(qr: String, station: [Connector], all: [Connector]) -> Connector? {
    let q = normalizeEVSE(qr)
    func best(_ pool: [Connector]) -> Connector? {
        pool.filter { let id = normalizeEVSE($0.id); return !id.isEmpty && q.contains(id) }
            .max { normalizeEVSE($0.id).count < normalizeEVSE($1.id).count }
    }
    return best(station) ?? best(all)
}
