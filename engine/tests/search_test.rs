/// 자연어 검색 엔진 테스트 — 파싱+별칭+의도분류

use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::Router;
use serde_json::json;
use tower::ServiceExt;

fn test_router() -> Router {
    Router::new().route("/api/calc/search", axum::routing::post(mock_search))
}

async fn mock_search(axum::extract::Json(body): axum::extract::Json<serde_json::Value>) -> (StatusCode, axum::response::Json<serde_json::Value>) {
    if body.get("company_id").and_then(|v| v.as_str()).is_none() {
        return (StatusCode::BAD_REQUEST, axum::response::Json(json!({"error": "company_id는 필수 항목입니다"})));
    }
    match body.get("query").and_then(|v| v.as_str()) {
        None => return (StatusCode::BAD_REQUEST, axum::response::Json(json!({"error": "query는 필수 항목입니다"}))),
        Some(q) if q.trim().is_empty() => return (StatusCode::BAD_REQUEST, axum::response::Json(json!({"error": "query는 빈 문자열일 수 없습니다"}))),
        _ => {}
    }
    (StatusCode::OK, axum::response::Json(json!({"query": body["query"], "intent": "fallback", "results": [], "calculated_at": "2026-03-29T12:00:00Z"})))
}

fn post_json(uri: &str, body: &serde_json::Value) -> Request<Body> {
    Request::builder().method("POST").uri(uri).header("Content-Type", "application/json")
        .body(Body::from(serde_json::to_string(body).unwrap())).unwrap()
}

// === API 테스트 ===

#[tokio::test]
async fn test_search_missing_company() {
    let r = test_router().oneshot(post_json("/api/calc/search", &json!({"query": "진코 640 재고"}))).await.unwrap();
    assert_eq!(r.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn test_search_empty_query() {
    let r = test_router().oneshot(post_json("/api/calc/search", &json!({"company_id": "uuid", "query": ""}))).await.unwrap();
    assert_eq!(r.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn test_search_ok() {
    let r = test_router().oneshot(post_json("/api/calc/search", &json!({"company_id": "uuid", "query": "테스트"}))).await.unwrap();
    assert_eq!(r.status(), StatusCode::OK);
}

// === 파싱 단위 테스트 ===

use solarflow_engine::calc::search::*;
use solarflow_engine::model::search::SearchIntent;

#[test]
fn test_parse_inventory() {
    let tokens = vec!["진코".into(), "640".into(), "재고".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::Inventory);
}

#[test]
fn test_parse_compare() {
    let tokens = vec!["진코".into(), "640".into(), "동일규격".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::Compare);
}

#[test]
fn test_parse_outbound() {
    let tokens = vec!["바로".into(), "3월".into(), "출고".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::Outbound);
}

#[test]
fn test_parse_lc_maturity() {
    let tokens = vec!["lc".into(), "만기".into(), "이번달".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::LcMaturity);
}

#[test]
fn test_parse_po_payment() {
    let tokens = vec!["라이젠".into(), "계약금".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::PoPayment);
}

#[test]
fn test_parse_outstanding() {
    let tokens = vec!["미수금".into(), "60일".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::Outstanding);
}

#[test]
fn test_parse_fallback() {
    let tokens = vec!["kgc원주공장".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::Fallback);
}

#[test]
fn test_parse_compare_alt() {
    let tokens = vec!["비교".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::Compare);
}

#[test]
fn test_parse_outbound_alt() {
    let tokens = vec!["납품".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::Outbound);
}

#[test]
fn test_parse_outstanding_alt() {
    let tokens = vec!["연체".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::Outstanding);
}

#[test]
fn test_parse_po_payment_alt() {
    let tokens = vec!["송금".into()];
    assert_eq!(classify_intent(&tokens), SearchIntent::PoPayment);
}

// === 별칭 테스트 ===

#[test]
fn test_alias_jinko() {
    let aliases = get_manufacturer_aliases();
    assert_eq!(aliases.get("진코"), Some(&"진코솔라".to_string()));
}

#[test]
fn test_alias_trina() {
    let aliases = get_manufacturer_aliases();
    assert_eq!(aliases.get("trina"), Some(&"트리나솔라".to_string()));
}

#[test]
fn test_alias_tongwei() {
    let aliases = get_manufacturer_aliases();
    assert_eq!(aliases.get("통웨이"), Some(&"통웨이솔라".to_string()));
}

#[test]
fn test_alias_aiko_separate() {
    let aliases = get_manufacturer_aliases();
    assert_eq!(aliases.get("아이코"), Some(&"AIKO".to_string()));
    assert_eq!(aliases.get("에스디엔"), Some(&"에스디엔".to_string()));
    assert_ne!(aliases.get("아이코"), aliases.get("에스디엔"));
}

#[test]
fn test_alias_partner_mirae() {
    let aliases = get_partner_aliases();
    assert_eq!(aliases.get("미래"), Some(&"신명".to_string()));
}

#[test]
fn test_alias_unknown() {
    let aliases = get_manufacturer_aliases();
    assert!(aliases.get("알수없는제조사").is_none());
}

// === 규격 인식 ===

#[test]
fn test_spec_wp_valid() {
    assert_eq!(parse_spec_wp("640"), Some(640));
    assert_eq!(parse_spec_wp("450"), Some(450));
    assert_eq!(parse_spec_wp("900"), Some(900));
}

#[test]
fn test_spec_wp_out_of_range() {
    assert_eq!(parse_spec_wp("350"), None);
    assert_eq!(parse_spec_wp("950"), None);
}

#[test]
fn test_spec_wp_non_numeric() {
    assert_eq!(parse_spec_wp("재고"), None);
}

// === 기간 인식 ===

#[test]
fn test_period_month() {
    let tokens = vec!["3월".into()];
    let (month, _) = parse_period("3월", &tokens);
    assert!(month.is_some());
    assert!(month.unwrap().ends_with("-03"));
}

#[test]
fn test_period_days() {
    let tokens = vec!["60일".into()];
    let (_, days) = parse_period("60일", &tokens);
    assert_eq!(days, Some(60));
}
