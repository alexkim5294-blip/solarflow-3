/// 라우터 모듈
/// 비유: 건물 안내 데스크 — 요청을 적절한 부서로 안내

pub mod health;

use axum::Router;
use sqlx::PgPool;

/// 전체 라우터 생성
pub fn create_router(pool: PgPool) -> Router {
    Router::new()
        .route("/health", axum::routing::get(health::health))
        .route("/health/ready", axum::routing::get(health::health_ready))
        // Step 13부터 계산 API 추가
        // .nest("/api/calc", calc_router)
        .with_state(pool)
}
