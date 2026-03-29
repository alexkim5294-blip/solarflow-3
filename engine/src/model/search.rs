/// 자연어 검색 요청/응답 모델

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Deserialize)]
pub struct SearchRequest {
    pub company_id: Option<Uuid>,
    pub query: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct SearchResponse {
    pub query: String,
    pub intent: String,
    pub parsed: ParsedInfo,
    pub results: Vec<SearchResult>,
    pub warnings: Vec<String>,
    pub calculated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Default)]
pub struct ParsedInfo {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub manufacturer: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub spec_wp: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub month: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub days: Option<i32>,
    pub keywords: Vec<String>,
}

#[derive(Debug, Serialize, Clone)]
pub struct SearchResult {
    pub result_type: String,
    pub title: String,
    pub data: serde_json::Value,
    pub link: SearchLink,
}

#[derive(Debug, Serialize, Clone)]
pub struct SearchLink {
    pub module: String,
    pub params: HashMap<String, String>,
}

/// 파싱된 쿼리 (내부용)
#[derive(Debug, Default)]
pub struct ParsedQuery {
    pub manufacturer: Option<(Uuid, String)>,
    pub partners: Vec<(Uuid, String)>,
    pub spec_wp: Option<i32>,
    pub month: Option<String>,
    pub days: Option<i32>,
    pub intent: SearchIntent,
    pub raw_tokens: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Default)]
pub enum SearchIntent {
    Inventory,
    Compare,
    Outbound,
    LcMaturity,
    PoPayment,
    Outstanding,
    #[default]
    Fallback,
}

impl SearchIntent {
    pub fn as_str(&self) -> &str {
        match self {
            Self::Inventory => "inventory",
            Self::Compare => "compare",
            Self::Outbound => "outbound",
            Self::LcMaturity => "lc_maturity",
            Self::PoPayment => "po_payment",
            Self::Outstanding => "outstanding",
            Self::Fallback => "fallback",
        }
    }
}
