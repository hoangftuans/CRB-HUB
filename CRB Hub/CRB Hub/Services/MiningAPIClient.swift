import Foundation

/// Cereblix Mining Pool API client
/// Calls the pool API: poolstats, workers, health
enum MiningAPIClient {
    
    /// GET /pool/api/poolstats — pool-wide statistics + all miners
    static func getPoolStats() async throws -> PoolStatsResponse {
        try await APIClient.get("\(APIConfig.poolAPI)/poolstats", type: PoolStatsResponse.self)
    }
    
    /// GET /pool/api/workers?addr=crb1... — per-rig breakdown for one address
    static func getWorkers(address: String) async throws -> WorkersResponse {
        try await APIClient.get("\(APIConfig.poolAPI)/workers?addr=\(address)", type: WorkersResponse.self)
    }
    
    /// GET /pool/api/health — load balancer / liveness probe
    static func getHealth() async throws -> PoolHealth {
        try await APIClient.get("\(APIConfig.poolAPI)/health", type: PoolHealth.self)
    }
}
