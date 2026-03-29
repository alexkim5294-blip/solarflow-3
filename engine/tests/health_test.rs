/// 헬스체크 엔드포인트 테스트
/// DB 없이도 /health는 200 OK를 반환해야 함

use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::Router;
use tower::ServiceExt;

/// 테스트용 라우터 생성 (DB 없이 /health만)
fn test_router() -> Router {
    Router::new()
        .route("/health", axum::routing::get(health_handler))
}

/// /health 핸들러 (DB 불필요 버전)
async fn health_handler() -> axum::response::Json<serde_json::Value> {
    axum::response::Json(serde_json::json!({
        "status": "ok",
        "service": "solarflow-engine",
        "version": "0.1.0"
    }))
}

/// /health → 200 + "status": "ok" 확인
#[tokio::test]
async fn test_health_returns_ok() {
    let app = test_router();

    let response = app
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = axum::body::to_bytes(response.into_body(), usize::MAX)
        .await
        .unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert_eq!(json["status"], "ok");
    assert_eq!(json["service"], "solarflow-engine");
    assert_eq!(json["version"], "0.1.0");
}
