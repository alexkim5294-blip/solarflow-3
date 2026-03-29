/// 월별 수급 전망 API + 단위 테스트

use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::Router;
use serde_json::json;
use tower::ServiceExt;

fn test_router() -> Router {
    Router::new().route("/api/calc/supply-forecast", axum::routing::post(mock_forecast))
}

async fn mock_forecast(axum::extract::Json(body): axum::extract::Json<serde_json::Value>) -> (StatusCode, axum::response::Json<serde_json::Value>) {
    if body.get("company_id").and_then(|v| v.as_str()).is_none() {
        return (StatusCode::BAD_REQUEST, axum::response::Json(json!({"error": "company_id는 필수 항목입니다"})));
    }
    let months = body.get("months_ahead").and_then(|v| v.as_i64()).unwrap_or(6).min(12);
    let month_data: Vec<serde_json::Value> = (0..months).map(|_| json!({"month": "2026-04", "opening_kw": 0.0, "closing_kw": 0.0, "insufficient": false})).collect();
    (StatusCode::OK, axum::response::Json(json!({
        "products": [], "months_generated": months,
        "summary": {"months": month_data},
        "calculated_at": "2026-03-29T12:00:00Z"
    })))
}

fn post_json(uri: &str, body: &serde_json::Value) -> Request<Body> {
    Request::builder().method("POST").uri(uri).header("Content-Type", "application/json")
        .body(Body::from(serde_json::to_string(body).unwrap())).unwrap()
}

#[tokio::test]
async fn test_forecast_missing_company() {
    let r = test_router().oneshot(post_json("/api/calc/supply-forecast", &json!({}))).await.unwrap();
    assert_eq!(r.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn test_forecast_default_months() {
    let r = test_router().oneshot(post_json("/api/calc/supply-forecast", &json!({"company_id": "uuid"}))).await.unwrap();
    let body = axum::body::to_bytes(r.into_body(), usize::MAX).await.unwrap();
    let j: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(j["months_generated"], 6);
}

#[tokio::test]
async fn test_forecast_max_12_months() {
    let r = test_router().oneshot(post_json("/api/calc/supply-forecast", &json!({"company_id": "uuid", "months_ahead": 15}))).await.unwrap();
    let body = axum::body::to_bytes(r.into_body(), usize::MAX).await.unwrap();
    let j: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(j["months_generated"], 12);
}

#[tokio::test]
async fn test_forecast_empty_products() {
    let r = test_router().oneshot(post_json("/api/calc/supply-forecast", &json!({"company_id": "uuid"}))).await.unwrap();
    let body = axum::body::to_bytes(r.into_body(), usize::MAX).await.unwrap();
    let j: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert!(j["products"].as_array().unwrap().is_empty());
}

#[tokio::test]
async fn test_forecast_1_month() {
    let r = test_router().oneshot(post_json("/api/calc/supply-forecast", &json!({"company_id": "uuid", "months_ahead": 1}))).await.unwrap();
    let body = axum::body::to_bytes(r.into_body(), usize::MAX).await.unwrap();
    let j: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(j["months_generated"], 1);
}

// === 단위 테스트 ===

#[test]
fn test_calc_closing() {
    use solarflow_engine::calc::forecast::calc_closing;
    assert_eq!(calc_closing(100.0, 30.0, 20.0, 10.0), 100.0);
}

#[test]
fn test_closing_chain() {
    use solarflow_engine::calc::forecast::calc_closing;
    let m1 = calc_closing(100.0, 0.0, 10.0, 10.0);
    assert_eq!(m1, 80.0);
    let m2 = calc_closing(m1, 20.0, 5.0, 5.0);
    assert_eq!(m2, 90.0);
}

#[test]
fn test_closing_insufficient() {
    use solarflow_engine::calc::forecast::calc_closing;
    let closing = calc_closing(50.0, 0.0, 60.0, 0.0);
    assert_eq!(closing, -10.0);
    assert!(closing < 0.0); // insufficient=true
}

#[test]
fn test_closing_with_unscheduled_excluded() {
    use solarflow_engine::calc::forecast::calc_closing;
    // unscheduled는 월별 계산에 포함 안 됨 (별도 표시)
    let closing = calc_closing(100.0, 0.0, 0.0, 0.0);
    assert_eq!(closing, 100.0);
}
