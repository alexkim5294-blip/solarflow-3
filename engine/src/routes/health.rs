/// 헬스체크 엔드포인트
/// /health — 서버 생존 확인 (fly.io 헬스체크용, DB 무관)
/// /health/ready — DB 연결 확인 (Go에서 Rust 호출 전 상태 확인)

use axum::extract::State;
use axum::http::StatusCode;
use axum::response::Json;
use serde_json::{json, Value};
use sqlx::PgPool;

/// GET /health — 항상 200 OK (서버 생존 확인)
/// 비유: 건물 현관 안내판 — "영업 중" 표시
pub async fn health() -> Json<Value> {
    Json(json!({
        "status": "ok",
        "service": "solarflow-engine",
        "version": "0.1.0"
    }))
}

/// GET /health/ready — DB 연결 확인
/// 비유: 건물 내부 설비 점검 — "수도/전기 정상" 확인
pub async fn health_ready(State(pool): State<PgPool>) -> (StatusCode, Json<Value>) {
    match sqlx::query("SELECT 1").execute(&pool).await {
        Ok(_) => (
            StatusCode::OK,
            Json(json!({
                "status": "ready",
                "db": "connected"
            })),
        ),
        Err(e) => (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(json!({
                "status": "not_ready",
                "db": "disconnected",
                "error": e.to_string()
            })),
        ),
    }
}
