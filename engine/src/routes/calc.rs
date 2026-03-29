/// 계산 API 엔드포인트
/// POST /api/calc/inventory — 재고 집계

use axum::extract::State;
use axum::http::StatusCode;
use axum::response::Json;
use serde_json::{json, Value};
use sqlx::PgPool;

use crate::calc::inventory::calculate_inventory;
use crate::model::inventory::InventoryRequest;

/// POST /api/calc/inventory — 재고 집계 핸들러
/// 비유: "재고 현황판 요청 접수 창구"
pub async fn inventory_handler(
    State(pool): State<PgPool>,
    Json(req): Json<InventoryRequest>,
) -> (StatusCode, Json<Value>) {
    // company_id 필수 검증
    if req.company_id.is_none() {
        return (
            StatusCode::BAD_REQUEST,
            Json(json!({"error": "company_id는 필수 항목입니다"})),
        );
    }

    match calculate_inventory(&pool, &req).await {
        Ok(response) => (
            StatusCode::OK,
            Json(serde_json::to_value(response).unwrap_or(json!({"error": "직렬화 실패"}))),
        ),
        Err(e) => {
            tracing::error!("재고 집계 실패: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({"error": format!("재고 집계 실패: {}", e)})),
            )
        }
    }
}
