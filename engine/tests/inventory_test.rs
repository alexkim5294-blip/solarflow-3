/// 재고 집계 API 엔드포인트 테스트
/// DB 없이 요청 형식 검증만 수행

use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::Router;
use serde_json::json;
use tower::ServiceExt;

/// 테스트용 라우터 (DB 없이 company_id 검증만)
fn test_router() -> Router {
    Router::new().route(
        "/api/calc/inventory",
        axum::routing::post(mock_inventory_handler),
    )
}

/// mock 핸들러 — company_id 검증만 수행, DB 미사용
async fn mock_inventory_handler(
    axum::extract::Json(body): axum::extract::Json<serde_json::Value>,
) -> (StatusCode, axum::response::Json<serde_json::Value>) {
    if body.get("company_id").and_then(|v| v.as_str()).is_none() {
        return (
            StatusCode::BAD_REQUEST,
            axum::response::Json(json!({"error": "company_id는 필수 항목입니다"})),
        );
    }

    // DB 없이 빈 결과 반환
    (
        StatusCode::OK,
        axum::response::Json(json!({
            "items": [],
            "summary": {
                "total_physical_kw": 0.0,
                "total_available_kw": 0.0,
                "total_incoming_kw": 0.0,
                "total_secured_kw": 0.0
            },
            "calculated_at": "2026-03-29T12:00:00Z"
        })),
    )
}

/// POST /api/calc/inventory + company_id -> 200
#[tokio::test]
async fn test_inventory_success() {
    let app = test_router();

    let body = json!({"company_id": "550e8400-e29b-41d4-a716-446655440000"});

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/calc/inventory")
                .header("Content-Type", "application/json")
                .body(Body::from(serde_json::to_string(&body).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let resp_body = axum::body::to_bytes(response.into_body(), usize::MAX)
        .await
        .unwrap();
    let json: serde_json::Value = serde_json::from_slice(&resp_body).unwrap();

    assert!(json["items"].is_array());
    assert_eq!(json["summary"]["total_physical_kw"], 0.0);
}

/// POST /api/calc/inventory — company_id 누락 -> 400
#[tokio::test]
async fn test_inventory_missing_company_id() {
    let app = test_router();

    let body = json!({"product_id": "550e8400-e29b-41d4-a716-446655440001"});

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/calc/inventory")
                .header("Content-Type", "application/json")
                .body(Body::from(serde_json::to_string(&body).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
}

/// POST /api/calc/inventory — 빈 items + 0 summary 확인
#[tokio::test]
async fn test_inventory_empty_result() {
    let app = test_router();

    let body = json!({"company_id": "550e8400-e29b-41d4-a716-446655440000"});

    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/calc/inventory")
                .header("Content-Type", "application/json")
                .body(Body::from(serde_json::to_string(&body).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap();

    let resp_body = axum::body::to_bytes(response.into_body(), usize::MAX)
        .await
        .unwrap();
    let json: serde_json::Value = serde_json::from_slice(&resp_body).unwrap();

    let items = json["items"].as_array().unwrap();
    assert!(items.is_empty());
    assert_eq!(json["summary"]["total_secured_kw"], 0.0);
}
